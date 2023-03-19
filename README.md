[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://deltares.github.io/PointCloudRasterizers.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://deltares.github.io/PointCloudRasterizers.jl/dev)
[![CI](https://github.com/Deltares/PointCloudRasterizers.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/Deltares/PointCloudRasterizers.jl/actions/workflows/CI.yml)
[![Coverage](https://codecov.io/gh/Deltares/PointCloudRasterizers.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Deltares/PointCloudRasterizers.jl)

# PointCloudRasterizers.jl
Rasterize larger than memory pointclouds

PointCloudRasterizers is a Julia package for creating geographical raster images from larger than memory pointclouds.

## Installation

Use the Julia package manager (`]` in the REPL):
```julia
(v1.8) pkg> add PointCloudRasterizers
```

## Usage

Rasterizing pointclouds requires at least two steps:
- `index(pc, cellsizes)` a pointcloud, returning a `PointCloudIndex`, linking each point to a `cellsizes` sized raster cell.
- `reduce(pc, f)` a `PointCloudIndex`, creating an output raster by calling `f` on all points intersecting a given raster cell. `f` should return a single value.

Optionally one can 
- `filter(pci, f)` the `PointCloudIndex`, by removing points for which `f` is false. The function `f` receives a single point. `filter!` mutates the `PointCloudIndex`.
- `filter(pci, raster, f)` the `PointCloudIndex`, by removing points for which `f` is false. The function `f` receives a single point and the corresponding cell value of `raster`. `raster` should have the same size and extents as `counts(pci)`, like a previous result of `reduce`. `filter!` mutates the `PointCloudIndex`.

All three operators iterate once over the pointcloud.
While rasterizing thus takes at least two complete iterations, it enables rasterizing larger than memory pointclouds, especially if the provided pointcloud is a lazy iterator itself, such as provided by LazIO.

In the case of a small pointcloud, it can be faster to disable this lazy iteration by calling `collect` on the LazIO pointcloud first.

## Examples

```julia
using PointCloudRasterizers
using LazIO
using GeoArrays
using Statistics
using GeoFormatTypes

# Open LAZ file, but can be any GeoInterface support MultiPoint geometry
lazfn = joinpath(dirname(pathof(LazIO)), "..", "test/libLAS_1.2.laz")
pointcloud = LazIO.open(lazfn)
```

```julia
# Index pointcloud
cellsizes = (1.,1.)  # can also use [1.,1.]
pci = index(pointcloud, cellsizes)

# By default, the bbox and crs of the pointcloud are used
pci = index(pointcloud, cellsizes; bbox::Extents.Extent=GeoInterface.extent(pointcloud),crs=GeoInterface.crs(pointcloud))

# but they can be set manually
pci = index(pointcloud, cellsizes; bbox=Extents.Extent(X=(0, 1), Y=(0, 1)), crs=GeoFormatTypes.EPSG(4326))

# or index using the cellsize and bbox of an existing GeoArray
pci = index(ds, ga::GeoArray)

# `index` returns a PointCloudIndex
# which consists of

# the dataset the index was calculated from
parent(pci)

# GeoArray of point density per cell
counts(pci)

# vector of linear indices joining points to cells
index(pci)

# For example, one can find the highest recorded point density with
maximum(counts(pci))
```


The `index(pci)` is created using `LinearIndices`, so the index is a single integer value per cell rather than cartesian (X,Y) syntax.

Once an `PointCloudIndex` is created, users can pass it to the `reduce` function to convert to a raster.

```julia
# Reduce to raster
raster = reduce(pci, reducer=median)
```
The reducer can be functions such as `mean`, `median`, `length` but can also take custom functions. By default the `GeoInterface.z` function is used to retrieve the values to be reduced on. You can provide your own function `op` that returns another value for your points.

```julia
# calculate raster of median height using an anonymous function
height_percentile = reduce(pci, op=GeoInterface.z, reducer = x -> quantile(x,0.5))
```
Any reduced layer is returned as a [GeoArray](https://github.com/evetion/GeoArrays.jl).

One can also filter points matching some condition.

```julia
# Filter on last returns (inclusive)
last_return(p) = p.return_number == p.number_of_returns  # custom for LazIO Points
filter!(pci, last_return)
```
Filters are done in-place and create a new index matching the condition. It does not change the loaded dataset. You can also call `filter` which returns a new index, copying the counts and the index, but it does **not** copy the dataset. This helps with trying out filtering settings without re-indexing the dataset.

Filtering can also be done compared to a computed surface.
For example, if we want to select all points within some tolerance of the median raster from above:

```julia
within_tol(p, raster_value) = isapprox(p.geometry[3], raster_value, atol=5.0)
filter!(pci, raster, within_tol)
```

Finally, we can write the raster to disk.

```julia
# Save raster to tiff
GeoArrays.write("last_return_median.tif", raster)

# Or set some attributes
GeoArrays.write("last_return_median.tif", raster; nodata=-9999, options=Dict("TILED"=>"YES", "COMPRESS"=>"ZSTD"))
```


## License
[MIT](LICENSE.md)
