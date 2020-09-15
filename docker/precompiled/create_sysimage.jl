using Pkg
Pkg.add(["Pluto", "PlutoUI", "PackageCompiler"]) #"Plots", "Images", "ImageIO", "ImageMagick", 

using PackageCompiler
create_sysimage([:Pluto, :PlutoUI]; precompile_execution_file="warmup.jl", replace_default=true, cpu_target = PackageCompiler.default_app_cpu_target())