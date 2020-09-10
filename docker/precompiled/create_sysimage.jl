using Pkg
Pkg.add(["Pluto", "PlutoUI", "PackageCompiler"]) #"Plots", "Images", "ImageIO", "ImageMagick", 

using PackageCompiler
create_sysimage([:Pluto, :PlutoUI]; precompile_execution_file="precompile.jl", replace_default=true)