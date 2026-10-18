package.path = "../../?.lua"

local BPGNGhostEntity = require("metatables.entity.BPGNGhostEntity")


---@class BPGNUndergroundPipe:BPGNGhostEntity
local BPGNUndergroundPipe = {}

---@param entity_args LuaSurface.create_entity_param.base
function BPGNUndergroundPipe.create(entity_args)
    return BPGNGhostEntity.create(entity_args, {}, BPGNUndergroundPipe)
end

return BPGNUndergroundPipe
