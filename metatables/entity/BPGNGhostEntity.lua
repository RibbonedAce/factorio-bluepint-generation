package.path = "../../?.lua"

local Position = require("metatables.Position")


---@class PostCreationArgs
---@field insert_plan? BlueprintInsertPlan[]

---@class BPGNGhostEntity
---@field _raw LuaEntity
local BPGNGhostEntity = {}

---@param entity LuaEntity
---@param metatable? table
---@return BPGNGhostEntity
function BPGNGhostEntity.adapt(entity, metatable)
    local bpgn_entity = {_raw = entity}
    return setmetatable(bpgn_entity, metatable or BPGNGhostEntity)
end

---@param entity_args LuaSurface.create_entity_param
---@param post_creation_args PostCreationArgs
---@param metatable? table
---@return BPGNGhostEntity
function BPGNGhostEntity.create(entity_args, post_creation_args, metatable)
    local inner_name = entity_args.name
    if inner_name.name then
        inner_name = inner_name.name 
    end
    ---@cast inner_name string

    ---@type LuaSurface.create_entity_param.entity_ghost
    local ghost_entity_args = {
        inner_name = inner_name,
        position = entity_args.position,
        direction = entity_args.direction,
        filters = entity_args.filters,
        use_filters = entity_args.filters ~= nil,
        name = prototypes.entity["entity-ghost"],
        force = "player",
        recipe = entity_args.recipe,
        type = entity_args.type,
        output_priority = entity_args.output_priority,
        mirror = entity_args.mirror
    }

    local new_entity = game.surfaces[1].create_entity(entity_args)
    if not new_entity then
        error("Failed to create entity with args: " .. serpent.line(entity_args))
    end

    if post_creation_args and post_creation_args.insert_plan then
        new_entity.insert_plan = post_creation_args.insert_plan
    end
    
    return BPGNGhostEntity.adapt(new_entity, metatable)
end

---@return BlueprintInsertPlan[]
function BPGNGhostEntity:get_insert_plan()
    return self._raw.insert_plan
end

---@return Position
function BPGNGhostEntity:get_position()
    return Position.from{self._raw.position}
end

---@return string
function BPGNGhostEntity:to_key()
    return self._raw.name .. ": (" .. self._raw.position.x .. ", " .. self._raw.position.y .. ")"
end

---@return LuaEntity
function BPGNGhostEntity:get_raw()
    return self._raw
end

---@return boolean
function BPGNGhostEntity:destroy()
    local old_entity = self._raw
    self._raw = nil
    return old_entity.destroy()
end

return BPGNGhostEntity
