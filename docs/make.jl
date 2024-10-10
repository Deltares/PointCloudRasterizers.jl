using PointCloudRasterizers
using Documenter

DocMeta.setdocmeta!(PointCloudRasterizers, :DocTestSetup, :(using PointCloudRasterizers); recursive=true)

makedocs(;
    modules=[PointCloudRasterizers],
    authors="Maarten Pronk <git@evetion.nl>, Deltares and contributors.",
    repo="https://github.com/Deltares/PointCloudRasterizers.jl/blob/{commit}{path}#{line}",
    sitename="PointCloudRasterizers.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://deltares.github.io/PointCloudRasterizers.jl",
        assets=String[],
        repolink="https://deltares.github.io/PointCloudRasterizers.jl"
    ),
    pages=[
        "Home" => "index.md",
    ]
)

deploydocs(;
    repo="github.com/Deltares/PointCloudRasterizers.jl",
    devbranch="master"
)
