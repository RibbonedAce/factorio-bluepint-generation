package.path = "../?.lua"

local math2d = require("core.lualib.math2d")


---@class Position
---@field x integer
---@field y integer
---@operator add(math2d_position_union | Position): Position
---@operator sub(math2d_position_union | Position): Position
---@operator mul(double): Position
---@operator div(double): Position
---@operator eq(math2d_position_union | Position): boolean
---@operator unm: Position
---@operator tostring: string
local Position = {}

---@param table math2d_position_union | Position
---@return Position
function Position.from(table)
    if getmetatable(table) == Position then
        ---@cast table Position
        return table
    end

    return setmetatable(table, Position)
end

---@return MapPosition.struct
function Position:to()
    return {x = self.x, y = self.y}
end

---@param p1 math2d_position_union
---@param p2 math2d_position_union
---@return Position
function Position.__add(p1, p2)
    return setmetatable(math2d.position.add(p1, p2), Position)
end

---@param p1 math2d_position_union
---@param p2 math2d_position_union
---@return Position
function Position.__sub(p1, p2)
    return setmetatable(math2d.position.subtract(p1, p2), Position)
end

---@param pos math2d_position_union
---@param num double
---@return Position
function Position.__mul(pos, num)
    return setmetatable(math2d.position.multiply_scalar(pos, num), Position)
end

---@param pos math2d_position_union
---@param num double
---@return Position
function Position.__div(pos, num)
    return setmetatable(math2d.position.divide_scalar(pos, num), Position)
end

---@param pos math2d_position_union
---@return Position
function Position.__unm(pos)
    return setmetatable(math2d.position.multiply_scalar(pos, -1), Position)
end

---@param p1 math2d_position_union
---@param p2 math2d_position_union
---@return boolean
function Position.__eq(p1, p2)
    return p1.x == p2.x and p1.y == p2.y
end

---@param pos math2d_position_union
---@return string
function Position.__tostring(pos)
    return "(" .. pos.x .. ", " .. pos.y .. ")"
end

return Position
