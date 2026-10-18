package.path = "../../?.lua"

local BPGNGhostEntity = require("metatables.entity.BPGNGhostEntity")


---@class BPGNTransportBelt:BPGNGhostEntity
local BPGNTransportBelt = {}

---@param entity_args LuaSurface.create_entity_param.transport_belt
function BPGNTransportBelt.create(entity_args)
    return BPGNGhostEntity.create(entity_args, {}, BPGNTransportBelt)
end

return BPGNTransportBelt
