module PointCloudRasterizers

using Extents
import Dictionaries
using GeoArrays
using GeoInterface
using GeoFormatTypes
using ProgressMeter

"""
    PointCloudIndex

GeoArray with the number of points in each cell
and an index for each point pointing to the cell its in.

Construct one by calling [`index`](@ref).
"""
struct PointCloudIndex{T,X}
    ds::T
    counts::GeoArray{X}
    index::Vector{Int}
end
Base.copy(idx::PointCloudIndex) = PointCloudIndex(idx.ds, copy(idx.counts), copy(idx.index))

function Base.show(io::IO, idx::PointCloudIndex{T,X}) where {T,X}
    println(io, "PointCloudIndex of $T with $(sum(idx.counts)) points")
end

Base.parent(pci::PointCloudIndex) = pci.ds
counts(pci::PointCloudIndex) = pci.counts
index(pci::PointCloudIndex) = pci.index


"""
    index(ds, cellsizes; bbox=GeoInterface.extent(ds), crs=GeoInterface.crs(ds))

Index a pointcloud `ds` to a raster, for given `cellsizes`. The `bbox` and `crs` will be
the CRS of the output raster and are by default derived from `ds`.
`ds` should implement GeoInterface as a MultiPoint geometry.

Note that the the cellsizes, together with the minima of the extent are leading in determining the output.
If the `cellsizes` do not fit precisely in the `bbox`, the output will be less than a cellsize
larger than the maxima provided in `bbox`.

Returns a [`PointCloudIndex`](@ref).
"""
function index(ds::T, cellsizes; bbox=GeoInterface.extent(ds; fallback=false), crs=GeoInterface.crs(ds), rounding::RoundingMode=RoundNearest)::PointCloudIndex{T,UInt16} where {T}

    # Check ds for GeoInterface support
    GeoInterface.isgeometry(ds) && (GeoInterface.geomtrait(ds) == GeoInterface.MultiPointTrait()) || throw(ArgumentError("`ds` must implement GeoInterface as a MultiPoint geometry"))
    isnothing(bbox) && throw(ArgumentError("Either `ds` must implement GeoInterface.extent(ds) or a `bbox` argument must be provided."))
    if isnothing(crs)
        crs = GeoFormatTypes.WellKnownText(GeoFormatTypes.CRS(), "")
    else
        GeoFormatTypes.mode(crs) isa GeoFormatTypes.CRS || throw(ArgumentError("`crs` must be provided as a GeoFormatTypes.CRS."))
    end

    cols = Int(cld(bbox.X[2] - bbox.X[1], cellsizes[1]))
    rows = Int(cld(bbox.Y[2] - bbox.Y[1], cellsizes[2]))
    nt = (min_x=bbox.X[1], min_y=bbox.Y[1], max_x=bbox.X[2], max_y=bbox.Y[2])
    ga = GeoArray(
        zeros(UInt16, cols, rows),  # max 65535 points per cell
        GeoArrays.AffineMap(
            GeoArrays.SMatrix{2,2}(float(cellsizes[1]), 0.0, 0.0, float(cellsizes[2])),
            GeoArrays.SVector(float(bbox.X[1]), float(bbox.Y[1]))
        ),
        convert(GeoFormatTypes.WellKnownText, crs),
    )

    return index!(ds, ga; rounding)
end
@deprecate index(ds, cellsizes, bbox, crs) index(ds, cellsizes; bbox=bbox, crs=crs)

function index!(ds::T, counts::GeoArray{X}; rounding::RoundingMode=RoundNearest)::PointCloudIndex{T,X} where {T,X}
    # Check input
    # TODO Check crs matching (including nothing for LazIO)
    GeoInterface.isgeometry(ds) && (GeoInterface.geomtrait(ds) == GeoInterface.MultiPointTrait()) || throw(ArgumentError("`ds` must implement GeoInterface as a MultiPoint geometry"))
    Base.fill!(counts, 0)

    # determine requested raster size
    indvec = zeros(Int, length(ds))

    linind = LinearIndices(counts)
    cols, rows = size(counts)

    # @showprogress 5 "Building index..." 
    for (i, p) in enumerate(GeoInterface.getgeom(ds))
        I = indices(counts, (GeoInterface.x(p), GeoInterface.y(p)), GeoArrays.Center(), rounding)
        checkbounds(Bool, counts, I) || continue
        @inbounds li = linind[I]
        @inbounds indvec[i] = li
        @inbounds counts[li] += 1
    end

    PointCloudIndex{T,X}(ds, counts, indvec)
end

"""
    index(ds, ga::GeoArray)

Index a pointcloud `ds` with the spatial information of an existing GeoArray `ga`.
Returns a [`PointCloudIndex`](@ref).
"""
function index(ds::T, ga::GeoArray{X})::PointCloudIndex{T,X} where {T,X}
    index!(ds, similar(ga, UInt16))
end


"""
    filter!(index::PointCloudIndex, condition=nothing)

Filter an `index` in place given a `condition`.
The `condition` is applied to each point in the `index`.
"""
function Base.filter!(index::PointCloudIndex, condition=nothing)
    if !isnothing(condition)
        n = 0

        for (i, p) in enumerate(GeoInterface.getpoint(index.ds))
            @inbounds ind = index.index[i]
            ind == 0 && continue  # filtered point

            if ~condition(p)
                @inbounds index.counts.A[ind] -= 1
                @inbounds index.index[i] = 0
                n += 1
            end
        end
    end
    return index
end

"""
    filter!(index::PointCloudIndex, raster::GeoArray, condition=nothing)

Filter an `index` in place given a `raster` and a `condition`.
The `condition` is applied to each point in the `index`, together
with the cell value of the raster at that point, as in `condition(p, raster[ind])`.

The `raster` should be the same size as the `index`.
"""
function Base.filter!(index::PointCloudIndex, raster::GeoArray, condition=nothing)

    # check that size and affine info match
    size(index.counts.A) == size(raster.A) || throw(DimensionMismatch("The sizes of the index and raster do not match."))
    index.counts.f == raster.f || error("The affine information does not match")
    index.counts.crs == raster.crs || error("The crs information does not match")

    if !isnothing(condition)
        n = 0
        @showprogress 5 "Filtering points..." for (i, p) in enumerate(GeoInterface.getpoint(index.ds))
            @inbounds ind = index.index[i]
            ind == 0 && continue  # filtered point
            raster_value = raster[ind]

            if ~condition(p, raster_value)
                @inbounds index.counts.A[ind] -= 1
                @inbounds index.index[i] = 0
                n += 1
            end
        end
    end
    return index
end

Base.filter(index::PointCloudIndex, condition=nothing) = filter!(copy(index), condition)
Base.filter(index::PointCloudIndex, raster::GeoArray, condition=nothing) = filter!(copy(index), raster, condition)

"""
    reduce(index::PointCloudIndex; field::Function=GeoInterface.z, reducer=min, output_type=Val(Float64))

Reduce the indexed pointcloud `index` to a raster with type `output_type`, using the `field` of the points to reduce with `reducer`.
For example, one might reduce on `minimum` and `:z`, to get the lowest z (elevation) value of all points intersecting each raster cell.
"""
function Base.reduce(index::PointCloudIndex; op::Function=GeoInterface.z, reducer=min, output_type::Val{T}=Val(Float64))::GeoArray{Union{Missing,T},2,Array{Union{Missing,T},2}} where {T}
    reduce(index, op, reducer, T)
end

function Base.reduce(idx::PointCloudIndex, op::Function, reducer, output_type::Type{T})::GeoArray{Union{Missing,T},2,Array{Union{Missing,T},2}} where {T}

    # Setup output grid
    count = counts(idx)
    output = similar(count, Union{Missing,T})::GeoArray{Union{Missing,T},2,Array{Union{Missing,T},2}}

    # If op.(index) fits in memory, we can use a more efficient method
    fitsinmemory = Sys.free_memory() / sum(counts(idx)) * sizeof(T) > 5
    if fitsinmemory
        opv = Vector{T}(undef, sum(count))::Vector{T}
        order = invperm(sortperm(filter(>(0), index(idx))))

        ii = 0
        @inbounds for (i, p) in enumerate(GeoInterface.getpoint(idx.ds))
            ind = index(idx)[i]
            ind == 0 && continue  # filtered point

            ii += 1
            ind = order[ii]
            opv[ind] = op(p)
        end
        ind = 1
        for (I, C) in enumerate(count::GeoArray{UInt16,2,Matrix{UInt16}})
            C == 0 && continue
            output[I] = reducer(@view opv[ind:ind+C-1])
            ind += C
        end
    else
        count = copy(count)::GeoArray{UInt16,2,Matrix{UInt16}}
        d = Dictionaries.Dictionary{Int,Vector{T}}(sizehint=cld(length(count), 4))

        @inbounds for (i, p) in enumerate(GeoInterface.getpoint(idx.ds))

            # Gather facts
            ind = index(idx)[i]
            ind == 0 && continue  # filtered point
            cnt = count[ind]
            cnt == 0 && continue  # filtered point

            # allocate vector points
            if !haskey(d, ind)
                insert!(d, ind, Vector{T}(undef, cnt))
            end

            # Assign point attribute to tile and decrease sizes
            # as it's used as pointer in the tile
            d[ind][cnt] = op(p)
            newcnt = count[ind] -= 1

            # If count reaches 0
            # tile is complete and we can operate on it
            if newcnt == 0
                points = d[ind]
                if length(points) > 0
                    output[ind] = reducer(points)
                else
                    error("No points in tile")
                end

                delete!(d, ind)
            end
        end
    end
    return output
end

function Base.reduce(index::PointCloudIndex, op::Function, reducer::Union{typeof(min),typeof(max)}, output_type::Type{T})::GeoArray{Union{Missing,T},2,Array{Union{Missing,T},2}} where {T}
    # Setup output grid
    output = similar(index.counts, Union{Missing,T})::GeoArray{Union{Missing,T},2,Array{Union{Missing,T},2}}
    fill!(output, missing)

    @inbounds for (i, p) in enumerate(GeoInterface.getpoint(index.ds))

        # Gather facts
        ind = index.index[i]::Int
        ind == 0 && continue  # filtered point
        output[ind] = ismissing(output[ind]) ? op(p) : reducer(output[ind], op(p))
    end
    return output
end


export
    index,
    reduce,
    counts

end  # module
