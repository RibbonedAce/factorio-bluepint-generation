local bpgn_util = {}

---@alias set<t> table<t, boolean>
---@alias ItemType "item" | "fluid"
---@alias FlowDirection "input" | "output"

north = defines.direction.north
east = defines.direction.east
south = defines.direction.south
west = defines.direction.west

function bpgn_util.dict_insert_all(table_to, table_from)
    for key, value in pairs(table_from) do
        table_to[key] = value
    end
end

function bpgn_util.array_insert_all(table_to, table_from)
    for _, obj in table_from do
        table.insert(table_to, obj)
    end
end

function bpgn_util.invert(dict, merging_function)
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

function bpgn_util.map(array, func)
    local new_array = {}

    for _, value in ipairs(array) do
        table.insert(new_array, func(value))
    end

    return new_array
end

---@generic T1
---@generic T2
---@param param_1 T1 | T2
---@param param_2 T1 | T2
---@param type_1 metatable | type
---@param type_2 metatable | type
---@return T1, T2
---@overload fun(param_1: T1, param_2: T2, type_1: metatable | type, type_2: metatable | type): T1, T2
---@overload fun(param_1: T2, param_2: T1, type_1: metatable | type, type_2: metatable | type): T1, T2
function bpgn_util.resolve_binary_params(param_1, param_2, type_1, type_2)
    if (getmetatable(param_1) == type_1 or type(param_1) == type_1)
            and (getmetatable(param_2) == type_2 or type(param_2) == type_2) then
        ---@cast param_1 T1
        ---@cast param_2 T2
        return param_1, param_2
    elseif (getmetatable(param_1) == type_2 or type(param_1) == type_2)
            and (getmetatable(param_2) == type_1 or type(param_2) == type_1) then
        ---@cast param_1 T2
        ---@cast param_2 T1
        return param_2, param_1
    end

    error("Cannot resolve between " .. tostring(param_1) .. " and " .. tostring(param_2) 
        .. " using types " .. tostring(type_1) .. " and " .. tostring(type_2))
end

return bpgn_util
