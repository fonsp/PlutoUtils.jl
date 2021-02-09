module Export

import Pluto
import Pluto: ServerSession
using HTTP
using Base64
using SHA
using Sockets


using Logging: global_logger
using GitHubActions: GitHubActionsLogger
get(ENV, "GITHUB_ACTIONS", "false") == "true" && global_logger(GitHubActionsLogger())

myhash = base64encode ∘ sha256

function github_action(; export_dir=".", output_dir=".", generate_default_index=true, offer_binder=false, copy_to_temp_before_running=false, disable_ui=true, bind_server_url=nothing, binder_url=nothing, kwargs...)
    mkpath(export_dir)

    jlfiles = vcat(map(walkdir(".")) do (root, dirs, files)
        map(
            filter(files) do file
                occursin(".jl", file)
            end
            ) do file
            joinpath(root, file)
        end
    end...)
    notebookfiles = filter(jlfiles) do f
        readline(f) == "### A Pluto.jl notebook ###"
    end
    export_paths(notebookfiles; export_dir=export_dir, output_dir=output_dir, copy_to_temp_before_running=copy_to_temp_before_running, offer_binder=offer_binder, disable_ui=disable_ui, bind_server_url=bind_server_url, binder_url=binder_url, kwargs...)

    generate_default_index && create_default_index(;export_dir=export_dir)
end

function create_default_index(;export_dir=".")
    default_md = """
    Notebooks:

    <ul>
        {% for page in site.static_files %}
            {% if page.extname == ".html" %}
                <li><a href="{{ page.path | absolute_url }}">{{ page.name }}</a></li>
            {% endif %}
        {% endfor %}
    </ul>

    <br>
    <br>
    <br>
    """

    exists = any(["index.html", "index.md", "index.jl"]) do f
        joinpath(export_dir, f) |> isfile
    end
    if !exists
        write(joinpath(export_dir, "index.md"), default_md)
    end
end

function export_paths(notebook_paths::Vector{String}; export_dir=".", output_dir=".", copy_to_temp_before_running=false, offer_binder=false, disable_ui=true, bind_server_url=nothing, binder_url=nothing, kwargs...)
    export_dir = Pluto.tamepath(export_dir)

    options = Pluto.Configuration.from_flat_kwargs(; kwargs...)
    session = Pluto.ServerSession(;options=options)

    for (i, path) in enumerate(notebook_paths)
        try
            @info "[$(i)/$(length(notebook_paths))] Opening $(path)"
            hash = myhash(read(path))
            if copy_to_temp_before_running
                newpath = tempname()
                write(newpath, read(path))
            else
                newpath = path
            end
            nb = Pluto.SessionActions.open(session, newpath; run_async=false)

            @info "Ready $(path)" hash

            html_filename = if endswith(path, ".jl")
                path[1:end-3] * ".html"
            else
                path * ".html"
            end

            mkpath(output_dir)
            export_path = joinpath(output_dir, basename(html_filename))
            export_jl_path = joinpath(export_dir, path)


            notebookfile_js = if offer_binder
                repr(basename(path))
            else
                "undefined"
            end
            bind_server_url_js = if bind_server_url !== nothing
                repr(bind_server_url)
            else
                "undefined"
            end
            binder_url_js = if binder_url !== nothing
                repr(binder_url)
            else
                "undefined"
            end
            html_contents = generate_baked_html(nb; notebookfile_js=notebookfile_js, disable_ui=disable_ui, bind_server_url_js=bind_server_url_js, binder_url_js=binder_url_js)

            write(export_path, html_contents)
            if offer_binder && !isfile(export_jl_path)
                write(export_jl_path, read(path))
            end

            @info "Written to $(export_path)"

            Pluto.SessionActions.shutdown(session, nb)
        catch e
            @error "$path failed to run" exception=(e, catch_backtrace())
        end
    end
    @info "Done"
end


import Pkg
function try_get_pluto_version()
    try
        deps = Pkg.API.dependencies()

        p_index = findfirst(p -> p.name == "Pluto", deps)
        p = deps[p_index]

        if p.git_revision === nothing
            p.version
        else
            # ugh
            is_probably_a_commit_thing = all(in(('0':'9') ∪ ('a':'f')), p.git_revision)
            if !is_probably_a_commit_thing
                error("Do not add the Pluto dependency by specifying its BRANCH, but by specifying its VERSION or an exact COMMIT SHA.")
            end

            p.git_revision
        end
    catch e
        @error "Failed to get exact Pluto version from dependency. Your website is not guaranteed to work forever." exception=(e, catch_backtrace())
        Pluto.PLUTO_VERSION
    end
end


function generate_baked_html(notebook::Pluto.Notebook; version=nothing, notebookfile_js="undefined", bind_server_url_js="undefined", binder_url_js="undefined", disable_ui=true)
    state = Pluto.notebook_to_js(notebook)
    statefile64 = base64encode() do io
        Pluto.pack(io, state)
    end

    original = read(Pluto.project_relative_path("frontend", "editor.html"), String)

    if version isa Nothing
        version = try_get_pluto_version()
    end

    cdn_root = "https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@$(string(version))/frontend/"

    @info "Using CDN for Pluto assets:" cdn_root

    cdnified = replace(
	replace(original, 
		"href=\"./" => "href=\"$(cdn_root)"),
        "src=\"./" => "src=\"$(cdn_root)")
    
    result = replace(cdnified, 
        "<!-- [automatically generated launch parameters can be inserted here] -->" => 
        """
        <script data-pluto-file="launch-parameters">
        window.pluto_notebookfile = $(notebookfile_js)
        window.pluto_disable_ui = $(disable_ui ? "true" : "false")
        window.pluto_statefile = "data:;base64,$(statefile64)"
        window.pluto_bind_server_url = $(bind_server_url_js)
        window.pluto_binder_url = $(binder_url_js)
        </script>
        <!-- [automatically generated launch parameters can be inserted here] -->
        """
    )

    return result
end



end
