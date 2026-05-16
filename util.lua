local util = {}

north = defines.direction.north
east = defines.direction.east
south = defines.direction.south
west = defines.direction.west

function util.insert_all(table_to, table_from)
    for key, value in pairs(table_from) do
        table_to[key] = value
    end
end

return util