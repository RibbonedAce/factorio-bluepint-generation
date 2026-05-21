local util = {}

north = defines.direction.north
east = defines.direction.east
south = defines.direction.south
west = defines.direction.west

belt_prefixes = {"", "fast-", "express-"}
inserters = {"inserter", "fast-inserter", "bulk-inserter"}

function util.insert_all(table_to, table_from)
    for key, value in pairs(table_from) do
        table_to[key] = value
    end
end

return util