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
using GeoRasters

# Open LAZ file
ds = LazIO.open("points.laz")
boundingbox = unscaled_bbox(ds)

# Rasterize pointcloud
cellsizes = (10.,10.)
index = rasterize(ds, boundingbox, cellsizes)

# Take minimum elevation of points for each cell
minraster = reduce_pointcloud(ds, index, field=:Z, reducer=minimum)

# Save raster to tiff
GeoRasters.write!("minimum_z.tif", minraster)

```

## Future Work
- Generalize naming
- Remove hardcoded Laz iteration
- Reduce index itself
- Integrate indexes, bounds into Julia ecosystem


## License
[MIT](LICENSE.md)
