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
Search recursively for all Pluto notebooks in the current folder, and for each notebook:
- Run the notebook and wait for all cells to finish
- Export the state object
- Create a .html file with the same name as the notebook, which has:
  - The JS and CSS assets to load the Pluto editor
  - The state object embedded
  - Extra functionality enabled, such as hidden UI, binder button, and a live bind server

# Arguments
- `export_dir::String="."`: folder to write generated HTML files to (will create directories to preserve the input folder structure). Leave at the default `"."` to generate each HTML file in the same folder as the notebook file.
- `disable_ui::Bool=true`: hide all buttons and toolbars to make it look like an article.
- `baked_state::Bool=true`: base64-encode the state object and write it inside the .html file. If `false`, a separate `.plutostate` file is generated.
- `offer_binder::Bool=false`: show a "Run on Binder" button on the notebooks. Use `binder_url` to choose a binder repository.
- `binder_url::Union{Nothing,String}=nothing`: e.g. `https://mybinder.org/v2/gh/mitmath/18S191/e2dec90` TODO docs
- `bind_server_url::Union{Nothing,String}=nothing`: e.g. `https://bindserver.mycoolproject.org/` TODO docs

Additional keyword arguments will be passed on to the configuration of `Pluto`. See [`Pluto.Configuration`](@ref) for more info.
"""
function export_paths(notebook_paths::Vector{String}; export_dir=".", baked_state=true, copy_to_temp_before_running=false, offer_binder=false, disable_ui=true, bind_server_url=nothing, binder_url=nothing, kwargs...)
    # TODO how can we fix the binder version to a Pluto version? We can't use the Pluto hash because the binder repo is different from Pluto.jl itself. We can use Pluto versions, tag those on the binder repo.
    if offer_binder && binder_url === nothing
        @warn "We highly recommend setting the `binder_url` keyword argument with a fixed commit hash. The default is not fixed to a specific version, and the binder button will break when Pluto updates.
        
        This might be automated in the future."
    end
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
            # open and run the notebook
            notebook = Pluto.SessionActions.open(session, newpath; run_async=false)

            @info "Ready $(path)" hash

            html_path = without_pluto_file_extension(path) * ".html"

            export_path = joinpath(export_dir, html_path)
            export_jl_path = joinpath(export_dir, path)
            mkpath(dirname(export_path))


            notebookfile_js = if offer_binder
                if !isfile(export_jl_path)
                    write(export_jl_path, read(path))
                end
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

            state = Pluto.notebook_to_js(notebook)

            statefile_js = if !baked_state
                statefile_path = without_pluto_file_extension(path) * ".plutostate"
                open(statefile_path, "w") do io
                    Pluto.pack(io, state)
                end
                repr(basename(statefile_path))
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

            write(export_path, html_contents)
            
            @info "Written to $(export_path)"

            Pluto.SessionActions.shutdown(session, notebook)
        catch e
            @error "$path failed to run" exception=(e, catch_backtrace())
        end
    end
    @info "Done"
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

"A convenience function to call from a GitHub Action. See [`export_paths`](@ref) for the list of keyword arguments."
function github_action(; export_dir=".", generate_default_index=true, kwargs...)
    export_dir = Pluto.tamepath(export_dir)

    mkpath(export_dir)

    jlfiles = vcat(
        map(walkdir(".")) do (root, dirs, files)
            map(filter(endswith_pluto_file_extension, files)) do file
                joinpath(root, file)
            end
        end...
    )
    notebookfiles = filter(jlfiles) do f
        readline(f) == "### A Pluto.jl notebook ###"
    end
    export_paths(notebookfiles; export_dir=export_dir, kwargs...)

    generate_default_index && create_default_index(;export_dir=export_dir)
end

"If no index.hmtl, index.md, index.jl file exists, create a default index.md that GitHub Pages will render into an index page, listing all notebooks."
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

    exists = any(["index.html", "index.md", ("index"*e for e in pluto_file_extensions)...]) do f
        joinpath(export_dir, f) |> isfile
    end
    if !exists
        write(joinpath(export_dir, "index.md"), default_md)
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