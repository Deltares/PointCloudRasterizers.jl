using Test

using PointCloudRasterizers
using LazIO
using GeoArrays
using Statistics

@testset "Rasterize file" begin
    lazfn = joinpath(dirname(pathof(LazIO)), "..", "test/libLAS_1.2.laz")
    pointcloud = LazIO.open(lazfn)

    cellsizes = (1.0, 1.0)
    idx = index(pointcloud, cellsizes)
    raster = reduce(idx, field=:Z, reducer=median, output_type=Float32)
    @test size(raster) == (5000, 5000, 1)
    @test all(832 .< skipmissing(raster) .< 973)
    @test all(typeof.(skipmissing(raster)) .== Float32)

    # indexing and reducing tests
    @test typeof(idx) == PointCloudRasterizers.PointCloudIndex
    @test count(ismissing, raster.A) == 24503457
    @test count(!ismissing, raster.A) == 496543
    @test isapprox(mean(skipmissing(raster.A)), 861.5422515270361)
    @test maximum(idx.counts.A) == 2

    # filtering tests
    last_return(p) = LazIO.return_number(p) == LazIO.number_of_returns(p)
    filter!(idx, last_return)
    @test sum(idx.counts.A) == 497534

    # file IO tests
    GeoArrays.write!("last_return_median.tif", raster)
    @test isfile("last_return_median.tif")
    rm("last_return_median.tif")
end
