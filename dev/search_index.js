var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = PointCloudRasterizers","category":"page"},{"location":"#PointCloudRasterizers","page":"Home","title":"PointCloudRasterizers","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for PointCloudRasterizers.","category":"page"},{"location":"","page":"Home","title":"Home","text":"(Image: Stable) (Image: Dev) (Image: CI) (Image: Coverage)","category":"page"},{"location":"","page":"Home","title":"Home","text":"PointCloudRasterizers is a Julia package for creating geographical raster images from larger than memory pointclouds.","category":"page"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Use the Julia package manager (] in the REPL):","category":"page"},{"location":"","page":"Home","title":"Home","text":"(v1.11) pkg> add PointCloudRasterizers","category":"page"},{"location":"#Usage","page":"Home","title":"Usage","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Rasterizing pointclouds requires at least two steps:","category":"page"},{"location":"","page":"Home","title":"Home","text":"index(pc, cellsizes) a pointcloud, returning a PointCloudIndex, linking each point to a cellsizes sized raster cell.\nreduce(pc, f) a PointCloudIndex, creating an output raster by calling f on all points intersecting a given raster cell. f should return a single value.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Optionally one can ","category":"page"},{"location":"","page":"Home","title":"Home","text":"filter(pci, f) the PointCloudIndex, by removing points for which f is false. The function f receives a single point. filter! mutates the PointCloudIndex.\nfilter(pci, raster, f) the PointCloudIndex, by removing points for which f is false. The function f receives a single point and the corresponding cell value of raster. raster should have the same size and extents as counts(pci), like a previous result of reduce. filter! mutates the PointCloudIndex.","category":"page"},{"location":"","page":"Home","title":"Home","text":"All three operators iterate once over the pointcloud. While rasterizing thus takes at least two complete iterations, it enables rasterizing larger than memory pointclouds, especially if the provided pointcloud is a lazy iterator itself, such as provided by LazIO.","category":"page"},{"location":"","page":"Home","title":"Home","text":"In the case of a small pointcloud, it can be faster to disable this lazy iteration by calling collect on the LazIO pointcloud first.","category":"page"},{"location":"#Examples","page":"Home","title":"Examples","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"using PointCloudRasterizers\nusing LazIO\nusing GeoArrays\nusing Statistics\nusing GeoFormatTypes\nusing Extents\nusing GeoInterface\n\n# Open LAZ file, but can be any GeoInterface support MultiPoint geometry\nlazfn = joinpath(dirname(pathof(LazIO)), \"..\", \"test/libLAS_1.2.laz\")\npointcloud = LazIO.open(lazfn)","category":"page"},{"location":"","page":"Home","title":"Home","text":"# Index pointcloud\ncellsizes = (1.,1.)  # can also use [1.,1.]\npci = index(pointcloud, cellsizes)\n\n# By default, the bbox and crs of the pointcloud are used\npci = index(pointcloud, cellsizes; bbox=GeoInterface.extent(pointcloud),crs=GeoInterface.crs(pointcloud))\n\n# but they can be set manually\npci = index(pointcloud, cellsizes; bbox=Extents.Extent(X=(0, 1), Y=(0, 1)), crs=GeoFormatTypes.EPSG(4326))\n\n# or index using the cellsize and bbox of an existing GeoArray `ga`\npci = index(pointcloud, ga)\n\n# `index` returns a PointCloudIndex\n# which consists of\n\n# the pointcloud the index was calculated from\nparent(pci)\n\n# GeoArray of point density per cell\ncounts(pci)\n\n# vector of linear indices joining points to cells\nindex(pci)\n\n# For example, one can find the highest recorded point density with\nmaximum(counts(pci))","category":"page"},{"location":"","page":"Home","title":"Home","text":"The index(pci) is created using LinearIndices, so the index is a single integer value per cell rather than cartesian (X,Y) syntax.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Once an PointCloudIndex is created, users can pass it to the reduce function to convert to a raster.","category":"page"},{"location":"","page":"Home","title":"Home","text":"# Reduce to raster\nraster = reduce(pci, reducer=median)","category":"page"},{"location":"","page":"Home","title":"Home","text":"The reducer can be functions such as mean, median, length but can also take custom functions. By default the GeoInterface.z function is used to retrieve the values to be reduced on. You can provide your own function op that returns another value for your points.","category":"page"},{"location":"","page":"Home","title":"Home","text":"# calculate raster of median height using an anonymous function\nheight_percentile = reduce(pci, op=GeoInterface.z, reducer = x -> quantile(x,0.5))","category":"page"},{"location":"","page":"Home","title":"Home","text":"Any reduced layer is returned as a GeoArray.","category":"page"},{"location":"","page":"Home","title":"Home","text":"One can also filter points matching some condition.","category":"page"},{"location":"","page":"Home","title":"Home","text":"# Filter on last returns (inclusive)\nlast_return(p) = p.return_number == p.number_of_returns  # custom for LazIO Points\nfilter!(pci, last_return)","category":"page"},{"location":"","page":"Home","title":"Home","text":"Filters are done in-place and create a new index matching the condition. It does not change the loaded dataset. You can also call filter which returns a new index, copying the counts and the index, but it does not copy the dataset. This helps with trying out filtering settings without re-indexing the dataset.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Filtering can also be done compared to a computed surface. For example, if we want to select all points within some tolerance of the median raster from above:","category":"page"},{"location":"","page":"Home","title":"Home","text":"within_tol(p, raster_value) = isapprox(p.geometry[3], raster_value, atol=5.0)\nfilter!(pci, raster, within_tol)","category":"page"},{"location":"","page":"Home","title":"Home","text":"Finally, we can write the raster to disk.","category":"page"},{"location":"","page":"Home","title":"Home","text":"# Save raster to tiff\nGeoArrays.write(\"last_return_median.tif\", raster)\n\n# Or set some attributes for the tiff file\nGeoArrays.write(\"last_return_median.tif\", raster; nodata=-9999, options=Dict(\"TILED\"=>\"YES\", \"COMPRESS\"=>\"ZSTD\"))","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [PointCloudRasterizers]","category":"page"},{"location":"#PointCloudRasterizers.PointCloudIndex","page":"Home","title":"PointCloudRasterizers.PointCloudIndex","text":"PointCloudIndex\n\nGeoArray with the number of points in each cell and an index for each point pointing to the cell its in.\n\nConstruct one by calling index.\n\n\n\n\n\n","category":"type"},{"location":"#Base.filter!","page":"Home","title":"Base.filter!","text":"filter!(index::PointCloudIndex, condition=nothing)\n\nFilter an index in place given a condition. The condition is applied to each point in the index.\n\n\n\n\n\n","category":"function"},{"location":"#Base.filter!-2","page":"Home","title":"Base.filter!","text":"filter!(index::PointCloudIndex, raster::GeoArray, condition=nothing)\n\nFilter an index in place given a raster and a condition. The condition is applied to each point in the index, together with the cell value of the raster at that point, as in condition(p, raster[ind]).\n\nThe raster should be the same size as the index.\n\n\n\n\n\n","category":"function"},{"location":"#Base.reduce-Union{Tuple{PointCloudRasterizers.PointCloudIndex}, Tuple{T}} where T","page":"Home","title":"Base.reduce","text":"reduce(index::PointCloudIndex; field::Function=GeoInterface.z, reducer=min, output_type=Val(Float64))\n\nReduce the indexed pointcloud index to a raster with type output_type, using the field of the points to reduce with reducer. For example, one might reduce on minimum and :z, to get the lowest z (elevation) value of all points intersecting each raster cell.\n\n\n\n\n\n","category":"method"},{"location":"#PointCloudRasterizers.index-Union{Tuple{T}, Tuple{T, Any}} where T","page":"Home","title":"PointCloudRasterizers.index","text":"index(ds, cellsizes; bbox=GeoInterface.extent(ds), crs=GeoInterface.crs(ds))\n\nIndex a pointcloud ds to a raster, for given cellsizes. The bbox and crs will be the CRS of the output raster and are by default derived from ds. ds should implement GeoInterface as a MultiPoint geometry.\n\nNote that the the cellsizes, together with the minima of the extent are leading in determining the output. If the cellsizes do not fit precisely in the bbox, the output will be less than a cellsize larger than the maxima provided in bbox.\n\nReturns a PointCloudIndex.\n\n\n\n\n\n","category":"method"},{"location":"#PointCloudRasterizers.index-Union{Tuple{X}, Tuple{T}, Tuple{T, GeoArrays.GeoArray{X, N, A} where {N, A<:AbstractArray{X, N}}}} where {T, X}","page":"Home","title":"PointCloudRasterizers.index","text":"index(ds, ga::GeoArray)\n\nIndex a pointcloud ds with the spatial information of an existing GeoArray ga. Returns a PointCloudIndex.\n\n\n\n\n\n","category":"method"}]
}
