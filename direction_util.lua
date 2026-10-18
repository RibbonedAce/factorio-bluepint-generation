local Position = require("metatables.Position")


local direction_util = {}

---@param direction defines.direction
---@return defines.direction
function direction_util.get_opposite(direction)
    if direction == defines.direction.north then
        return defines.direction.south
    elseif direction == defines.direction.east then
        return defines.direction.west
    elseif direction == defines.direction.south then
        return defines.direction.north
    elseif direction == defines.direction.west then
        return defines.direction.east
    end

    error("Invalid direction: " .. tostring(direction))
end

---@param direction defines.direction
---@return defines.direction
function direction_util.get_horizontal_flip(direction)
    if direction == defines.direction.north or direction == defines.direction.south then
        return direction
    elseif direction == defines.direction.east or direction == defines.direction.west then
        return direction_util.get_opposite(direction)
    end

    error("Invalid direction: " .. tostring(direction))
end

---@param direction defines.direction
---@return defines.direction
function direction_util.get_vertical_flip(direction)
    if direction == defines.direction.east or direction == defines.direction.west then
        return direction
    elseif direction == defines.direction.north or direction == defines.direction.south then
        return direction_util.get_opposite(direction)
    end

    error("Invalid direction: " .. tostring(direction))
end

---@param direction defines.direction
---@return Position
function direction_util.vector(direction)
    if direction == defines.direction.north then
        return Position.from{0, -1}
    elseif direction == defines.direction.east then
        return Position.from{1, 0}
    elseif direction == defines.direction.south then
        return Position.from{0, 1}
    elseif direction == defines.direction.west then
        return Position.from{-1, 0}
    end

    error("Invalid direction: " .. tostring(direction))
end

return direction_util
