package.path = "../?.lua"

local common = require("blueprint.common")
local Position = require("metatables.Position")


local input = {}

---@param item_rows integer
---@return integer
local function _get_fluid_row_offset(item_rows)
    return item_rows == 0 and 0
            or item_rows <= 2 and item_rows + 2
            or item_rows * 3 + 2
end

---@param plan_put function(args: GhostEntityArgs)
---@param crafting_entity_size integer
---@param fluid_row_offset integer
---@param placing "first" | "middle" | "last"
---@param planned_layout Layout
---@param fluid string
local function _place_single_fluid_row(
        plan_put,
        crafting_entity_size,
        fluid_row_offset,
        placing,
        planned_layout,
        fluid
)
    local x_position = -1 * (crafting_entity_size + 1 + fluid_row_offset)

    for i = -crafting_entity_size, crafting_entity_size do
        plan_put{name = "pipe", position = Position.from{x_position, i}}
    end

    if placing == "first" then
        local new_recipes = common.get_recipes(fluid)

        if #new_recipes == 0 then
            plan_put{name = "pipe-to-ground", position = Position.from{x_position, -crafting_entity_size - 7}, direction = north}
            plan_put{name = "pipe-to-ground", position = Position.from{x_position, -crafting_entity_size - 1}, direction = south}
        else
            table.insert(planned_layout.fluid_input_positions, Position.from{x_position, -crafting_entity_size})
        end
    end
end

---@param plan_put function(args: GhostEntityArgs)
---@param crafting_entity_size integer
---@param fluid_positions Position[]
---@param fluid_row_offset integer
---@param placing "first" | "middle" | "last"
---@param planned_layout Layout
---@param fluids string[]
local function _place_multiple_fluid_rows(
        plan_put,
        crafting_entity_size,
        fluid_positions,
        fluid_row_offset,
        placing,
        planned_layout,
        fluids
)
    for i, m_position in ipairs(fluid_positions) do
        m_position = Position.from(m_position - {fluid_row_offset, 0})

        for j = 0, i - 1 do
            plan_put{name = "pipe", position = m_position - {j, 0}}
        end

        m_position = Position.from(m_position - {i - 1, 0})

        if m_position.y - 1 >= -crafting_entity_size then
            if m_position.y - 2 >= -crafting_entity_size or placing == "first" then
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
            if not fluids[i] then
                error("Fluid not found for fluid row " .. i)
            end

            local new_recipes = common.get_recipes(fluids[i])

            if #new_recipes == 0 then
                plan_put{name = "pipe-to-ground", position = Position.from{m_position.x, -crafting_entity_size - 7}, direction = north}
            else
                table.insert(planned_layout.fluid_input_positions, Position.from{m_position.x, -crafting_entity_size})
            end
        end
    end
end

---@param plan_put function(args: GhostEntityArgs)
---@param fluid_positions Position[]
---@param fluid_row_offset integer
local function _place_pipe_trench(plan_put, fluid_positions, fluid_row_offset)
    for _, m_position in ipairs(fluid_positions) do
        plan_put{name = "pipe-to-ground", position = m_position, direction = east}
        plan_put{name = "pipe-to-ground", position = m_position + {1 - fluid_row_offset, 0}, direction = west}
    end
end

---@param plan_put function(args: GhostEntityArgs)
---@param num_item_rows integer
---@param crafting_entity_size integer
---@param fluid_positions Position[]
---@param placing "first" | "middle" | "last"
---@param planned_layout Layout
---@param fluids string[]
local function _place_fluid_rows(
        plan_put,
        num_item_rows,
        crafting_entity_size,
        fluid_positions,
        placing,
        planned_layout,
        fluids
)

    local fluid_row_offset = _get_fluid_row_offset(num_item_rows)

    if #fluids == 1 then
        _place_single_fluid_row(plan_put, crafting_entity_size, fluid_row_offset, placing, planned_layout, fluids[1])
    else
        _place_multiple_fluid_rows(plan_put, crafting_entity_size, fluid_positions, fluid_row_offset, placing, planned_layout, fluids)
    end

    if fluid_row_offset > 0 then
        _place_pipe_trench(plan_put, fluid_positions, fluid_row_offset)
    end
end

---@param entity LuaEntityPrototype
---@param items? string[]
---@return string[] | nil
local function _get_input_filters(entity, items)
    if entity.type == "assembling-machine" or not items then
        return nil
    end

    local input_filters = {}

    for _, item_name in ipairs(items) do
        table.insert(input_filters, item_name)
    end

    return input_filters
end

---@param plan_put function(args: GhostEntityArgs)
---@param layer_info SkeletonLayer
---@param crafting_entity_size integer
---@param input_item_position Position
---@param input_filters string[] | nil
---@param placing "first" | "middle" | "last"
---@param planned_layout Layout
local function _place_single_item_row(
        plan_put, 
        layer_info, 
        crafting_entity_size, 
        input_item_position, 
        input_filters, 
        placing, 
        planned_layout, 
        items
)
    if not layer_info or not layer_info.inserter then
        error("layer_info is required")
    end

    plan_put{name = layer_info.inserter, position = input_item_position, filters = input_filters, direction = west}
    local x_position = -1 * (crafting_entity_size + 2)

    for i = -crafting_entity_size, crafting_entity_size do
        plan_put{name = layer_info.belt.normal, position = Position.from{x_position, i}, direction = south}
    end

    if placing == "first" then
        local new_recipes = common.get_recipes(items[1])

        if #new_recipes == 0 then
            plan_put{name = layer_info.belt.underground, position = {x_position, -crafting_entity_size - 7}, type = "input", direction = south}
            plan_put{name = layer_info.belt.underground, position = {x_position, -crafting_entity_size - 2}, type = "output", direction = south}
            plan_put{name = layer_info.belt.normal, position = {x_position, -crafting_entity_size - 1}, direction = south}
        else
            table.insert(planned_layout.item_input_positions, Position.from{x_position, -crafting_entity_size})
        end
    end
end

---@param plan_put function(args: GhostEntityArgs)
---@param layer_info_1 SkeletonLayer
---@param layer_info_2 SkeletonLayer
---@param crafting_entity_size integer
---@param input_item_position Position
---@param input_filters string[] | nil
---@param item_positions Position[]
---@param input_index integer
---@param placing "first" | "middle" | "last"
---@param planned_layout Layout
---@param items string[]
local function _place_double_item_rows(
        plan_put, 
        layer_info_1, 
        layer_info_2, 
        crafting_entity_size,
        input_filters,
        item_positions,
        input_index,
        input_item_position,
        placing,
        planned_layout,
        items
)
    plan_put{name = layer_info_1.inserter, position = item_positions[#item_positions - (input_index - 1)], filters = input_filters, direction = west}
    plan_put{name = layer_info_2.inserter, position = input_item_position, filters = input_filters, direction = west}

    for j = -crafting_entity_size, crafting_entity_size do
        if j == input_item_position.y - 1 then
            plan_put{name = layer_info_1.belt.underground, position = Position.from{input_item_position.x - 1, j}, type = "input", direction = south}
            plan_put{name = layer_info_2.belt.normal, position = Position.from{input_item_position.x - 2, j}, direction = south}
        elseif j == input_item_position.y then
            plan_put{name = layer_info_2.belt.splitter, position = Position.from{input_item_position.x - 1, j}, output_priority = "left", direction = south}
        elseif j == input_item_position.y + 1 then
            plan_put{name = layer_info_1.belt.underground, position = Position.from{input_item_position.x - 1, j}, type = "output", direction = south}
            plan_put{name = layer_info_2.belt.normal, position = Position.from{input_item_position.x - 2, j}, direction = south}
        else
            plan_put{name = layer_info_1.belt.normal, position = Position.from{input_item_position.x - 1, j}, direction = south}
            plan_put{name = layer_info_2.belt.normal, position = Position.from{input_item_position.x - 2, j}, direction = south}
        end
    end

    if placing == "first" then
        local new_recipes = common.get_recipes(items[1] or error("IItem 1 is required"))

        if #new_recipes == 0 then
            plan_put{name = layer_info_1.belt.underground, position = Position.from{input_item_position.x - 1, -crafting_entity_size - 7}, type = "input", direction = south}
            plan_put{name = layer_info_1.belt.underground, position = Position.from{input_item_position.x - 1, -crafting_entity_size - 2}, type = "output", direction = south}
            plan_put{name = layer_info_1.belt.normal, position = Position.from{input_item_position.x - 1, -crafting_entity_size - 1}, direction = south}
        else
            table.insert(planned_layout.item_input_positions, Position.from{input_item_position.x - 1, -crafting_entity_size})
        end

        new_recipes = common.get_recipes(items[2] or error("Item 2 is required"))

        if #new_recipes == 0 then
            plan_put{name = layer_info_2.belt.underground, position = Position.from{input_item_position.x - 2, -crafting_entity_size - 7}, type = "input", direction = south}
            plan_put{name = layer_info_2.belt.underground, position = Position.from{input_item_position.x - 2, -crafting_entity_size - 2}, type = "output", direction = south}
            plan_put{name = layer_info_2.belt.normal, position = Position.from{input_item_position.x - 2, -crafting_entity_size - 1}, direction = south}
        else
            table.insert(planned_layout.item_input_positions, Position.from{input_item_position.x - 2, -crafting_entity_size})
        end
    end
end

---@param plan_put function(args: GhostEntityArgs)
---@param skeleton BlueprintSkeleton
---@param crafting_entity_size integer
---@param input_filters string[] | nil
---@param item_positions Position[]
---@param placing "first" | "middle" | "last"
---@param parity "even" | "odd"
---@param planned_layout Layout
---@param items string[]
---@param num_item_rows integer
local function _place_multiple_item_rows(
        plan_put,
        skeleton,
        crafting_entity_size,
        item_positions,
        input_filters,
        placing,
        parity,
        planned_layout,
        items,
        num_item_rows
)
    if #item_positions < num_item_rows then
        error("Not enough item positions for the number of items")
    end

    for i = 1, num_item_rows do
        local layer_info = skeleton.input_layers[i]
        if not layer_info then
            error("Input layer info not found for item row " .. i)
        end

        local input_index = parity == "even" and i or #item_positions - i + 1
        local input_item_position = item_positions[input_index]
        if not input_item_position then
            error("Input item position not found for item row " .. i)
        end

        plan_put{name = layer_info.inserter, position = input_item_position, filters = input_filters, direction = west}
        local y_offset = input_item_position.y == crafting_entity_size and 1 or 0
        local base_position = input_item_position + {-3 * i, y_offset - 1}

        for j = -crafting_entity_size - 1, crafting_entity_size do
            if j ~= base_position.y then
                plan_put{name = layer_info.belt.normal, position = {base_position.x, j}, direction = south}
            end
        end

        plan_put{name = layer_info.belt.splitter, position = base_position + {1, 0}, output_priority = "left", direction = south}
        plan_put{name = layer_info.belt.normal, position = base_position + {1, 1}, direction = east}

        local covering_multiple = base_position.y + 1 == -crafting_entity_size or base_position.y == crafting_entity_size

        for j = base_position.x + 2, input_item_position.x - 2, 6 do
            plan_put{name = layer_info.belt.underground, position = {j, base_position.y + 1}, type = "input", direction = east}

            local underground_exit_x_position = math.min(j + 6, input_item_position.x - 2)
            if not covering_multiple and underground_exit_x_position == input_item_position.x - 2 then
                underground_exit_x_position = underground_exit_x_position + 1
            end

            plan_put{name = layer_info.belt.underground, position = {underground_exit_x_position, base_position.y + 1}, type = "output", direction = east}
        end

        if covering_multiple then
            plan_put{name = layer_info.belt.normal, position = {input_item_position.x - 1, base_position.y + 1}, direction = north}
        end

        for j = 1, y_offset do
            if j == y_offset then
                plan_put{name = layer_info.belt.underground, position = {input_item_position.x - 1, base_position.y + 1 - j}, type = "input", direction = north}
            else
                plan_put{name = layer_info.belt.normal, position = {input_item_position.x - 1, base_position.y + 1 - j}, direction = north}
            end
        end

        if placing == "first" then
            local item = items[i]
            if not item then
                error("Item not found for item row " .. i)
            end

            local new_recipes = common.get_recipes(item)

            if #new_recipes == 0 then
                plan_put{name = layer_info.belt.underground, position = {base_position.x, -crafting_entity_size - 7}, type = "input", direction = south}
                plan_put{name = layer_info.belt.underground, position = {base_position.x, -crafting_entity_size - 2}, type = "output", direction = south}
                plan_put{name = layer_info.belt.normal, position = {base_position.x, -crafting_entity_size - 1}, direction = south}
            else
                table.insert(planned_layout.item_input_positions, Position.from{base_position.x, -crafting_entity_size - 1})
            end
        end
    end
end

---@param plan_put function(args: GhostEntityArgs)
---@param skeleton BlueprintSkeleton
---@param crafting_entity LuaEntityPrototype
---@param crafting_entity_size integer
---@param item_positions Position[]
---@param placing "first" | "middle" | "last"
---@param parity "even" | "odd"
---@param planned_layout Layout
---@param items string[]
local function _place_item_rows(
        plan_put,
        skeleton,
        crafting_entity,
        crafting_entity_size,
        item_positions,
        placing,
        parity,
        planned_layout,
        items
)
    if #items <= 0 or #item_positions <= 0 then
        return
    end

    local input_index = parity == "even" and 1 or #item_positions
    local input_item_position = item_positions[input_index]
    if not input_item_position then
        error("Input item position not found for item row " .. input_index)
    end

    local input_filters = _get_input_filters(crafting_entity, items)
    local num_item_rows = math.floor(#items / 2)

    if num_item_rows == 1 and #skeleton.input_layers == 1 then
        _place_single_item_row(
            plan_put,
            skeleton.input_layers[1],
            crafting_entity_size,
            input_item_position,
            input_filters,
            placing,
            planned_layout,
            items
        )
    elseif num_item_rows == 2 and #skeleton.input_layers == 2 then
        _place_double_item_rows(
            plan_put,
            skeleton.input_layers[1],
            skeleton.input_layers[2],
            crafting_entity_size,
            input_filters,
            item_positions,
            input_index,
            input_item_position,
            placing,
            planned_layout,
            items
        )
    else
        _place_multiple_item_rows(
            plan_put,
            skeleton,
            crafting_entity_size,
            item_positions,
            input_filters,
            placing,
            parity,
            planned_layout,
            items,
            num_item_rows
        )
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
    for x = -1, -math.floor(electric_pole.get_supply_area_distance() + 1), -1 do
        for y = crafting_entity_size, -crafting_entity_size, -1 do
            local candidate_position = Position.from{x, y} - {crafting_entity_size, 0}

            if not planned_layout.positions[tostring(candidate_position + position)] then
                plan_put{name = "medium-electric-pole", position = candidate_position}
                return
            end
        end
    end
end

---@param args PlanPutArgs
function input.create_layout(args)
    common.setup_args(args, {components = args.recipe.ingredients, flow_direction = "input"})

    _place_fluid_rows(
        args.plan_put,
        args.num_item_rows,
        args.crafting_entity_size,
        args.fluid_positions,
        args.placing,
        args.planned_layout,
        args.fluids
    )
    
    _place_item_rows(
        args.plan_put,
        args.skeleton,
        args.crafting_entity,
        args.crafting_entity_size,
        args.item_positions,
        args.placing,
        args.parity,
        args.planned_layout,
        args.items
    )

    _place_electric_poles(
        args.plan_put,
        args.position,
        args.electric_pole,
        args.crafting_entity_size,
        args.planned_layout
    )
end

return input
