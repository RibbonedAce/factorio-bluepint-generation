package.path = "../?.lua"

local Position = {}
Position.mt = {}

function Position.from(table)
    if getmetatable(table) == Position.mt then
        return table
    end

    local position = {x=0, y=0}

    if table.x and table.y then
        position.x = table.x
        position.y = table.y
    elseif #table == 2 then
        position.x = table[1]
        position.y = table[2]
    else
        error("Not a valid table to turn into a position - structure not valid")
    end

    if type(position.x) == "number" and type(position.y) == "number" then
        setmetatable(position, Position.mt)
        return position
    else
        error("Not a valid table to turn into a position - values not valid: " .. position.x .. ", " .. position.y)
    end
end

Position.mt.__add = function(self, p_2)
    local other = Position.from(p_2)

    return Position.from{self.x + other.x, self.y + other.y}
end

Position.mt.__sub = function(self, p_2)
    local other = Position.from(p_2)

    return Position.from{self.x - other.x, self.y - other.y}
end

Position.mt.__unm = function(self)
    return Position.from{-self.x, -self.y}
end

Position.mt.__eq = function(self, p_2)
    local other = Position.from(p_2)

    return self.x == other.x and self.y == other.y
end

return Position