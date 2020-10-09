using LazIO

function countsgrid(bbox, cellsizes)
    min_x, min_y, min_z, max_x, max_y, max_z = bbox
    rows = Int(cld(max_x - min_x, cellsizes[1]))
    cols = Int(cld(max_y - min_y, cellsizes[2]))
    # heights = Int(cld(max_z - min_z, cellsizes[3]))
    zeros(Int64, rows, cols) # , heights)
end
