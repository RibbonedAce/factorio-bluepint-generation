package.path = "../?.lua"

local Position = require("metatables.Position")


---@class BPGNBoundingBox
---@field _raw BoundingBox
local BPGNBoundingBox = {}

---@param bounding_box BoundingBox
---@return BPGNBoundingBox
function BPGNBoundingBox.adapt(bounding_box)
    local bpgn_bounding_box = {_raw = bounding_box}
    return setmetatable(bpgn_bounding_box, BPGNBoundingBox)
end

---@return BoundingBox
function BPGNBoundingBox:get_raw()
    return self._raw
end

---@return Position
function BPGNBoundingBox:get_left_top()
    return Position.from{self._raw.left_top}
end

---@return Position
function BPGNBoundingBox:get_right_bottom()
    return Position.from{self._raw.right_bottom}
end

return BPGNBoundingBox
