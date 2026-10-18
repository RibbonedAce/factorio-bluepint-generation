package.path = "../../?.lua"

local BPGNGhostEntity = require("metatables.entity.BPGNGhostEntity")


---@class BPGNCraftingMachine:BPGNGhostEntity
local BPGNCraftingMachine = {}

---@param items_array string[]
---@return BlueprintInsertPlan[]
local function _to_inventory_positions(items_array)
    ---@type BlueprintInsertPlan[]
    local insert_plans = {}
    ---@type table,string, integer>
    local item_stacks = {}

    for i, item_name in ipairs(items_array) do
        if not item_stacks[item_name] then
            item_stacks[item_name] = {}
        end

        table.insert(item_stacks[item_name], i - 1)
    end

    for item_name, stacks in pairs(item_stacks) do
        local in_inventory = {}

        for _, stack in ipairs(stacks) do
            table.insert(in_inventory, {inventory = defines.inventory.crafter_modules, stack = stack})
        end

        table.insert(insert_plans, {id = {name = item_name}, items = {in_inventory = in_inventory}})
    end

    return insert_plans
end

---@param entity_args LuaSurface.create_entity_param.assembling_machine | LuaSurface.create_entity_param.furnace
---@param modules? string[]
function BPGNCraftingMachine.create(entity_args, modules)
    local insert_plan = {}

    if modules then
        insert_plan = _to_inventory_positions(modules)
    end

    return BPGNGhostEntity.create(entity_args, {insert_plan = insert_plan}, BPGNCraftingMachine)
end

return BPGNCraftingMachine
