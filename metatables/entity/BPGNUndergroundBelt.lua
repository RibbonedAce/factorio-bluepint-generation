package.path = "../../?.lua"

local BPGNGhostEntity = require("metatables.entity.BPGNGhostEntity")


---@class BPGNUndergroundBelt:BPGNGhostEntity
local BPGNUndergroundBelt = {}

---@param entity_args LuaSurface.create_entity_param.underground_belt
function BPGNUndergroundBelt.create(entity_args)
    return BPGNGhostEntity.create(entity_args, {}, BPGNUndergroundBelt)
end

return BPGNUndergroundBelt
