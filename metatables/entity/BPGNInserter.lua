package.path = "../../?.lua"

local BPGNGhostEntity = require("metatables.entity.BPGNGhostEntity")


---@class BPGNInserter:BPGNGhostEntity
local BPGNInserter = {}

---@param entity_args LuaSurface.create_entity_param.inserter
function BPGNInserter.create(entity_args)
    return BPGNGhostEntity.create(entity_args, {}, BPGNInserter)
end

return BPGNInserter
