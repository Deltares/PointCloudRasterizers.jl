```@meta
CurrentModule = PointCloudRasterizers
```

# PointCloudRasterizers
Documentation for [PointCloudRasterizers](https://github.com/Deltares/PointCloudRasterizers.jl).

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://deltares.github.io/PointCloudRasterizers.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://deltares.github.io/PointCloudRasterizers.jl/dev)
[![CI](https://github.com/Deltares/PointCloudRasterizers.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/Deltares/PointCloudRasterizers.jl/actions/workflows/CI.yml)
[![Coverage](https://codecov.io/gh/Deltares/PointCloudRasterizers.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Deltares/PointCloudRasterizers.jl)

PointCloudRasterizers is a Julia package for creating geographical raster images from larger than memory pointclouds.

## Installation

Use the Julia package manager:
```julia
(v1.8) pkg> add https://github.com/Deltares/PointCloudRasterizers.jl
```

## Usage

```julia
using PointCloudRasterizers
using LazIO
using GeoArrays
using Statistics

# Open LAZ file
lazfn = joinpath(dirname(pathof(LazIO)), "..", "test/libLAS_1.2.laz")

# LAS file support is provided through LazIO.open() as well
pointcloud = LazIO.open(lazfn)
```

```julia
# Index pointcloud
cellsizes = (1.,1.) #can also use [1.,1.]
raster_index = index(pointcloud, cellsizes)

# get some information about the index

# the dataset the index was calculated from
raster_index.ds

# ::GeoArray of point density per cell
raster_index.counts

# find highest recorded point density
maximum(raster_index.counts)

# one dimensional vector of index values joining points to cells
raster_index.index
```
The `.index` is created using `LinearIndices`, so the index is a single integer value per cell rather than cartesian (X,Y) syntax

Once an index is created, users can pass the index to the `reduce` function to convert to a raster.

```julia
# Reduce to raster
raster = reduce(raster_index, field=:Z, reducer=median)
```
The reducer can be functions such as `mean`, `median`, `length` but can also take custom functions.

```julia
# calculate raster of median height using an anonymous function
height_percentile = reduce(raster_index, field=:Z, reducer = x -> quantile(x,0.5))
```

`field` is always a symbol and can either be `:X`, `:Y`, or `:Z`. In the event that your area of interest and/or cellsize is square, using `:X` or `:Y` may both return the same results.

Any reduced layer is returned as a [GeoArray](https://github.com/evetion/GeoArrays.jl).

```julia
# access the underlying data GeoArray
raster.A
# affine map information
raster.f
# crs information
raster.crs
```
Lastly, users can filter points matching some condition.

```julia
# Filter on last returns (inclusive)
last_return(p) = return_number(p) == number_of_returns(p)
filter!(raster_index, last_return)
```
Filters are done in-place and create a new index matching the condition. It does not change the loaded dataset.

Filtering can also be done compared to a computed surface.
For example, if we want to select all points within some tolerance of the median raster from above:

```julia
within_tol(p, raster_value) = isapprox(p.Z, raster_value, atol=5.0)
filter!(idx, raster, within_tol)
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

```@index
```

```@autodocs
Modules = [PointCloudRasterizers]
```
