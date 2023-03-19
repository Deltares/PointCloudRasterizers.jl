var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = PointCloudRasterizers","category":"page"},{"location":"#PointCloudRasterizers","page":"Home","title":"PointCloudRasterizers","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for PointCloudRasterizers.","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Image: Stable) (Image: Dev) (Image: CI) (Image: Coverage)","category":"page"},{"location":"","page":"Home","title":"Home","text":"PointCloudRasterizers is a Julia package for creating geographical raster images from larger than memory pointclouds.","category":"page"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Use the Julia package manager:","category":"page"},{"location":"","page":"Home","title":"Home","text":"(v1.8) pkg> add https://github.com/Deltares/PointCloudRasterizers.jl","category":"page"},{"location":"#Usage","page":"Home","title":"Usage","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"using PointCloudRasterizers\nusing LazIO\nusing GeoArrays\nusing Statistics\n\n# Open LAZ file\nlazfn = joinpath(dirname(pathof(LazIO)), \"..\", \"test/libLAS_1.2.laz\")\n\n# LAS file support is provided through LazIO.open() as well\npointcloud = LazIO.open(lazfn)","category":"page"},{"location":"","page":"Home","title":"Home","text":"# Index pointcloud\ncellsizes = (1.,1.) #can also use [1.,1.]\nraster_index = index(pointcloud, cellsizes)\n\n# get some information about the index\n\n# the dataset the index was calculated from\nraster_index.ds\n\n# ::GeoArray of point density per cell\nraster_index.counts\n\n# find highest recorded point density\nmaximum(raster_index.counts)\n\n# one dimensional vector of index values joining points to cells\nraster_index.index","category":"page"},{"location":"","page":"Home","title":"Home","text":"The .index is created using LinearIndices, so the index is a single integer value per cell rather than cartesian (X,Y) syntax","category":"page"},{"location":"","page":"Home","title":"Home","text":"Once an index is created, users can pass the index to the reduce function to convert to a raster.","category":"page"},{"location":"","page":"Home","title":"Home","text":"# Reduce to raster\nraster = reduce(raster_index, field=:Z, reducer=median)","category":"page"},{"location":"","page":"Home","title":"Home","text":"The reducer can be functions such as mean, median, length but can also take custom functions.","category":"page"},{"location":"","page":"Home","title":"Home","text":"# calculate raster of median height using an anonymous function\nheight_percentile = reduce(raster_index, field=:Z, reducer = x -> quantile(x,0.5))","category":"page"},{"location":"","page":"Home","title":"Home","text":"field is always a symbol and can either be :X, :Y, or :Z. In the event that your area of interest and/or cellsize is square, using :X or :Y may both return the same results.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Any reduced layer is returned as a GeoArray.","category":"page"},{"location":"","page":"Home","title":"Home","text":"# access the underlying data GeoArray\nraster.A\n# affine map information\nraster.f\n# crs information\nraster.crs","category":"page"},{"location":"","page":"Home","title":"Home","text":"Lastly, users can filter points matching some condition.","category":"page"},{"location":"","page":"Home","title":"Home","text":"# Filter on last returns (inclusive)\nlast_return(p) = return_number(p) == number_of_returns(p)\nfilter!(raster_index, last_return)","category":"page"},{"location":"","page":"Home","title":"Home","text":"Filters are done in-place and create a new index matching the condition. It does not change the loaded dataset.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Filtering can also be done compared to a computed surface. For example, if we want to select all points within some tolerance of the median raster from above:","category":"page"},{"location":"","page":"Home","title":"Home","text":"within_tol(p, raster_value) = isapprox(p.Z, raster_value, atol=5.0)\nfilter!(idx, raster, within_tol)","category":"page"},{"location":"","page":"Home","title":"Home","text":"# Save raster to tiff\nGeoArrays.write!(\"last_return_median.tif\", raster)","category":"page"},{"location":"#Future-Work","page":"Home","title":"Future Work","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Generalize naming\nRemove hardcoded Laz iteration\nReduce index itself\nIntegrate indexes, bounds into Julia ecosystem","category":"page"},{"location":"#License","page":"Home","title":"License","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"MIT","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [PointCloudRasterizers]","category":"page"},{"location":"#PointCloudRasterizers.PointCloudIndex","page":"Home","title":"PointCloudRasterizers.PointCloudIndex","text":"PointCloudIndex\n\nGeoArray with the number of points in each cell and an index for each point pointing to the cell its in.\n\nConstruct one by calling index.\n\n\n\n\n\n","category":"type"},{"location":"#Base.filter!","page":"Home","title":"Base.filter!","text":"filter!(index::PointCloudIndex, raster::GeoArray, condition=nothing)\n\nFilter an index in place given a raster and a condition. The condition is applied to each point in the index, together with the cell value of the raster at that point, as in condition(p, raster[ind]).\n\nThe raster should be the same size as the index.\n\n\n\n\n\n","category":"function"},{"location":"#Base.filter!-2","page":"Home","title":"Base.filter!","text":"filter!(index::PointCloudIndex, condition=nothing)\n\nFilter an index in place given a condition. The condition is applied to each LazIO.LazPoint in the index.\n\n\n\n\n\n","category":"function"},{"location":"#Base.reduce-Union{Tuple{PointCloudRasterizers.PointCloudIndex}, Tuple{T}} where T","page":"Home","title":"Base.reduce","text":"reduce(index::PointCloudIndex; field::Function=GeoInterface.z, reducer=minimum, output_type=Val(Float64))\n\nReduce the indexed pointcloud index to a raster with type output_type, using the field of the points to reduce with reducer. For example, one might reduce on minimum and :z, to get the lowest z (elevation) value of all points intersecting each raster cell.\n\n\n\n\n\n","category":"method"},{"location":"#PointCloudRasterizers.index-Union{Tuple{T}, Tuple{T, Any}} where T","page":"Home","title":"PointCloudRasterizers.index","text":"index(ds, cellsizes; bbox=GeoInterface.extent(ds), crs=GeoInterface.crs(ds))\n\nIndex a pointcloud ds to a raster, for given cellsizes. The bbox and crs will be the CRS of the output raster and are by default derived from ds. ds should implement GeoInterface as a MultiPoint geometry.\n\nNote that the the cellsizes, together with the minima of the extent are leading in determining the output. If the cellsizes do not fit precisely in the bbox, the output will be less than a cellsize larger than the maxima provided in bbox.\n\nReturns a PointCloudIndex.\n\n\n\n\n\n","category":"method"},{"location":"#PointCloudRasterizers.index-Union{Tuple{X}, Tuple{T}, Tuple{T, GeoArrays.GeoArray{X, A} where A<:AbstractArray{X, 3}}} where {T, X}","page":"Home","title":"PointCloudRasterizers.index","text":"index(ds, ga::GeoArray)\n\nIndex a pointcloud ds with the spatial information of an existing GeoArray ga. Returns a PointCloudIndex.\n\n\n\n\n\n","category":"method"}]
}
