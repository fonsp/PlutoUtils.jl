# PlutoUtils.jl

Nifty scripts to go with Pluto.jl.

## Pluto CLI

_Launch [Pluto directly from the command line!_

When installed, you can launch Pluto using the shell command `pluto`, and check the available options using `pluto --help`.

```julia
julia> ]
(v1.5) pkg> add https://github.com/fonsp/PlutoCLI.jl.git
```

then add `~/.julia/bin` to your `PATH`.

## Future

This will contain:

-   [x] the Pluto CLI - https://github.com/Roger-luo/PlutoCLI.jl/issues/2
-   [ ] notebook conversion tools: https://github.com/vdayanand/Jupyter2Pluto.jl

and several deployment methods:

-   [ ] Docker - https://github.com/fonsp/Pluto.jl/pull/230
-   [ ] heroku - ...
-   [ ] binder - https://github.com/fonsp/vscode-binder

And perhaps in the future:

-   maybe a headless browser/JS runtime to generate HTML and PDF from a notebook
-   once Pluto notebooks contain package environments - some tools for this

Some of this might move into Pluto itself - let's see how it goes!

Because this repository will mostly be short little scripts, it uses the [Unlicense](./LICENSE), the most permissive license. This means that people can copy the utility functions and edit them to suit their needs, without having to worry about licensing. (This is the same license as the Pluto sample notebooks.) _If you want to contribute but you feel like this license is not approriate, open up an issue and we'll look at alternatives!_
