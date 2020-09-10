module PlutoUtils

using Comonicon
using Pluto

"""
open a Pluto notebook at given path.

# Arguments

- `file`: file path of the Pluto notebook.

# Options

- `--host <ip>`: default is 127.0.0.1 (localhost)
- `-p,--port <int>`: port you want to specify, default is 1234
- `--project <path>`: notebook project path, default is Julia's default global environment.

# Flags

- `-l,--launchbrowser`: add this flag to launch browser.
"""
@cast function open(file; host="127.0.0.1", port::Int=1234, launchbrowser::Bool=false, project=nothing)
    isfile(file) || error("file $file does not exist!")
    s = Pluto.ServerSession()
    config = Pluto.ServerConfiguration(launch_browser=launchbrowser)

    nb = Pluto.SessionActions.open(s, file; project=project)
    println("you can open the notebook at: http://localhost:$port/edit?id=$(nb.notebook_id)")
    Pluto.run(host, port;configuration=config, session=s)
    return
end

"""
start Pluto notebook server.

# Options

- `--host <ip>`: default is 127.0.0.1 (localhost)
- `-p,--port <int>`: port you want to specify, default is 1234
- `--project <path>`: custom project path, default is Julia's default global environment.

# Flags

- `-l,--launchbrowser`: add this flag to launch browser.
"""
@cast function run(;host="127.0.0.1", port::Int=1234, launchbrowser::Bool=false, project=nothing)
    config = Pluto.ServerConfiguration(launch_browser=launchbrowser)
    s = ServerSession(default_environment_path=project)
    Pluto.run(host, port; configuration=config, session=s)
end


@main name="pluto" doc="Pluto CLI - Lightweight reactive notebooks for Julia"

end
