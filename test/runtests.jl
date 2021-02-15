using PlutoUtils.Export
using Test

flatmap(args...) = vcat(map(args...)...)

list_files_recursive(dir) = let
    paths = flatmap(walkdir(dir)) do (root, dirs, files)
        joinpath.([root], files)
    end
    relpath.(paths, [dir])
end

original_dir1 = joinpath(@__DIR__, "dir1")
make_test_dir() = let
    new = tempname(cleanup=false)
    cp(original_dir1, new)
    new
end


@testset "Basic github action" begin
    test_dir = make_test_dir()
    @show test_dir
    inpath = test_dir
    outpath = joinpath(test_dir, "build")
    @test sort(list_files_recursive(inpath)) == sort([
        "a.jl",
        "b.pluto.jl",
        "notanotebook.jl",
        "subdir/c.plutojl",
    ])

    github_action(;
        notebook_dir=inpath,
        export_dir=outpath
        )

    @test sort(list_files_recursive(outpath)) == sort([ 
        "index.md",
        "a.jl",
        "a.html",
        "b.pluto.jl",
        "b.html",
        "subdir/c.html",
        "subdir/c.plutojl",
    ])

    # Test whether the notebook file did not get changed
    @test read(joinpath(original_dir1, "a.jl")) == read(joinpath(test_dir, "a.jl"))
end


@testset "Separate state files" begin
    test_dir = make_test_dir()
    inpath = test_dir
    outpath = joinpath(test_dir, "build")
    @show test_dir
    @test sort(list_files_recursive(inpath)) == sort([
        "a.jl",
        "b.pluto.jl",
        "notanotebook.jl",
        "subdir/c.plutojl",
    ])

    github_action(;
        notebook_dir=inpath,
        export_dir=outpath,
        offer_binder=true,
        baked_state=false,
    )

    @test sort(list_files_recursive(outpath)) == sort([
        "index.md",

        "a.html",
        "a.jl",
        "a.plutostate",

        "b.html",
        "b.pluto.jl",
        "b.plutostate",


        "subdir/c.html",
        "subdir/c.plutojl",
        "subdir/c.plutostate",
    ])

    @test occursin("a.jl", read(joinpath(outpath, "a.html"), String))
    @test occursin("a.plutostate", read(joinpath(outpath, "a.html"), String))
end

