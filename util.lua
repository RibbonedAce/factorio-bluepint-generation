local util = {}

north = defines.direction.north
east = defines.direction.east
south = defines.direction.south
west = defines.direction.west

belt_prefixes = {"", "fast-", "express-"}
inserters = {"inserter", "fast-inserter", "bulk-inserter"}

function util.dict_insert_all(table_to, table_from)
    for key, value in pairs(table_from) do
        table_to[key] = value
    end
end

function util.array_insert_all(table_to, table_from)
    for _, obj in table_from do
        table.insert(table_to, obj)
    end
end

function util.invert(dict, merging_function)
    local m_function = merging_function or function(a, b) return b end
    local i_dict = {}

    for key, value in pairs(dict) do
        if i_dict[value] then
            i_dict[value] = m_function(i_dict[value], key)
        else
            i_dict[value] = key
        end
    end

    return i_dict
end

function util.map(array, func)
    local new_array = {}

    for _, value in ipairs(array) do
        table.insert(new_array, func(value))
    end

    return new_array
end

return util