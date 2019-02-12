using Documenter, PointCloudRasterizers

makedocs(modules = [PointCloudRasterizers], sitename = "PointCloudRasterizers.jl")

deploydocs(
    repo = "github.com/Deltares/PointCloudRasterizers.jl.git",
)
