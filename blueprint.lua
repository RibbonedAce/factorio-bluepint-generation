local blueprint = {}

local up = 0
local right = 4
local down = 8
local left = 12

local function _to_inventory_positions(items_array, inventory_slot)
    local inventory_positions = {}
    local dict = {}

    for i, item_name in ipairs(items_array) do
        if not dict[item_name] then
            dict[item_name] = {}
        end

        table.insert(dict[item_name], i - 1)
    end

    for item_name, stacks in pairs(dict) do
        local m_in_inventory = {}

        for _, m_stack in ipairs(stacks) do
           table.insert(m_in_inventory, {inventory=inventory_slot, stack=m_stack})
        end

        table.insert(inventory_positions, {id={name=item_name}, items={in_inventory=m_in_inventory}})
    end

    return inventory_positions
end

local function _get_bounding_box_length(box)
    return math.max(math.abs(box.left_top.x - box.right_bottom.x), math.abs(box.left_top.y - box.right_bottom.y))
end

local function _determine_modules_from_recipe(recipe)
    return recipe.group.name == "intermediate-products" and {"productivity-module-3", "productivity-module-3", "productivity-module-3", "productivity-module-3"}
            or {"efficiency-module-3", "efficiency-module-3", "efficiency-module-3", "speed-module-3"}
end

local function _create_ghost_entity(args)
    local m_direction = args.direction or 0
    local m_filters = nil

    if args.filters then
        m_filters = {}

        for i, filter in ipairs(args.filters) do
            table.insert(m_filters, {name=filter, index=i})
        end
    end

    local entity = game.surfaces[1].create_entity{
        inner_name=args.name,
        position=args.position,
        direction=m_direction,
        filters=m_filters,
        use_filters=m_filters ~= nil,
        name="entity-ghost",
        force="player",
        recipe=args.recipe,
        type=args.type,
        output_priority=args.output_priority
    }

    if args.modules then
        local m_modules = {unpack(args.modules, 1, entity.ghost_prototype.module_inventory_size)}
        entity.insert_plan = _to_inventory_positions(m_modules, defines.inventory.crafter_modules)
    end

    return entity
end

local function _create_layout_input(created_items, recipe, crafting_entity)
    local crafting_entity_size = math.floor(_get_bounding_box_length(crafting_entity.bounding_box) / 2)

    local input_fluid_positions = {}
    local fluidbox = crafting_entity.fluidbox

    for i = 1, #fluidbox do
        for _, pipe in ipairs(fluidbox.get_pipe_connections(i)) do
            if pipe.flow_direction == "input" then
                table.insert(input_fluid_positions, {x=pipe.target_position.x - 0.5, y=pipe.target_position.y - 0.5})
            end
        end
    end

    local input_item_positions = {}

    for i = -crafting_entity_size, crafting_entity_size do
        local input_position = {x=-1 * (crafting_entity_size + 1), y=i}
        local already_fluid_position = false

        for _, fluid_position in ipairs(input_fluid_positions) do
            if fluid_position.x == input_position.x and fluid_position.y == input_position.y then
                already_fluid_position = true
                break
            end
        end

        if not already_fluid_position then
            table.insert(input_item_positions, input_position)
        end
    end

    local ingredients = {}

    for _, ingredient in ipairs(recipe.ingredients) do
        local type = ingredient.type

        if not ingredients[type] then
            ingredients[type] = {}
        end

        table.insert(ingredients[type], ingredient.name)
    end

    local num_item_rows = ingredients["item"] and math.ceil(#ingredients["item"] / 2) or 0

    if ingredients["fluid"] then
        local fluid_row_offset = num_item_rows == 0 and 0
                or num_item_rows == 1 and 3
                or num_item_rows * 3 + 2

        if #ingredients["fluid"] == 1 then
            local x_position = -1 * (crafting_entity_size + 1 + fluid_row_offset)

            for i = -crafting_entity_size, crafting_entity_size do
                table.insert(created_items, _create_ghost_entity{name="pipe", position={x_position, i}})
            end
        else
            for i, m_position in ipairs(input_fluid_positions) do
                local x_position = m_position.x - fluid_row_offset

                for j = 0, i - 1 do
                    x_position = m_position.x - j - fluid_row_offset
                    table.insert(created_items, _create_ghost_entity{name="pipe", position={x_position, m_position.y}})
                end

                if m_position.y - 1 >= -crafting_entity_size then
                    table.insert(created_items, _create_ghost_entity{name="pipe-to-ground", position={x_position, m_position.y - 1}, direction=down})
                end

                if m_position.y + 1 <= crafting_entity_size then
                    table.insert(created_items, _create_ghost_entity{name="pipe-to-ground", position={x_position, m_position.y + 1}, direction=up})
                end
            end
        end

        if fluid_row_offset > 0 then
            for _, m_position in ipairs(input_fluid_positions) do
                table.insert(created_items, _create_ghost_entity{name="pipe-to-ground", position=m_position, direction=right})

                local x_position = m_position.x - fluid_row_offset + 1
                table.insert(created_items, _create_ghost_entity{name="pipe-to-ground", position={x_position, m_position.y}, direction=left})
            end
        end
    end

    if num_item_rows > 0 then
        local input_filters = nil

        if crafting_entity.ghost_prototype.type ~= "assembling-machine" then
            input_filters = {}

            for _, item_name in ipairs(ingredients["item"]) do
                table.insert(input_filters, item_name)
            end
        end

        if num_item_rows == 1 then
            table.insert(created_items, _create_ghost_entity{name="inserter", position=input_item_positions[1], filters=input_filters, direction=left})
            local x_position = -1 * (crafting_entity_size + 2)

            for i = -crafting_entity_size, crafting_entity_size do
                table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={x_position, i}, direction=down})
            end
        else
            for i = 1, num_item_rows do
                table.insert(created_items, _create_ghost_entity{name="inserter", position=input_item_positions[i], filters=input_filters, direction=left})
                local x_position = input_item_positions[i].x - 3 * i
                local y_offset = input_item_positions[i].y == crafting_entity_size and 1 or 0
                local y_position = input_item_positions[i].y + y_offset - 1

                for j = -crafting_entity_size, crafting_entity_size do
                    if j ~= y_position then
                        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={x_position, j}, direction=down})
                    end
                end

                table.insert(created_items, _create_ghost_entity{name="express-splitter", position={x_position + 1, y_position}, output_priority="left", direction=down})
                table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={x_position + 1, y_position + 1}, direction=right})

                for j = x_position + 2, input_item_positions[i].x - 2, 6 do
                    table.insert(created_items, _create_ghost_entity{name="express-underground-belt", position={j, y_position + 1}, type="input", direction=right})
                    local underground_exit_x_position = math.min(j + 6, input_item_positions[i].x - 2)
                    table.insert(created_items, _create_ghost_entity{name="express-underground-belt", position={underground_exit_x_position, y_position + 1}, type="output", direction=right})
                end

                local underground_exit_direction = y_offset == 0 and right or up
                table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={input_item_positions[i].x - 1, y_position + 1}, direction=underground_exit_direction})

                for j = 1, y_offset do
                    if j == y_offset then
                        table.insert(created_items, _create_ghost_entity{name="express-underground-belt", position={input_item_positions[i].x - 1, y_position + 1 - j}, type="input", direction=up})
                    else
                        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={input_item_positions[i].x - 1, y_position + 1 - j}, direction=up})
                    end
                end
            end
        end
    end
end

local function _create_layout_output(created_items, recipe, crafting_entity)
    local crafting_entity_size = math.floor(_get_bounding_box_length(crafting_entity.bounding_box) / 2)
    
    local output_fluid_positions = {}
    local fluidbox = crafting_entity.fluidbox

    for i = 1, #fluidbox do
        for _, pipe in ipairs(fluidbox.get_pipe_connections(i)) do
            if pipe.flow_direction == "output" then
                table.insert(output_fluid_positions, {x=pipe.target_position.x - 0.5, y=pipe.target_position.y - 0.5})
            end
        end
    end

    local output_item_positions = {}

    for i = -crafting_entity_size, crafting_entity_size do
        local input_position = {x=crafting_entity_size + 1, y=i}
        local already_fluid_position = false

        for _, fluid_position in ipairs(output_fluid_positions) do
            if fluid_position.x == input_position.x and fluid_position.y == input_position.y then
                already_fluid_position = true
                break
            end
        end

        if not already_fluid_position then
            table.insert(output_item_positions, input_position)
        end
    end

    local products = {}

    for _, product in ipairs(recipe.products) do
        local type = product.type

        if not products[type] then
            products[type] = {}
        end

        table.insert(products[type], product.name)
    end

    local num_item_rows = products["item"] and math.ceil(#products["item"] / 2) or 0

    if products["fluid"] then
        local fluid_row_offset = num_item_rows == 0 and 0 or num_item_rows + 3

        if #products["fluid"] == 1 then
            local x_position = crafting_entity_size + 1 + fluid_row_offset

            for i = -crafting_entity_size, crafting_entity_size do
                table.insert(created_items, _create_ghost_entity{name="pipe", position={x_position, i}})
            end
        else
            for i, m_position in ipairs(output_fluid_positions) do
                local x_position = m_position.x + fluid_row_offset

                for j = 0, i - 1 do
                    x_position = m_position.x + j + fluid_row_offset
                    table.insert(created_items, _create_ghost_entity{name="pipe", position={x_position, m_position.y}})
                end

                if m_position.y - 1 >= -crafting_entity_size then
                    table.insert(created_items, _create_ghost_entity{name="pipe-to-ground", position={x_position, m_position.y - 1}, direction=down})
                end

                if m_position.y + 1 <= crafting_entity_size then
                    table.insert(created_items, _create_ghost_entity{name="pipe-to-ground", position={x_position, m_position.y + 1}, direction=up})
                end
            end
        end

        if fluid_row_offset > 0 then
            for _, m_position in ipairs(output_fluid_positions) do
                table.insert(created_items, _create_ghost_entity{name="pipe-to-ground", position=m_position, direction=left})

                local x_position = m_position.x + fluid_row_offset - 1
                table.insert(created_items, _create_ghost_entity{name="pipe-to-ground", position={x_position, m_position.y}, direction=right})
            end
        end
    end

    if num_item_rows > 0 then
        table.insert(created_items, _create_ghost_entity{name="inserter", position=output_item_positions[1], direction=left})

        for i = -crafting_entity_size, crafting_entity_size do
            table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={crafting_entity_size + 2, i}, direction=up})
        end
    end
end

local function _create_layout(recipe)
    local created_items = {}

    local crafting_modules = _determine_modules_from_recipe(recipe)
    local crafting_entity_name = recipe.has_category("smelting") and "electric-furnace"
            or recipe.has_category("chemistry") and "chemical-plant"
            or recipe.has_category("centrifuging") and "centrifuge"
            or recipe.has_category("oil-processing") and "oil-refinery"
            or "assembling-machine-3"

    local crafting_direction = crafting_entity_name == "oil-refinery" and right or left
    local crafting_entity = _create_ghost_entity{name=crafting_entity_name, position={0, 0}, modules=crafting_modules, recipe=recipe.name, direction=crafting_direction}

    table.insert(created_items, crafting_entity)
    _create_layout_input(created_items, recipe, crafting_entity)
    _create_layout_output(created_items, recipe, crafting_entity)

    return created_items
end

local function _create_blueprint(player)
    local player_stack = player.cursor_stack
    player_stack.set_stack("blueprint")
    player_stack.create_blueprint{surface=game.surfaces[1], force="player", area={left_top={-10, -10}, right_bottom={10, 10}}}
    player_stack.label = "Blueprint"
end

local function _remove_layout(layout)
    for _, entity in ipairs(layout) do
        entity.destroy{}
    end
end

function blueprint.generate_blueprint(player, recipe_name)
   local layout = _create_layout(player.force.recipes[recipe_name])
   _create_blueprint(player)
   _remove_layout(layout)
end

return blueprint