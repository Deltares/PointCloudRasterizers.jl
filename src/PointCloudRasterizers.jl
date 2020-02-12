module PointCloudRasterizers

using GeoArrays
using ProgressMeter
using LazIO
using StaticArrays

include("utils.jl")

"""GeoArray with the number of points in each cell
and an index for each point pointing to the cell its in."""
struct PointCloudIndex
	ds::LazIO.LazDataset
	counts::GeoArray
	index::Vector{Int64}
end

crs(ds::LazIO.LazDataset) = ""  # implement at LazIO.jl

function index(ds::LazIO.LazDataset, cellsizes, bbox=LazIO.boundingbox(ds), wkt=crs(ds))

	# determine requested raster size
	unscaled_cellsizes = (cellsizes[1] / ds.header.x_scale_factor, cellsizes[2] / ds.header.y_scale_factor)
    indvec = zeros(Int, length(ds))
    min_x, min_y, min_z, max_x, max_y, max_z = bbox

	# Scale to stored coordinates
	u_min_x = round(Int32, (min_x - ds.header.x_offset) / ds.header.x_scale_factor)
	u_min_y = round(Int32, (min_y - ds.header.y_offset) / ds.header.y_scale_factor)
	u_min_z = round(Int32, (min_z - ds.header.z_offset) / ds.header.z_scale_factor)
	u_max_x = round(Int32, (max_x - ds.header.x_offset) / ds.header.x_scale_factor)
	u_max_y = round(Int32, (max_y - ds.header.y_offset) / ds.header.y_scale_factor)
	u_max_z = round(Int32, (max_z - ds.header.z_offset) / ds.header.z_scale_factor)
	unscaled_bbox = (u_min_x, u_min_y, u_min_z, u_max_x, u_max_y, u_max_z)

    counts = countsgrid(unscaled_bbox, unscaled_cellsizes)
    linind = LinearIndices(counts)
	@info "Indexing into a grid of $(size(counts))"

    @showprogress "Building raster index.." for (i, p) in enumerate(ds)
        (u_min_x < p.X <= u_max_x && u_min_y < p.Y <= u_max_y ) || continue #&& u_min_z <= p.Z <= u_max_z) || continue
        row = Int(fld(p.X - u_min_x, unscaled_cellsizes[1])+1)
        col = Int(fld(p.Y - u_min_y, unscaled_cellsizes[2])+1)
        # height = div(p.Z - min_z, cellsize_z) + 1

        # Include points on edge
        p.X == u_max_x && (row -= 1)
        p.Y == u_max_y && (col -= 1)
        # p.Z == u_max_z && (height -= 1)

        li = linind[row, col]#, height]
        @inbounds indvec[i] = li
        @inbounds counts[li] += 1
    end

	affine = GeoArrays.geotransform_to_affine(SVector(min_x,cellsizes[1],0.,min_y,0.,cellsizes[2]))
	ga = GeoArray(reshape(counts, size(counts)..., 1), affine, wkt)

	PointCloudIndex(ds, ga, indvec)
end

"""Filter out index on given condition."""
function Base.filter!(index::PointCloudIndex, condition=nothing)
	if condition != nothing
	    @showprogress 1 "Reducing points..." for (i, p) in enumerate(index.ds)
			@inbounds ind = index.index[i]
			ind == 0 && continue  # filtered point

			if ~condition(p)
				@inbounds index.counts.A[ind] -= 1
				@inbounds index.index[i] = 0
			end
		end
	end
end

"""Filter out index on given condition relative to a reduced layer."""
function Base.filter!(index::PointCloudRasterizers.PointCloudIndex, raster::GeoArray, condition=nothing)

    # check that size and affine info match
    size(index.counts.A) == size(raster.A) || throw(DimensionMismatch("The sizes of the index and raster do not match."))
    index.counts.f == raster.f || error("The affine information does not match")
    index.counts.crs == raster.crs || error("The crs information does not match")

    if condition != nothing
        @showprogress 1 "Reducing points..." for (i, p) in enumerate(index.ds)
            @inbounds ind = index.index[i]
            ind == 0 && continue  # filtered point
            raster_value = raster[ind]

            if ~condition(p, raster_value)
                @inbounds index.counts.A[ind] -= 1
                @inbounds index.index[i] = 0
            end
        end
    end
end

"""Reduce multiple points to single value in given indexed pointcloud."""
function Base.reduce(index::PointCloudIndex; field::Symbol=:Z, reducer=minimum, output_type=Float64)

	# Setup output grid
	counts = copy(index.counts.A)
	# output_type = fieldtype(eltype(index.ds), field)
    d = Dict{Int, Vector{output_type}}()
    output = similar(counts, Union{Missing, output_type})  # init missing

    @showprogress 1 "Reducing points..." for (i, p) in enumerate(index.ds)

        # Gather facts
        @inbounds ind = index.index[i]
        ind == 0 && continue  # filtered point
        @inbounds cnt = counts[ind]
        cnt == 0 && continue  # filtered point

        # allocate vector points
        if !haskey(d, ind)
            d[ind] = Vector{output_type}(undef, cnt)
        end

        # Assign point attribute to tile and decrease sizes
        # as it's used as pointer in the tile
        d[ind][cnt] = getfield(p, field)
        newcnt = counts[ind] -= 1

        # If count reaches 0
        # tile is complete and we can operate on it
        if newcnt == 0
            points = d[ind]

			if length(points) > 0
            	output[ind] = reducer(points)
			else
				output[ind] = missing
			end

            delete!(d, ind)
        end
    end

	# Scale coordinates back if necessary
	if field == :Z
		output = (output .+ index.ds.header.z_offset) .* index.ds.header.z_scale_factor
	end

	ga = GeoArray(output, index.counts.f, index.counts.crs)
	ga
end

export
	bbox,
	index,
	filter,
	reduce

end  # module
