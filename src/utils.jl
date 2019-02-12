using LazIO

function bbox(ds::LazIO.LazDataset)
    return MVector((ds.header.min_x, ds.header.min_y, ds.header.min_z, ds.header.max_x, ds.header.max_y, ds.header.max_z))
end

function unscaled_bbox(ds::LazIO.LazDataset)
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
