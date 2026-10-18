package.path = "../../?.lua"

local BPGNGhostEntity = require("metatables.entity.BPGNGhostEntity")


---@class BPGNPipe:BPGNGhostEntity
local BPGNPipe = {}

---@param entity_args LuaSurface.create_entity_param.base
function BPGNPipe.create(entity_args)
    return BPGNGhostEntity.create(entity_args, {}, BPGNPipe)
end

return BPGNPipe
