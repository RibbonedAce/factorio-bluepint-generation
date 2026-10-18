package.path = "../?.lua"

local common = require("blueprint.common")
local Position = require("metatables.Position")


local output = {}

---@param plan_put function(args: GhostEntityArgs)
---@param crafting_entity_size integer
---@param placing "first" | "middle" | "last"
---@param planned_layout Layout
local function _place_single_fluid_row(
        plan_put,
        crafting_entity_size,
        placing,
        planned_layout
)
    local x_position = crafting_entity_size + 1

    for i = -crafting_entity_size, crafting_entity_size do
        plan_put{name = "pipe", position = {x_position, i}}
    end

    if placing == "first" then
        table.insert(planned_layout.fluid_output_positions, Position.from{crafting_entity_size + 1, -crafting_entity_size})
    end
end

---@param plan_put function(args: GhostEntityArgs)
---@param crafting_entity_size integer
---@param fluid_positions Position[]
---@param placing "first" | "middle" | "last"
---@param planned_layout Layout
local function _place_multiple_fluid_rows(
        plan_put,
        crafting_entity_size,
        fluid_positions,
        placing,
        planned_layout
)
    for i, m_position in ipairs(fluid_positions) do
        for j = 0, i - 1 do
            plan_put{name = "pipe", position = m_position + {j, 0}}
        end

        m_position = Position.from(m_position + {i - 1, 0})

        if m_position.y - 1 >= -crafting_entity_size then
            if m_position.y - 2 >= -crafting_entity_size then
                plan_put{name = "pipe-to-ground", position = m_position - {0, 1}, direction = south}
            else
                plan_put{name = "pipe", position = m_position - {0, 1}}
            end
        end

        if m_position.y + 1 <= crafting_entity_size then
            if m_position.y + 2 <= crafting_entity_size then
                plan_put{name = "pipe-to-ground", position = m_position + {0, 1}, direction = north}
            else
                plan_put{name = "pipe", position = m_position + {0, 1}}
            end
        end

        if placing == "first" then
            table.insert(planned_layout.fluid_output_positions, Position.from{m_position.x, -crafting_entity_size})
        end
    end
end

---@param plan_put function(args: GhostEntityArgs)
---@param crafting_entity_size integer
---@param fluid_positions Position[]
---@param placing "first" | "middle" | "last"
---@param planned_layout Layout
---@param fluids string[]
local function _place_fluid_rows(
        plan_put,
        crafting_entity_size,
        fluid_positions,
        placing,
        planned_layout,
        fluids
)
    if #fluids <= 0 then
        return
    end

    if #fluids == 1 then
        _place_single_fluid_row(plan_put, crafting_entity_size, placing, planned_layout)
    else
        _place_multiple_fluid_rows(plan_put, crafting_entity_size, fluid_positions, placing, planned_layout)
    end
end

---@param plan_put function(args: GhostEntityArgs)
---@param layer_info SkeletonLayer
---@param crafting_entity_size integer
---@param item_positions Position[]
---@param placing "first" | "middle" | "last"
---@param parity "even" | "odd"
---@param planned_layout Layout
local function _place_single_item_row(
        plan_put,
        layer_info,
        crafting_entity_size,
        item_positions,
        placing,
        parity,
        planned_layout
)
    local output_index = parity == "even" and 1 or #item_positions
    local output_item_position = item_positions[output_index]
    plan_put{name = layer_info.inserter, position = output_item_position, direction = west}

    for i = -crafting_entity_size, crafting_entity_size do
        plan_put{name = layer_info.belt.normal, position = {crafting_entity_size + 2, i}, direction = north}
    end

    if placing == "first" then
        table.insert(planned_layout.item_output_positions, Position.from{crafting_entity_size + 2, -crafting_entity_size})
    end
end

---@param plan_put function(args: GhostEntityArgs)
---@param skeleton BlueprintSkeleton
---@param crafting_entity_size integer
---@param item_positions Position[]
---@param placing "first" | "middle" | "last"
---@param parity "even" | "odd"
---@param planned_layout Layout
---@param num_item_rows integer
local function _place_item_rows(
        plan_put,
        skeleton,
        crafting_entity_size,
        item_positions,
        placing,
        parity,
        planned_layout,
        num_item_rows
)
    if num_item_rows > 0 and #skeleton.output_layers > 0 then
        _place_single_item_row(plan_put, skeleton.output_layers[1], crafting_entity_size, item_positions, placing, parity, planned_layout)
    end
end

---@param plan_put function(args: GhostEntityArgs)
---@param position Position
---@param electric_pole LuaEntityPrototype
---@param crafting_entity_size integer
---@param planned_layout Layout
local function _place_electric_poles(
        plan_put,
        position,
        electric_pole,
        crafting_entity_size,
        planned_layout
)
    for x = 1, math.floor(electric_pole.get_supply_area_distance() + 1) do
        for y = crafting_entity_size, -crafting_entity_size, -1 do
            local candidate_position = Position.from{x, y} + {crafting_entity_size, 0}

            if not planned_layout.positions[tostring(candidate_position + position)] then
                plan_put{name = "medium-electric-pole", position = candidate_position}
                return
            end
        end
    end
end

---@param args PlanPutArgs
function output.create_layout(args)
    common.setup_args(args, {components = args.recipe.products, flow_direction = "output"})

    _place_fluid_rows(
        args.plan_put, 
        args.crafting_entity_size, 
        args.fluid_positions,
        args.placing, 
        args.planned_layout, 
        args.fluids
    )
    _place_item_rows(
        args.plan_put, 
        args.skeleton, 
        args.crafting_entity_size, 
        args.item_positions, 
        args.placing, 
        args.parity, 
        args.planned_layout, 
        args.num_item_rows
    )
    _place_electric_poles(
        args.plan_put, 
        args.position, 
        args.electric_pole, 
        args.crafting_entity_size, 
        args.planned_layout
    )
end

return output
