module Export

export github_action, export_paths, generate_html

import Pluto
import Pluto: ServerSession
using HTTP
using Base64
using SHA
using Sockets


myhash = base64encode ∘ sha256

"""
    export_paths(src_and_dst; kwargs...)

For each notebook specified in `src_and_dst`:
- Run the notebook and wait for all cells to finish
- Export the state object
- Create a .html file with the same name as the notebook, which has:
  - The JS and CSS assets to load the Pluto editor
  - The state object embedded
  - Extra functionality enabled, such as hidden UI, binder button, and a live bind server

# Arguments
- `src_and_dst::AbstractVector{Pair{String,String}}`: a list of `source notebook (input) => destination folder (output)` pair.

# Keyword Arguments
- `disable_ui::Bool=true`: hide all buttons and toolbars to make it look like an article.
- `baked_state::Bool=true`: base64-encode the state object and write it inside the .html file. If `false`, a separate `.plutostate` file is generated.
- `offer_binder::Bool=false`: show a "Run on Binder" button on the notebooks. Use `binder_url` to choose a binder repository.
- `binder_url::Union{Nothing,String}=nothing`: e.g. `https://mybinder.org/v2/gh/mitmath/18S191/e2dec90` TODO docs
- `bind_server_url::Union{Nothing,String}=nothing`: e.g. `https://bindserver.mycoolproject.org/` TODO docs

Additional keyword arguments will be passed on to the configuration of `Pluto`. See [`Pluto.Configuration`](@ref) for more info.

# Example
```julia
export_paths([
    "/home/xxx/a.jl"=>"/tmp/build", 
    "/home/xxx/subfolder/b.jl"=>"/tmp/build/subfolder"
    ],
    offer_binder=true,
    )
```
"""
function export_paths(src_and_dst::AbstractVector{Pair{String,String}}; baked_state=true,
                      offer_binder=false, disable_ui=true, bind_server_url=nothing, binder_url=nothing, kwargs...)
    # TODO how can we fix the binder version to a Pluto version? We can't use the Pluto hash because the binder repo is different from Pluto.jl itself. We can use Pluto versions, tag those on the binder repo.
    if offer_binder && binder_url === nothing
        @warn "We highly recommend setting the `binder_url` keyword argument with a fixed commit hash. The default is not fixed to a specific version, and the binder button will break when Pluto updates.
        
        This might be automated in the future."
    end
    options = Pluto.Configuration.from_flat_kwargs(; kwargs...)
    session = Pluto.ServerSession(;options=options)

    for (i, (src, dst)) in enumerate(src_and_dst)
        try
            export_jl_path = joinpath(dst, basename(src))
            export_html_path = without_pluto_file_extension(export_jl_path) * ".html"
            export_statefile_path = without_pluto_file_extension(export_jl_path) * ".plutostate"
            mkpath(dirname(export_jl_path))
            mkpath(dirname(export_html_path))
            mkpath(dirname(export_statefile_path))

            jl_contents = read(src)



            @info "[$(i)/$(length(src_and_dst))] Opening $(src)"

            hash = myhash(jl_contents)
            # open and run the notebook (TODO: tell pluto not to write to the notebook file)
            notebook = Pluto.SessionActions.open(session, src; run_async=false)
            # get the state object
            state = Pluto.notebook_to_js(notebook)
            # shut down the notebook
            Pluto.SessionActions.shutdown(session, notebook)

            @info "Ready $(src)" hash
            


            notebookfile_js = if offer_binder
                repr(basename(export_jl_path))
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

            statefile_js = if !baked_state
                open(export_statefile_path, "w") do io
                    Pluto.pack(io, state)
                end
                repr(basename(export_statefile_path))
            else
                statefile64 = base64encode() do io
                    Pluto.pack(io, state)
                end

                "\"data:;base64,$(statefile64)\""
            end



            html_contents = generate_html(; 
                notebookfile_js=notebookfile_js, statefile_js=statefile_js,
                bind_server_url_js=bind_server_url_js, binder_url_js=binder_url_js,
                disable_ui=disable_ui
            )

            write(export_html_path, html_contents)
            
            if (var"we need the .jl file" = offer_binder) || 
                (var"the .jl file is already there and might have changed" = isfile(export_jl_path))
                write(export_jl_path, jl_contents)
            end

            @info "Written to $(export_html_path)"
        catch e
            @error "$src failed to run" exception=(e, catch_backtrace())
        end
    end
    @info "All notebooks processed"
end


function generate_html(;
        version=nothing, 
        notebookfile_js="undefined", statefile_js="undefined", 
        bind_server_url_js="undefined", binder_url_js="undefined", 
        disable_ui=true
    )::String

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
        window.pluto_statefile = $(statefile_js)
        window.pluto_bind_server_url = $(bind_server_url_js)
        window.pluto_binder_url = $(binder_url_js)
        </script>
        <!-- [automatically generated launch parameters can be inserted here] -->
        """
    )

    return result
end




## GITHUB ACTION

using Logging: global_logger
using GitHubActions: GitHubActionsLogger
get(ENV, "GITHUB_ACTIONS", "false") == "true" && global_logger(GitHubActionsLogger())

function scan_plutonotebooks_relativepath(notebook_dir::String)
    nbase = splitpath(notebook_dir) |> length
    jlfiles = vcat(
        map(walkdir(notebook_dir)) do (root, dirs, files)
            map(filter(endswith_pluto_file_extension, files)) do file
                fullpath = joinpath(root, file)
                joinpath(splitpath(fullpath)[nbase+1:end]...)
            end
        end...
    )
    notebookfiles = filter(jlfiles) do f
        readline(joinpath(notebook_dir, f)) == "### A Pluto.jl notebook ###"
    end
    return notebookfiles
end

"""
    github_action(; notebook_dir, export_dir, generate_default_index=true, kwargs...)

A convenience function to call from a GitHub Action.
It will scan the pluto notebooks in `notebook_dir` recursively and generate output files to `export_dir`.
See [`export_paths`](@ref) for the list of keyword arguments.
"""
function github_action(; notebook_dir, export_dir, generate_default_index=true, kwargs...)
    notebook_dir = Pluto.tamepath(notebook_dir)
    export_dir = Pluto.tamepath(export_dir)
    notebookfiles = scan_plutonotebooks_relativepath(notebook_dir)
    # generate output folders
    src_and_dst = map(notebookfiles) do relativepath
        joinpath(notebook_dir, relativepath) => joinpath(export_dir, dirname(relativepath))
    end

    export_paths(src_and_dst; kwargs...)

    generate_default_index && create_default_index(; export_dir=export_dir)
end

"If no index.hmtl, index.md, index.jl file exists, create a default index.md that GitHub Pages will render into an index page, listing all notebooks."
function create_default_index(; export_dir)
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

    @info "Generating default index..."
    exists = any(["index.html", "index.md", ("index"*e for e in pluto_file_extensions)...]) do f
        joinpath(export_dir, f) |> isfile
    end
    if !exists
        index_path = joinpath(export_dir, "index.md")
        write(index_path, default_md)
        @info "Index written to $(index_path)"
    end
end





## HELPERS

const pluto_file_extensions = [
    ".pluto.jl",
    ".jl",
    ".plutojl",
    ".pluto",
]

endswith_pluto_file_extension(s) = any(endswith(s, e) for e in pluto_file_extensions)

function without_pluto_file_extension(s)
    for e in pluto_file_extensions
        if endswith(s, e)
            return s[1:end-length(e)]
        end
    end
    s
end


import Pkg
function try_get_pluto_version()
    try
        deps = Pkg.API.dependencies()

        p_index = findfirst(p -> p.name == "Pluto", deps)
        p = deps[p_index]

        if p.is_tracking_registry
            p.version
        elseif p.is_tracking_path
            error("Do not add the Pluto dependency as a local path, but by specifying its VERSION or an exact COMMIT SHA.")
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






end
