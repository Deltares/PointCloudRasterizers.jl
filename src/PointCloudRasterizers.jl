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

function Base.show(io::IO, ::PointCloudIndex{T,X}) where {T,X}
    println(io, "PointCloudIndex of $T with $(sum(idx.counts)) points")
end


"""
    index(ds, cellsizes; bbox=GeoInterface.extent(ds), wkt=GeoInterface.crs(ds))

Index a pointcloud `ds` to a raster, for given `cellsizes` and `bbox`. The `crs` will be
the CRS of the output raster. `ds` should implement GeoInterface as a MultiPoint geometry,
including the 
Returns a [`PointCloudIndex`](@ref).
"""
function index(ds::T, cellsizes; bbox::Extents.Extent=GeoInterface.extent(ds), crs=GeoInterface.crs(ds))::PointCloudIndex{T} where {T}

    # Check ds for GeoInterface support
    GeoInterface.isgeometry(ds) && (GeoInterface.geomtrait(ds) == GeoInterface.MultiPointTrait()) || throw(ArgumentError("`ds` must implement GeoInterface as a MultiPoint geometry"))
    isnothing(bbox) && throw(ArgumentError("Either `ds` must implement GeoInterface.extent(ds) or a `bbox` argument must be provided."))
    crs isa GeoFormatTypes.CoordinateReferenceSystemFormat || throw(ArgumentError("Either `ds` must implement GeoInterface.crs(ds) or a `crs` must be provided as a GeoFormatType.CRS."))

    cols = Int(cld(bbox.X[2] - bbox.X[1], cellsizes[1]))
    rows = Int(cld(bbox.Y[2] - bbox.Y[1], cellsizes[2]))
    ga = GeoArray(zeros(Int64, cols, rows))
    nt = (min_x=bbox.X[1], min_y=bbox.Y[1], max_x=bbox.X[2], max_y=bbox.Y[2])
    bbox!(ga, nt)
    crs!(ga, crs)

    return index!(ds, ga)
end
@deprecate index(ds, cellsizes, bbox, crs) index(ds, cellsizes; bbox=bbox, crs=crs)

function index!(ds::T, counts::GeoArray{X})::PointCloudIndex{T} where {T,X}
    # Check input
    # TODO Check crs matching (including nothing for LazIO)
    GeoInterface.isgeometry(ds) && (GeoInterface.geomtrait(ds) == GeoInterface.MultiPointTrait()) || throw(ArgumentError("`ds` must implement GeoInterface as a MultiPoint geometry"))
    Base.fill!(counts, 0)

    # determine requested raster size
    indvec = zeros(Int, length(ds))

    linind = LinearIndices(counts)
    cols, rows, _ = size(counts)

    @showprogress 5 "Building index..." for (i, p) in enumerate(GeoInterface.getgeom(ds))
        col, row = indices(counts, (GeoInterface.x(p), GeoInterface.y(p)))
        ((0 < col < cols) && (0 < row < rows)) || continue
        li = linind[col, row]
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
function index(ds, ga::GeoArray)
    index!(ds, similar(Int, ga))
end


"""
    filter!(index::PointCloudIndex, condition=nothing)

Filter an `index` in place given a `condition`.
The `condition` is applied to each [`LazIO.LazPoint`](@ref) in the `index`.
"""
function Base.filter!(index::PointCloudIndex, condition=nothing)
    if !isnothing(condition)
        n = 0
        @showprogress 5 "Reducing points..." for (i, p) in enumerate(GeoInterface.getpoint(index.ds))
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
    reduce(index::PointCloudIndex; field::Function=GeoInterface.z, reducer=minimum, output_type=Val(Float64))

Reduce the indexed pointcloud `index` to a raster with type `output_type`, using the `field` of the points to reduce with `reducer`.
For example, one might reduce on `minimum` and `:z`, to get the lowest z (elevation) value of all points intersecting each raster cell.
"""
function Base.reduce(index::PointCloudIndex; op::Function=GeoInterface.z, reducer=minimum, output_type::Val{T}=Val(Float64))::GeoArray{Union{Missing,T},Array{Union{Missing,T},3}} where {T}

    # Setup output grid
    counts = copy(index.counts)
    d = Dictionaries.Dictionary{Int,Vector{T}}()
    output = similar(counts, Union{Missing,T})

    @inbounds @showprogress 5 "Reducing points..." for (i, p) in enumerate(GeoInterface.getpoint(index.ds))

        # Gather facts
        ind = index.index[i]
        ind == 0 && continue  # filtered point
        cnt = counts.A[ind]
        cnt == 0 && continue  # filtered point

        # allocate vector points
        if !haskey(d, ind)
            insert!(d, ind, Vector{T}(undef, cnt))
        end

        # Assign point attribute to tile and decrease sizes
        # as it's used as pointer in the tile
        d[ind][cnt] = op(p)
        newcnt = counts.A[ind] -= 1

        # If count reaches 0
        # tile is complete and we can operate on it
        if newcnt == 0
            points = d[ind]

            if length(points) > 0
                output.A[ind] = reducer(points)
            else
                output.A[ind] = missing
            end

            delete!(d, ind)
        end
    end
    return output
end

export
    index,
    reduce

end  # module
