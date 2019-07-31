using LazIO

function bbox(ds::LazIO.LazDataset)
    return MVector((ds.header.min_x, ds.header.min_y, ds.header.min_z, ds.header.max_x, ds.header.max_y, ds.header.max_z))
end

function scaled_bbox(ds::LazIO.LazDataset)
    return MVector(
    (
        (ds.header.min_x - ds.header.x_offset) / ds.header.x_scale_factor,
        (ds.header.min_y - ds.header.y_offset) / ds.header.y_scale_factor,
        (ds.header.min_z - ds.header.z_offset) / ds.header.z_scale_factor,
        (ds.header.max_x - ds.header.x_offset) / ds.header.x_scale_factor,
        (ds.header.max_y - ds.header.y_offset) / ds.header.y_scale_factor,
        (ds.header.max_z - ds.header.z_offset) / ds.header.z_scale_factor
        )
    )
end

function countsgrid(bbox, cellsizes)
    min_x, min_y, min_z, max_x, max_y, max_z = bbox
    rows = Int(cld(max_x - min_x, cellsizes[1]))
    cols = Int(cld(max_y - min_y, cellsizes[2]))
    # heights = Int(cld(max_z - min_z, cellsizes[3]))
    zeros(Int64, rows, cols) #, heights)
end
