local blueprint = {}

local north = defines.direction.north
local east = defines.direction.east
local south = defines.direction.south
local west = defines.direction.west

local function _add_positions(p_1, p_2)
    if not p_1 and not p_2 then
        return nil
    end

    if not p_1 then
        return p_2
    end

    if not p_2 then
        return p_1
    end

    x_1 = p_1.x and p_1.x or p_1[1]
    x_2 = p_2.x and p_2.x or p_2[1]
    y_1 = p_1.y and p_1.y or p_1[2]
    y_2 = p_2.y and p_2.y or p_2[2]

    return {x=x_1 + x_2, y=y_1 + y_2}
end

local function _flip_entities(entities)
    if not entities or not #entities or #entities == 0 then
        return
    end

    local top = entities[1].selection_box.left_top.y
    local bottom = entities[1].selection_box.right_bottom.y

    for _, entity in ipairs(entities) do
        top = math.min(top, entity.selection_box.left_top.y)
        bottom = math.max(bottom, entity.selection_box.right_bottom.y)
    end

    local entities = game.surfaces[1].find_entities(area)

    for _, entity in ipairs(entities) do
        local new_y_position = bottom + top - entity.position.y
        entity.teleport({x=entity.position.x, y=new_y_position})
        entity.mirroring = not entity.mirroring

        if entity.direction == north or entity.direction == south then
            entity.rotate()
            entity.rotate()
        end

    end
end

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
    local m_direction = args.direction or north
    local m_filters = nil

    if args.filters then
        m_filters = {}

        for i, filter in ipairs(args.filters) do
            table.insert(m_filters, {name=filter, index=i})
        end
    end

    local m_mirror = false

    if args.mirror == "horizontal" then
        m_mirror = true

        if m_direction == east or m_direction == west then
            m_direction = (m_direction + 8) % 16
        end
    elseif args.mirror == "vertical" then
        m_mirror = true

        if m_direction == north or m_direction == south then
            m_direction = (m_direction + 8) % 16
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
        output_priority=args.output_priority,
        mirror=m_mirror
    }

    if args.modules then
        local m_modules = {unpack(args.modules, 1, entity.ghost_prototype.module_inventory_size)}
        entity.insert_plan = _to_inventory_positions(m_modules, defines.inventory.crafter_modules)
    end

    return entity
end

local function _create_layout_input(args)
    local function put(i_args)
        i_args.position = _add_positions(i_args.position, args.position)
        local new_entity = _create_ghost_entity(i_args)
        table.insert(args.created_items, new_entity)
        return new_entity
    end

    local crafting_entity_size = math.floor(_get_bounding_box_length(args.crafting_entity.bounding_box) / 2)

    local input_fluid_positions = {}
    local fluidbox = args.crafting_entity.fluidbox

    for i = 1, #fluidbox do
        for _, pipe in ipairs(fluidbox.get_pipe_connections(i)) do
            if pipe.flow_direction == "input" then
                local abs_fluid_position = {x=pipe.target_position.x - 0.5, y=pipe.target_position.y - 0.5}
                local fluid_position = _add_positions(abs_fluid_position, {x=-1 * args.position.x, y=-1 * args.position.y})
                table.insert(input_fluid_positions, fluid_position)
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

    for _, ingredient in ipairs(args.recipe.ingredients) do
        local type = ingredient.type

        if not ingredients[type] then
            ingredients[type] = {}
        end

        table.insert(ingredients[type], ingredient.name)
    end

    local num_item_rows = ingredients["item"] and math.ceil(#ingredients["item"] / 2) or 0

    if ingredients["fluid"] then
        local fluid_entities = {}

        local function put_fluid(i_args)
            table.insert(fluid_entities, put(i_args))
        end

        local fluid_row_offset = num_item_rows == 0 and 0
                or num_item_rows <= 2 and num_item_rows + 2
                or num_item_rows * 3 + 2

        if #ingredients["fluid"] == 1 then
            local x_position = -1 * (crafting_entity_size + 1 + fluid_row_offset)

            for i = -crafting_entity_size, crafting_entity_size do
               put_fluid{name="pipe", position={x_position, i}}
            end
        else
            for i, m_position in ipairs(input_fluid_positions) do
                local x_position = m_position.x - fluid_row_offset

                for j = 0, i - 1 do
                    x_position = m_position.x - j - fluid_row_offset
                    put_fluid{name="pipe", position={x_position, m_position.y}}
                end

                if m_position.y - 1 >= -crafting_entity_size then
                    if m_position.y - 2 >= -crafting_entity_size then
                        put_fluid{name="pipe-to-ground", position={x_position, m_position.y - 1}, direction=south}
                    else
                        put_fluid{name="pipe", position={x_position, m_position.y - 1}}
                    end
                end

                if m_position.y + 1 <= crafting_entity_size then
                    if m_position.y + 2 <= crafting_entity_size then
                        put_fluid{name="pipe-to-ground", position={x_position, m_position.y + 1}, direction=north}
                    else
                        put_fluid{name="pipe", position={x_position, m_position.y + 1}}
                    end
                end
            end
        end

        if fluid_row_offset > 0 then
            for _, m_position in ipairs(input_fluid_positions) do
                put_fluid{name="pipe-to-ground", position=m_position, direction=east}

                local x_position = m_position.x - fluid_row_offset + 1
                put_fluid{name="pipe-to-ground", position={x_position, m_position.y}, direction=west}
            end
        end
    end

    if num_item_rows > 0 then
        local input_filters = nil

        if args.crafting_entity.ghost_prototype.type ~= "assembling-machine" then
            input_filters = {}

            for _, item_name in ipairs(ingredients["item"]) do
                table.insert(input_filters, item_name)
            end
        end

        local input_index = args.parity == "even" and 1 or #input_item_positions
        local input_item_position = input_item_positions[input_index]

        if num_item_rows == 1 then
            put{name="inserter", position=input_item_position, filters=input_filters, direction=west}
            local x_position = -1 * (crafting_entity_size + 2)

            for i = -crafting_entity_size, crafting_entity_size do
                put{name="express-transport-belt", position={x_position, i}, direction=south}
            end
        elseif num_item_rows == 2 then
            put{name="inserter", position=input_item_positions[#input_item_positions - (input_index - 1)], filters=input_filters, direction=west}
            put{name="inserter", position=input_item_position, filters=input_filters, direction=west}

            for j = -crafting_entity_size, crafting_entity_size do
                if j == input_item_position.y - 1 then
                    put{name="express-underground-belt", position={input_item_position.x - 1, j}, type="input", direction=south}
                    put{name="express-transport-belt", position={input_item_position.x - 2, j}, direction=south}
                elseif j == input_item_position.y then
                    put{name="express-splitter", position={input_item_position.x - 1, j}, output_priority="left", direction=south}
                elseif j == input_item_position.y + 1 then
                    put{name="express-underground-belt", position={input_item_position.x - 1, j}, type="output", direction=south}
                    put{name="express-transport-belt", position={input_item_position.x - 2, j}, direction=south}
                else
                    put{name="express-transport-belt", position={input_item_position.x - 1, j}, direction=south}
                    put{name="express-transport-belt", position={input_item_position.x - 2, j}, direction=south}
                end
            end
        else
            for i = 1, num_item_rows do
                input_index = args.parity == "even" and i or #input_item_positions - (i - 1)
                input_item_position = input_item_positions[input_index]

                put{name="inserter", position=input_item_position, filters=input_filters, direction=west}
                local x_position = input_item_position.x - 3 * i
                local y_offset = input_item_position.y == crafting_entity_size and 1 or 0
                local y_position = input_item_position.y + y_offset - 1

                for j = -crafting_entity_size, crafting_entity_size do
                    if j ~= y_position then
                        put{name="express-transport-belt", position={x_position, j}, direction=south}
                    end
                end

                put{name="express-splitter", position={x_position + 1, y_position}, output_priority="left", direction=south}
                put{name="express-transport-belt", position={x_position + 1, y_position + 1}, direction=east}

                for j = x_position + 2, input_item_position.x - 2, 6 do
                    put{name="express-underground-belt", position={j, y_position + 1}, type="input", direction=east}
                    local underground_exit_x_position = math.min(j + 6, input_item_position.x - 2)
                    put{name="express-underground-belt", position={underground_exit_x_position, y_position + 1}, type="output", direction=east}
                end

                local underground_exit_direction = (y_position + 1 == -crafting_entity_size or y_position == crafting_entity_size) and north or east
                put{name="express-transport-belt", position={input_item_position.x - 1, y_position + 1}, direction=underground_exit_direction}

                for j = 1, y_offset do
                    if j == y_offset then
                        put{name="express-underground-belt", position={input_item_position.x - 1, y_position + 1 - j}, type="input", direction=north}
                    else
                        put{name="express-transport-belt", position={input_item_position.x - 1, y_position + 1 - j}, direction=north}
                    end
                end
            end
        end
    end
end

local function _create_layout_output(args)
    local function put(i_args)
        i_args.position = _add_positions(i_args.position, args.position)
        local new_entity = _create_ghost_entity(i_args)
        table.insert(args.created_items, new_entity)
        return new_entity
    end

    local crafting_entity_size = math.floor(_get_bounding_box_length(args.crafting_entity.bounding_box) / 2)
    
    local output_fluid_positions = {}
    local fluidbox = args.crafting_entity.fluidbox

    for i = 1, #fluidbox do
        for _, pipe in ipairs(fluidbox.get_pipe_connections(i)) do
            if pipe.flow_direction == "output" then
                local abs_fluid_position = {x=pipe.target_position.x - 0.5, y=pipe.target_position.y - 0.5}
                local fluid_position = _add_positions(abs_fluid_position, {x=-1 * args.position.x, y=-1 * args.position.y})
                table.insert(output_fluid_positions, fluid_position)
            end
        end
    end

    local output_item_positions = {}

    for i = -crafting_entity_size, crafting_entity_size do
        local output_position = {x=crafting_entity_size + 1, y=i}
        local already_fluid_position = false

        for _, fluid_position in ipairs(output_fluid_positions) do
            if fluid_position.x == output_position.x and fluid_position.y == output_position.y then
                already_fluid_position = true
                break
            end
        end

        if not already_fluid_position then
            table.insert(output_item_positions, output_position)
        end
    end

    local products = {}

    for _, product in ipairs(args.recipe.products) do
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
                put{name="pipe", position={x_position, i}}
            end
        else
            for i, m_position in ipairs(output_fluid_positions) do
                local x_position = m_position.x + fluid_row_offset

                for j = 0, i - 1 do
                    x_position = m_position.x + j + fluid_row_offset
                    put{name="pipe", position={x_position, m_position.y}}
                end

                if m_position.y - 1 >= -crafting_entity_size then
                    if m_position.y - 2 >= -crafting_entity_size then
                        put{name="pipe-to-ground", position={x_position, m_position.y - 1}, direction=south}
                    else
                        put{name="pipe", position={x_position, m_position.y - 1}}
                    end
                end

                if m_position.y + 1 <= crafting_entity_size then
                    if m_position.y + 2 <= crafting_entity_size then
                        put{name="pipe-to-ground", position={x_position, m_position.y + 1}, direction=north}
                    else
                        put{name="pipe", position={x_position, m_position.y + 1}}
                    end
                end
            end
        end

        if fluid_row_offset > 0 then
            for _, m_position in ipairs(output_fluid_positions) do
                put{name="pipe-to-ground", position=m_position, direction=west}

                local x_position = m_position.x + fluid_row_offset - 1
                put{name="pipe-to-ground", position={x_position, m_position.y}, direction=east}
            end
        end
    end

    if num_item_rows > 0 then
        local output_index = args.parity == "even" and 1 or #output_item_positions
        local output_item_position = output_item_positions[output_index]

        put{name="inserter", position=output_item_position, direction=west}

        for i = -crafting_entity_size, crafting_entity_size do
            put{name="express-transport-belt", position={crafting_entity_size + 2, i}, direction=north}
        end
    end
end

local function _create_layout(args)
    local m_mirror = args.parity == "even" and "vertical" or nil

    local crafting_entity = _create_ghost_entity{
        name=args.name, 
        position=args.position, 
        modules=args.modules, 
        recipe=args.recipe.name, 
        direction=args.direction,
        mirror=m_mirror
    }

    table.insert(args.created_items, crafting_entity)
    args.crafting_entity = crafting_entity

    _create_layout_input(args)
    _create_layout_output(args)
end

local function _create_layouts(recipe, num_crafting)
    local created_items = {}

    local crafting_modules = _determine_modules_from_recipe(recipe)
    local crafting_entity_name = recipe.has_category("smelting") and "electric-furnace"
            or recipe.has_category("chemistry") and "chemical-plant"
            or recipe.has_category("centrifuging") and "centrifuge"
            or recipe.has_category("oil-processing") and "oil-refinery"
            or "assembling-machine-3"

    local crafting_entity_size = _get_bounding_box_length(prototypes.entity[crafting_entity_name].selection_box)
    local crafting_direction = crafting_entity_name == "oil-refinery" and east or west

    for i = 1, num_crafting do
        local relative_position = {x=0, y=(i - 1) * crafting_entity_size}
        local parity = i % 2 == 0 and "even" or "odd"
        local placing = i == 1 and "first"
                or i == num_crafting and "last"
                or "middle"

        _create_layout{
            created_items=created_items,
            recipe=recipe,
            name=crafting_entity_name,
            position=relative_position,
            direction=crafting_direction,
            modules=crafting_modules,
            parity=parity,
            placing=placing
        }
    end

    return created_items
end

local function _create_blueprint(player)
    local player_stack = player.cursor_stack
    player_stack.set_stack("blueprint")
    player_stack.create_blueprint{surface=game.surfaces[1], force="player", area={left_top={-100, -100}, right_bottom={100, 100}}}
    player_stack.label = "Blueprint"
end

local function _remove_layout(layout)
    for _, entity in ipairs(layout) do
        entity.destroy()
    end
end

function blueprint.generate_blueprint(player, recipe_args)
    local m_recipe = player.force.recipes[recipe_args.recipe]
    local m_num_crafting = recipe_args.quantity and recipe_args.quantity or 1

    local layout = _create_layouts(m_recipe, m_num_crafting)
    _create_blueprint(player)
    _remove_layout(layout)
end

return blueprint