using Test

using PointCloudRasterizers
using LazIO
using GeoArrays
using Statistics

lazfn = joinpath(dirname(pathof(LazIO)), "..", "test/libLAS_1.2.laz")
pointcloud = LazIO.open(lazfn)

cellsizes = (1.,1.)
idx = index(pointcloud, cellsizes)
raster = reduce(idx, field=:Z, reducer=median)

# indexing and reducing tests
@test typeof(idx) == PointCloudRasterizers.PointCloudIndex
@test count(ismissing,raster) == 24503457
@test count(!ismissing,raster) == 496543
@test isapprox(mean(skipmissing(raster.A)), 861.5422515270361)
@test maximum(idx.counts) == 2

# filtering tests
last_return(p) = LazIO.return_number(p) == LazIO.number_of_returns(p)
filter!(idx, last_return)
@test sum(idx.counts) == 497534

# file IO tests
GeoArrays.write!("last_return_median.tif", raster)
@test isfile("last_return_median.tif")
rm("last_return_median.tif")
