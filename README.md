[![Build Status](https://travis-ci.org/Deltares/PointCloudRasterizers.jl.svg?branch=master)](https://travis-ci.org/Deltares/PointCloudRasterizers.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/1ky79ibw82f8rif2/branch/master?svg=true)](https://ci.appveyor.com/project/evetion/pointcloudrasterizers-jl/branch/master)
# [WIP] PointCloudRasterizers.jl
Rasterize larger than memory pointclouds

PointCloudRasterizers is a Julia package for creating geographical raster images from larger than memory pointclouds.

## Installation

Use the Julia package manager:
```julia
(v1.1) pkg> add https://github.com/Deltares/PointCloudRasterizers.jl
```

## Usage

```julia
using PointCloudRasterizers
using LazIO
using GeoArrays
using Statistics

# Open LAZ file
lazfn = joinpath(dirname(pathof(LazIO)), "..", "test/libLAS_1.2.laz")
pointcloud = LazIO.open(lazfn)

# Index pointcloud
cellsizes = (1.,1.)
raster_index = index(pointcloud, cellsizes)

# Filter on last returns (inclusive)
last_return(p) = return_number(p) == number_of_returns(p)
filter!(raster_index, last_return)
```
Filters are done in-place and create a new index matching the condition. It does not change the loaded dataset.

```julia
# Reduce to raster
raster = reduce(raster_index, field=:Z, reducer=median)
```
The reducer can be functions such as `mean`, `median`, `length` but can also take custom functions.

```julia
#calculate raster of median height using an anonymous function
height_percentile = reduce(raster_index, field=:Z, reducer = x -> quantile(x,0.5))

#calculate raster of point density per cell
counts_x = reduce(raster_index, field=:X, reducer=length)

#find highest recorded point density
findmax(skipmissing(counts_x[:,:,1]))
```
`field` is always a symbol and can either be `:X`, `:Y`, or `:Z`. In the event that your area of interest and/or cellsize is square, using `:X` or `:Y` may both return the same results.

```julia
# Save raster to tiff
GeoArrays.write!("last_return_median.tif", raster)
```

## Future Work
- Generalize naming
- Remove hardcoded Laz iteration
- Reduce index itself
- Integrate indexes, bounds into Julia ecosystem


## License
[MIT](LICENSE.md)
