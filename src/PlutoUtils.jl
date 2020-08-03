module PlutoUtils

using Comonicon

# run(host, port::Integer; launchbrowser::Bool=false, session=ServerSession())

"""
Pluto CLI - Lightweight reactive notebooks for Julia

# Arguments

- `host`: default is 127.0.0.1 (localhost)

# Options

- `-p,--port <int>`: port you want to specify, default is 1234

# Flags

- `-l,--launchbrowser`: add this flag to launch browser.
"""
@main function pluto(;host="127.0.0.1", port::Int=1234, launchbrowser::Bool=false)
    # workaround the package environment problem
    # might be resolved by Pluto#142
    julia = joinpath(Sys.BINDIR::String, Base.julia_exename())
    script = """
    try
        import Pluto
    catch e
        if e isa ArgumentError
            print("Pluto not found, install Pluto? [Y/n]")
            x = read(stdin, Char)
            if x in ['Y', 'y', '\n']
                using Pkg
                Pkg.add("Pluto")
                import Pluto
            else
                exit(0)
            end
        end
    end

    Pluto.run("$host", $port; launchbrowser=$launchbrowser)    
    """


    PLUTO_ENV = filter(x->x.first!="JULIA_PROJECT", ENV)
    run(setenv(`$julia -e "$script"`, PLUTO_ENV))
end


end
