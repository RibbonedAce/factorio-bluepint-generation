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
    local m_filters = args.filter and {{name=args.filter, index=1}} or nil

    local entity = game.surfaces[1].create_entity{
        inner_name=args.name,
        position=args.position,
        direction=m_direction,
        filters=m_filters,
        use_filters=m_filters ~= nil,
        name="entity-ghost",
        force="player",
        recipe=args.recipe,
        type=args.type
    }

    if args.modules then
        local m_modules = {unpack(args.modules, 1, entity.ghost_prototype.module_inventory_size)}
        entity.insert_plan = _to_inventory_positions(m_modules, defines.inventory.crafter_modules)
    end

    return entity
end

local function _create_layout_input(created_items, recipe, crafting_machine_size)
    local input_filter = recipe.has_category("smelting") and recipe.ingredients[1].name or nil

    if #recipe.ingredients <= 2 then
        table.insert(created_items, _create_ghost_entity{name="inserter", position={-1 * (crafting_machine_size + 1), -1}, direction=left, filter=input_filter})
        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-1 * (crafting_machine_size + 2), -1}, direction=down})
    elseif #recipe.ingredients <= 4 then
        table.insert(created_items, _create_ghost_entity{name="inserter", position={-1 * (crafting_machine_size + 1), -1}, direction=left, filter=input_filter})
        table.insert(created_items, _create_ghost_entity{name="inserter", position={-1 * (crafting_machine_size + 1), 0}, direction=left, filter=input_filter})
        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-1 * (crafting_machine_size + 3), -1}, direction=down})
        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-1 * (crafting_machine_size + 3), 0}, direction=right})
        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-1 * (crafting_machine_size + 2), 0}, direction=down})
        table.insert(created_items, _create_ghost_entity{name="express-underground-belt", position={-1 * (crafting_machine_size + 2), -1}, type="input", direction=down})
    else
        table.insert(created_items, _create_ghost_entity{name="inserter", position={-1 * (crafting_machine_size + 1), -1}, direction=left, filter=input_filter})
        table.insert(created_items, _create_ghost_entity{name="inserter", position={-1 * (crafting_machine_size + 1), 0}, direction=left, filter=input_filter})
        table.insert(created_items, _create_ghost_entity{name="inserter", position={-1 * (crafting_machine_size + 1), 1}, direction=left, filter=input_filter})
        table.insert(created_items, _create_ghost_entity{name="express-splitter", position={-1 * (crafting_machine_size + 5), -1}, direction=down})
        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-1 * (crafting_machine_size + 6), 0}, direction=down})
        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-1 * (crafting_machine_size + 6), 1}, direction=down})
        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-1 * (crafting_machine_size + 5), 0}, direction=right})
        table.insert(created_items, _create_ghost_entity{name="express-underground-belt", position={-1 * (crafting_machine_size + 4), 0}, type="input", direction=right})
        table.insert(created_items, _create_ghost_entity{name="express-underground-belt", position={-1 * (crafting_machine_size + 2), 0}, type="output", direction=right})
        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-1 * (crafting_machine_size + 3), -1}, direction=down})
        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-1 * (crafting_machine_size + 3), 0}, direction=down})
        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-1 * (crafting_machine_size + 3), 1}, direction=right})
        table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-1 * (crafting_machine_size + 2), 1}, direction=down})
        table.insert(created_items, _create_ghost_entity{name="express-underground-belt", position={-1 * (crafting_machine_size + 2), -1}, type="input", direction=down})
    end
end

local function _create_layout(recipe)
    local created_items = {}

    local crafting_modules = _determine_modules_from_recipe(recipe)
    local crafting_entity = recipe.has_category("smelting") and "electric-furnace"
            or recipe.has_category("chemistry") and "chemical-plant"
            or recipe.has_category("centrifuging") and "centrifuge"
            or recipe.has_category("oil-processing") and "oil-refinery"
            or "assembling-machine-3"

    local crafting_machine = _create_ghost_entity{name=crafting_entity, position={0, 0}, modules=crafting_modules, recipe=recipe.name}
    table.insert(created_items, crafting_machine)

    local crafting_machine_size = math.floor(_get_bounding_box_length(crafting_machine.bounding_box) / 2)
    _create_layout_input(created_items, recipe, crafting_machine_size)

    table.insert(created_items, _create_ghost_entity{name="inserter", position={crafting_machine_size + 1, -1}, direction=left})
    table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={crafting_machine_size + 2, -1}, direction=up})

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