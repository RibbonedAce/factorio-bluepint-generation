package.path = "../../?.lua"

local BPGNGhostEntity = require("metatables.entity.BPGNGhostEntity")


---@class BPGNElectricPole:BPGNGhostEntity
local BPGNElectricPole = {}

---@param entity_args LuaSurface.create_entity_param.electric_pole
function BPGNElectricPole.create(entity_args)
    return BPGNGhostEntity.create(entity_args, {}, BPGNElectricPole)
end

return BPGNElectricPole
