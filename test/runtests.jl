using PlutoUtils.Export
using Test

flatmap(args...) = vcat(map(args...)...)

list_files_recursive(dir=".") = let
    paths = flatmap(walkdir(dir)) do (root, dirs, files)
        joinpath.([root], files)
    end
    relpath.(paths, [dir])
end

make_test_dir() = let
    original = joinpath(@__DIR__, "dir1")
    new = tempname(cleanup=false)
    cp(original, new)
    new
end


@testset "Basic github action" begin
    test_dir = make_test_dir()
    @show test_dir
    cd(test_dir)
    @test sort(list_files_recursive()) == sort([
        "a.jl",
        "b.pluto.jl",
        "notanotebook.jl",
        "subdir/c.plutojl",
    ])

    github_action()

    @test sort(list_files_recursive()) == sort([
        "index.md",
        "a.jl",
        "a.html",
        "b.pluto.jl",
        "b.html",
        "notanotebook.jl",
        "subdir/c.plutojl",
        "subdir/c.html",
    ])
end


@testset "Separate state files" begin
    test_dir = make_test_dir()
    @show test_dir
    cd(test_dir)
    @test sort(list_files_recursive()) == sort([
        "a.jl",
        "b.pluto.jl",
        "notanotebook.jl",
        "subdir/c.plutojl",
    ])

    github_action(
        offer_binder=true,
        baked_state=false,
    )

    @test sort(list_files_recursive()) == sort([
        "index.md",

        "a.jl",
        "a.html",
        "a.plutostate",

        "b.pluto.jl",
        "b.html",
        "b.plutostate",

        "notanotebook.jl",

        "subdir/c.plutojl",
        "subdir/c.html",
        "subdir/c.plutostate",
    ])

    @test occursin("a.jl", read("a.html", String))
    @test occursin("a.plutostate", read("a.html", String))
end

