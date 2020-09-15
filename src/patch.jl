# NOTE: this is copied from Pluto.run with launch_browser url changed
using Pluto: Sockets, HTTP, ServerSession, http_router_for, WorkspaceManager, MSG_DELIM, unpack, process_ws_message

function run_with_notebook_open(session::ServerSession, nb::Notebook)
    pluto_router = http_router_for(session)
    host = session.options.server.host
    port = session.options.server.port

    hostIP = parse(Sockets.IPAddr, host)
    if port === nothing
        port, serversocket = Sockets.listenany(hostIP, UInt16(1234))
    else
        try
            serversocket = Sockets.listen(hostIP, UInt16(port))
        catch e
            @error "Port with number $port is already in use. Use Pluto.run() to automatically select an available port."
            return
        end
    end

    kill_server = Ref{Function}(identity)

    servertask = @async HTTP.serve(hostIP, UInt16(port), stream=true, server=serversocket) do http::HTTP.Stream
        # messy messy code so that we can use the websocket on the same port as the HTTP server

        if HTTP.WebSockets.is_upgrade(http.message)
            try
                requestURI = http.message.target |> HTTP.URIs.unescapeuri |> HTTP.URI
                @assert endswith(requestURI.path, string(session.secret))

                HTTP.WebSockets.upgrade(http) do clientstream
                    if !isopen(clientstream)
                        return
                    end
                    try
                    while !eof(clientstream)
                        # This stream contains data received over the WebSocket.
                        # It is formatted and MsgPack-encoded by send(...) in PlutoConnection.js
                        try
                            parentbody = let
                                # For some reason, long (>256*512 bytes) WS messages get split up - `readavailable` only gives the first 256*512 
                                data = UInt8[]
                                while !endswith(data, MSG_DELIM)
                                    if eof(clientstream)
                                        if isempty(data)
                                            return
                                        end
                                        @warn "Unexpected eof after" data
                                        append!(data, MSG_DELIM)
                                        break
                                    end
                                    append!(data, readavailable(clientstream))
                                end
                                # TODO: view to avoid memory allocation
                                unpack(data[1:end - length(MSG_DELIM)])
                            end
                            process_ws_message(session, parentbody, clientstream)
                        catch ex
                            if ex isa InterruptException
                                kill_server[]()
                            elseif ex isa HTTP.WebSockets.WebSocketError || ex isa EOFError
                                # that's fine!
                            elseif ex isa InexactError
                                # that's fine! this is a (fixed) HTTP.jl bug: https://github.com/JuliaWeb/HTTP.jl/issues/471
                                # TODO: remove this switch
                            else
                                bt = stacktrace(catch_backtrace())
                                @warn "Reading WebSocket client stream failed for unknown reason:" exception = (ex, bt)
                            end
                        end
                    end
                    catch ex
                        if ex isa InterruptException
                            kill_server[]()
                        else
                            bt = stacktrace(catch_backtrace())
                            @warn "Reading WebSocket client stream failed for unknown reason:" exception = (ex, bt)
                        end
                    end
                end
            catch ex
                if ex isa InterruptException
                    kill_server[]()
                elseif ex isa Base.IOError
                    # that's fine!
                elseif ex isa ArgumentError && occursin("stream is closed", ex.msg)
                    # that's fine!
                else
                    bt = stacktrace(catch_backtrace())
                    @warn "HTTP upgrade failed for unknown reason" exception = (ex, bt)
                end
            end
        else
            request::HTTP.Request = http.message
            request.body = read(http)
            HTTP.closeread(http)

            # If a "token" url parameter is passed in from binder, then we store it to add to every URL (so that you can share the URL to collaborate).
            params = HTTP.queryparams(HTTP.URI(request.target))
            if haskey(params, "token") && session.binder_token === nothing 
                session.binder_token = params["token"]
            end

            request_body = IOBuffer(HTTP.payload(request))
            if eof(request_body)
                # no request body
                response_body = HTTP.handle(pluto_router, request)
            else
                @warn "HTTP request contains a body, huh?" request_body
            end
    
            request.response::HTTP.Response = response_body
            request.response.request = request
            try
                HTTP.startwrite(http)
                write(http, request.response.body)
                HTTP.closewrite(http)
            catch e
                if isa(e, Base.IOError) || isa(e, ArgumentError)
                    # @warn "Attempted to write to a closed stream at $(request.target)"
                else
                    rethrow(e)
                end
            end
        end
    end

    address = if session.options.server.root_url === nothing
        hostPretty = (hostStr = string(hostIP)) == "127.0.0.1" ? "localhost" : hostStr
        portPretty = Int(port)
        "http://$(hostPretty):$(portPretty)/"
    else
        session.options.server.root_url
    end
    Sys.set_process_title("Pluto server - $address")

    notebook_url = address * "edit?id=$(nb.notebook_id)"
    if session.options.server.launch_browser && open_in_default_browser(notebook_url)
        println("Opening $notebook_url in your default browser... ~ have fun!")
    else
        println("Go to $notebook_url in your browser to start your notebook ~ have fun!")
    end
    println()
    println("Press Ctrl+C in this terminal to stop Pluto")
    println()

    kill_server[] = () -> @sync begin
        println("\n\nClosing Pluto... Restart Julia for a fresh session. \n\nHave a nice day! 🎈")
        @async close(serversocket)
        # TODO: HTTP has a kill signal?
        # TODO: put do_work tokens back 
        for client in values(session.connected_clients)
            @async close(client.stream)
        end
        empty!(session.connected_clients)
        for (notebook_id, ws) in WorkspaceManager.workspaces
            @async WorkspaceManager.unmake_workspace(ws)
        end
    end

    try
        # create blocking call and switch the scheduler back to the server task, so that interrupts land there
        wait(servertask)
    catch e
        if e isa InterruptException
            kill_server[]()
        elseif e isa TaskFailedException
            # nice!
        else
            rethrow(e)
        end
    end
end
