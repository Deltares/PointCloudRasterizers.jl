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
#LAS file support is provided through LazIO.open() as well
pointcloud = LazIO.open(lazfn)
```

```julia
# Index pointcloud
cellsizes = (1.,1.) #can also use [1.,1.]
raster_index = index(pointcloud, cellsizes)

#get some information about the index

#the dataset the index was calculated from
raster_index.ds

#::GeoArray of point density per cell
raster_index.counts

#find highest recorded point density
maximum(raster_index.counts)

#one dimensional vector of index values joining points to cells
raster_index.index
```
The `.index` is created using `LinearIndices` so the index is a single integer value per cell rather than cartesian (X,Y) syntax

```julia
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
```

`field` is always a symbol and can either be `:X`, `:Y`, or `:Z`. In the event that your area of interest and/or cellsize is square, using `:X` or `:Y` may both return the same results.

Any reduced layer is returned as a [GeoArray](https://github.com/evetion/GeoArrays.jl). 

```julia
#access the underlying data GeoArray
raster.A
#affine map information
raster.f
#crs information
raster.crs
```

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
