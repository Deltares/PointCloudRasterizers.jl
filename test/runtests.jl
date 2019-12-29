using PointCloudRasterizers
if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end

using LazIO
using LazIO
using GeoArrays
using Statistics

# Open LAZ file
lazfn = joinpath(dirname(pathof(LazIO)), "..", "test/libLAS_1.2.laz")
pointcloud = LazIO.open(lazfn)

# Index pointcloud
cellsizes = (1.,1.)
idx = index(pointcloud, cellsizes)

# Filter on last returns (inclusive)
last_return(p) = LazIO.return_number(p) == LazIO.number_of_returns(p)
filter!(idx, last_return)

# Reduce to raster
raster = reduce(idx, field=:Z, reducer=median)

within_tol(p, raster_value) = isapprox(p.Z, raster_value, atol=5.0)
filter!(idx, raster, within_tol)

# Save raster to tiff
GeoArrays.write!("last_return_median.tif", raster)
