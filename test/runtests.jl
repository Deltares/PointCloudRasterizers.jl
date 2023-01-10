using Test

using GeoArrays
using GeoFormatTypes
using LazIO
using PointCloudRasterizers
using Statistics

lazfn = joinpath(dirname(pathof(LazIO)), "..", "test/libLAS_1.2.laz")
pointcloud = LazIO.open(lazfn)
cellsizes = (1.0, 1.0)
crs = EPSG(4326)

@testset "PointCloudRasterizers" begin

    @testset "Indexing" begin
        idx = index(pointcloud, cellsizes; crs=crs)
        @inferred index(pointcloud, cellsizes; crs=crs)
        @test typeof(idx) == PointCloudRasterizers.PointCloudIndex{LazIO.Dataset{0x00},Int64}
        @test maximum(idx.counts.A) == 2
    end

    @testset "Filtering" begin
        idx = index(pointcloud, cellsizes; crs=crs)
        last_return(p) = p.return_number == p.number_of_returns

        @inferred filter!(idx, last_return)
        filter!(idx, last_return)
        @test sum(idx.counts.A) == 497347

        min_terrain = similar(idx.counts, Float32)
        avg_height = mean(map(x -> x.geometry[3], pointcloud))
        Base.fill!(min_terrain, avg_height)
        ground(p, r) = p.geometry[3] < r
        filter!(idx, min_terrain, ground)
        @test sum(idx.counts.A) == 385861
    end

    @testset "Reducing" begin
        idx = index(pointcloud, cellsizes; crs=crs)
        raster = reduce(idx, reducer=median, output_type=Val(Float32))
        @inferred reduce(idx, reducer=median, output_type=Val(Float32))
        @test raster.crs == convert(GeoFormatTypes.WellKnownText{GeoFormatTypes.CRS}, crs)

        @test size(raster) == (5000, 5000, 1)
        @test all(832 .< skipmissing(raster) .< 973)
        @test all(typeof.(skipmissing(raster)) .== Float32)

        @test count(ismissing, raster.A) == 24503647
        @test count(!ismissing, raster.A) == 496353
        @test isapprox(mean(skipmissing(raster.A)), 861.5422515270361)

    end

    @testset "FileIO" begin
        idx = index(pointcloud, cellsizes; crs=crs)
        raster = reduce(idx, reducer=median, output_type=Val(Float32))
        eltype(raster) == Float32
        GeoArrays.write("last_return_median.tif", raster)
        @test isfile("last_return_median.tif")
        # rm("last_return_median.tif")

        idx = index(pointcloud, (10, 10); crs=crs)
        raster = reduce(idx, reducer=minimum, output_type=Val(Float64))
        eltype(raster) == Float64
        GeoArrays.write("last_return_minimum.tif", raster)
        @test isfile("last_return_minimum.tif")
        # rm("last_return_minimum.tif")
    end
end
