using Pluto
include(joinpath(pkgdir(Pluto), "test", "runtests.jl"))

using Plots
p = plot(rand(5), rand(5))
display(MIME"text/html"(), p)
