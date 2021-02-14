# PlutoUtils.jl

Nifty scripts to go with [Pluto.jl](https://github.com/fonsp/Pluto.jl).

Still work-in-progress, and very open to contributions!

---

## How to install

This package is meant for people who already know what Pluto is, so head over to [fonsp/Pluto.jl](https://github.com/fonsp/Pluto.jl) if you're new!

If you want to install the **Pluto CLI**, some **conversion scripts** (Jupyter, Literate), and more (see the list below), you can install PlutoUtils.jl:

```julia
julia> ]
(v1.5) pkg> add https://github.com/fonsp/PlutoUtils.jl
```

## Future

This will contain:

-   [ ] notebook conversion tools: https://github.com/vdayanand/Jupyter2Pluto.jl

and several deployment methods:

-   [ ] Docker - https://github.com/fonsp/Pluto.jl/pull/230
-   [ ] heroku - ...
-   [ ] JupyterHub extension - https://github.com/fonsp/vscode-binder
-   [ ] binder - https://github.com/fonsp/vscode-binder

And perhaps in the future:

-   maybe a headless browser/JS runtime to generate HTML and PDF from a notebook
-   once Pluto notebooks contain package environments - some tools for this

Some of this might move into Pluto itself - let's see how it goes!

# License

Because this repository will mostly be short little scripts, it uses the [Unlicense](./LICENSE), the most permissive license. This means that people can copy the utility functions and edit them to suit their needs, without having to worry about licensing. (This is the same license as the Pluto sample notebooks.) _If you want to contribute but you feel like this license is not approriate, open up an issue and we'll look at alternatives!_
