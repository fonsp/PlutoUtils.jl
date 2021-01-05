module Export

import Pluto
import Pluto: ServerSession
using HTTP
using Base64
using SHA
using Sockets

myhash = base64encode ∘ sha256




function export_paths(notebook_paths::Vector{String}; export_dir=".", kwargs...)
    export_dir = Pluto.tamepath(export_dir)

    options = Pluto.Configuration.from_flat_kwargs(; kwargs...)
    session = Pluto.ServerSession(;options=options)

    for path in notebook_paths
        @info "Opening $(path)"
        hash = myhash(read(path))
        newpath = tempname()
        write(newpath, read(path))
        nb = Pluto.SessionActions.open(session, newpath; run_async=false)

        @info "Ready $(path)" hash

        html_contents = generate_baked_html(nb)
        html_filename = if endswith(path, ".jl")
            path[1:end-3] * ".html"
        else
            path * ".html"
        end

        write(joinpath(export_dir, html_filename), html_contents)

        @info "Written to $(joinpath(export_dir, html_filename))"

        Pluto.SessionActions.shutdown(session, nb)
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


function generate_baked_html(notebook::Pluto.Notebook; version=nothing)
    state = Pluto.notebook_to_js(notebook)
    statefile64 = base64encode() do io
        Pluto.pack(io, state)
    end

    original = read(Pluto.project_relative_path("frontend", "editor.html"), String)

    if version isa Nothing
        version = try_get_pluto_version()
    end

    cdn_root = "https://cdn.jsdelivr.net/gh/fonsp/Pluto.jl@$(string(version))/frontend/"

    cdnified = replace(
	replace(original, 
		"href=\"./" => "href=\"$(cdn_root)"),
        "src=\"./" => "src=\"$(cdn_root)")
    
    result = replace(cdnified, 
        "<!-- [automatically generated launch parameters can be inserted here] -->" => 
        """
        <script>
        window.pluto_statefile = "data:;base64,$(statefile64)"
        </script>
        <!-- [automatically generated launch parameters can be inserted here] -->
        """
    )

    return result
end



end