package.path = "../?.lua"

local Position = {}
Position.mt = {}

function Position.from(table)
    if not table then
        error("No table passed to make position")
    end

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
        error("Not a valid table to turn into a position - structure not valid: " .. serpent.block(table))
    end

    if type(position.x) == "number" and type(position.y) == "number" then
        setmetatable(position, Position.mt)
        return position
    else
        error("Not a valid table to turn into a position - values not valid: " .. (position.x or "nil") .. ", " .. (position.y or "nil"))
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

Position.mt.__mul = function(p1, p2)
    local self = getmetatable(p1) == Position.mt and p1 or p2
    local other = self == p1 and p2 or p1

    if type(other) == "number" then
        return Position.from{self.x * other, self.y * other}
    else
        error("Cannot multiply position by non-number " .. tostring(other))
    end
end

Position.mt.__div = function(p1, p2)
    local self = getmetatable(p1) == Position.mt and p1 or p2
    local other = self == p1 and p2 or p1

    if type(other) == "number" then
        return Position.from{self.x / other, self.y / other}
    else
        error("Cannot divide position by non-number " .. tostring(other))
    end
end

Position.mt.__unm = function(self)
    return Position.from{-self.x, -self.y}
end

Position.mt.__eq = function(self, p_2)
    local other = Position.from(p_2)

    return self.x == other.x and self.y == other.y
end

Position.mt.__tostring = function(self)
    return "(" .. self.x .. ", " .. self.y .. ")"
end

return Position