using Pkg
Pkg.add(["Pluto", "PlutoUI", "Plots", "PackageCompiler"])

using PackageCompiler
create_sysimage([:Pluto, :PlutoUI]; precompile_execution_file="precompile.jl", replace_default=true)