using Pkg
Pkg.add(["Pluto", "PlutoUI", "PackageCompiler"]) #"Plots", "Images", "ImageIO", "ImageMagick",

using PackageCompiler
create_sysimage([:Pluto, :PlutoUI]; precompile_execution_file="warmup.jl", cpu_target = PackageCompiler.default_app_cpu_target(), sysimage_path="sys.so")
