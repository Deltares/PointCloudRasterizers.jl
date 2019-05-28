module PointCloudRasterizers

using GeoArrays
using ProgressMeter
using LazIO
using StaticArrays

include("utils.jl")

struct RasterIndex
	ga::GeoArray
	index::Vector{Int64}
end

function countsgrid(bbox, cellsizes)
    min_x, min_y, min_z, max_x, max_y, max_z = bbox
    rows = Int(cld(max_x - min_x, cellsizes[1]))
    cols = Int(cld(max_y - min_y, cellsizes[2]))
    zeros(Int64, rows, cols) #, heights)
end

function rasterize(ds, bbox, cellsizes, wkt="")
    indvec = zeros(Int, length(ds))

    min_x, min_y, min_z, max_x, max_y, max_z = bbox
    counts = countsgrid(bbox, cellsizes)
    linind = LinearIndices(counts)

    @showprogress "Building raster index.." for (i, p) in enumerate(ds)
        (min_x < p.X <= max_x && min_y < p.Y <= max_y ) || continue #&& min_z <= p.Z <= max_z) || continue
        row = Int(fld(p.X - min_x, cellsizes[1])+1)
        col = Int(fld(p.Y - min_y, cellsizes[2])+1)
        # height = div(p.Z - min_z, cellsize_z) + 1

        # Include points on edge
        p.X == max_x && (row -= 1)
        p.Y == max_y && (col -= 1)

        li = linind[row, col]#, height]
        @inbounds indvec[i] = li
        @inbounds counts[li] += 1
    end
    indvec, counts
	ga = GeoArray(reshape(counts, size(counts)..., 1), GeoArrays.geotransform_to_affine(SVector(min_x,cellsizes[1],0.,min_y,0.,cellsizes[2])), wkt)
	RasterIndex(ga, indvec)
end

function reduce_pointcloud(ds, index::RasterIndex; field::Symbol=:Z, reducer=minimum, filter=nothing)
    counts = copy(index.ga.A)
    # check if Dict is the best data structure for this
    d = Dict{Int, Vector{eltype(ds)}}()
    output = similar(counts, Union{Missing, Float64})

    @showprogress 1 "Reducing by index.." for (i, p) in enumerate(ds)

        # Gather facts
        @inbounds ind = index.index[i]
        ind == 0 && continue  # filtered point
        @inbounds cnt = counts[ind]
        # cnt == 0 && continue  # filtered point

        # allocate vector points
        if !haskey(d, ind)
            d[ind] = Vector{eltype(ds)}(undef, cnt)
        end

        # Assign point to tile and decrease sizes
        # as it's used as pointer in the tile
        d[ind][cnt] = p
        newcnt = counts[ind] -= 1

        # If count reaches 0
        # tile is complete and we can operate on it
        if newcnt == 0
            points = d[ind]
			values = map(x->getfield(x, field), points)
			if filter != nothing
				values = filter(values)
			end
            output[ind] = reducer(values)
            delete!(d, ind)  # remove thing from memory
        end
    end
	GeoArray(output, index.ga.f, index.ga.crs)
end

export
	bbox,
	unscaled_bbox,
	rasterize,
	reduce_pointcloud


end  # module
