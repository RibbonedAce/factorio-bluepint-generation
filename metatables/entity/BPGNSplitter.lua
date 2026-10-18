package.path = "../../?.lua"

local BPGNGhostEntity = require("metatables.entity.BPGNGhostEntity")


---@class BPGNSplitter:BPGNGhostEntity
local BPGNSplitter = {}

---@param entity_args LuaSurface.create_entity_param.splitter
function BPGNSplitter.create(entity_args)
    return BPGNGhostEntity.create(entity_args, {}, BPGNSplitter)
end

return BPGNSplitter
