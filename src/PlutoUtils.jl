module PlutoUtils

using Comonicon
using Pluto
using ExprTools
using Pluto.Configuration: Options, CompilerOptions, ServerOptions, from_flat_kwargs
using Pluto: open_in_default_browser, Notebook

include("patch.jl")

# all the following has a prefix JULIA_PLUTO
const PLUTO_ENV_VARIABLES = [
    "PROJECT",
    "WORKSPACE_USE_DISTRIBUTED",
    "RUN_NOTEBOOK_ON_LOAD",
    "PLUTO_WORKING_DIRECTORY",
]

_get_kw_name(x::Symbol) = x
function _get_kw_name(ex::Expr)
    if ex.head === :kw
        return _get_kw_name(ex.args[1])
    elseif ex.head === :(::)
        return _get_kw_name(ex.args[1])
    else
        error("invalid kwargs expression: $ex")
    end
end

function read_env(env::AbstractDict = ENV)
    for key in PLUTO_ENV_VARIABLES
        if haskey(env, "JULIA_PLUTO_" * key)
            return env[key]
        end
    end
end

# both `run` and `open` can accepet these options
const CLI_OPTIONS = [
    Expr(:kw, :(host::String), "127.0.0.1"),
    Expr(:kw, :(port::Int), 1234),
    Expr(:kw, :(launch_browser::Bool), true),
    Expr(:kw, :(project::String), "@."),
    Expr(:kw, :sysimage, nothing),
]

@static if VERSION > v"1.5.0-"
    push!(CLI_OPTIONS, Expr(:kw, :threads, nothing))
end

const CLI_OPTION_NAMES = map(_get_kw_name, CLI_OPTIONS)

const CLI_OPTION_DOCS = """
- `--host <ip>`: IP address of the host.
- `-p, --port <int>`: port you want to specify.
- `--launch-browser <bool>`: launch browser automatically or not.
- `--project <path>`: specify a project environment to run.
- `--sysimage <path>`: specify the path of a system image to use.
$(if VERSION > v"1.5.0-"
"- `-t, --threads <int>`: specify number of threads."
end
)
"""

defs = Dict{Symbol, Any}()
defs[:name] = :open
defs[:args] = [:(file::String)]
defs[:kwargs] = CLI_OPTIONS
defs[:body] = quote
    isfile(file) || error("file $file does not exist!")
    # from_flat_kwargs(;host=host, port=port, launch_browser=false, ...)
    options = $(Expr(:call, :from_flat_kwargs, Expr(:parameters, [Expr(:kw, each, each) for each in CLI_OPTION_NAMES]...)))
    session = Pluto.ServerSession(;options=options)
    # we overwrite the notebook options temporarily since
    # this session will be used for this notebook only
    nb = Pluto.SessionActions.open(session, file; compiler_options=nothing)
    return run_with_notebook_open(session, nb)
end

@eval begin
    """
    open a Pluto notebook at given path.

    # Args

    - `file`: file path of the Pluto notebook.

    # Options

    $(CLI_OPTION_DOCS)
    """
    @cast $(combinedef(defs))
end

defs = Dict{Symbol, Any}()
defs[:name] = :run
defs[:args] = []
defs[:kwargs] = CLI_OPTIONS
defs[:body] = quote
    options = $(Expr(:call, :from_flat_kwargs, Expr(:parameters, [Expr(:kw, each, each) for each in CLI_OPTION_NAMES]...)))
    s = Pluto.ServerSession(;options=options)
    return Pluto.run(s)
end

@eval begin
    """
    start Pluto notebook server.

    # Options

    $(CLI_OPTION_DOCS)
    """
    @cast $(combinedef(defs))
end

"Pluto CLI - Lightweight reactive notebooks for Julia"
@main

end
