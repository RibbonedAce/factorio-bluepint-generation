local blueprint = {}

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

local function _create_ghost_entity(args)
    local m_direction = args.direction or 0
    local m_filters = args.filter and {{name=args.filter, index=1}} or nil

    local item = game.surfaces[1].create_entity{
        inner_name=args.name,
        position=args.position,
        direction=m_direction,
        filters=m_filters,
        use_filters=m_filters ~= nil,
        name="entity-ghost",
        force="player"
    }

    if args.modules then
        item.insert_plan = _to_inventory_positions(args.modules, defines.inventory.crafter_modules)
    end

    return item
end

local function _create_layout()
    local created_items = {}

    table.insert(created_items, _create_ghost_entity{name="electric-furnace", position={0, 0}, modules={"productivity-module-3", "productivity-module-3"}})
    table.insert(created_items, _create_ghost_entity{name="inserter", position={-2, -1}, direction=12, filter="iron-ore"})
    table.insert(created_items, _create_ghost_entity{name="inserter", position={2, -1}, direction=12})
    table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={-3, -1}, direction=8})
    table.insert(created_items, _create_ghost_entity{name="express-transport-belt", position={3, -1}, direction=0})

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

function blueprint.generate_blueprint(player)
   local layout = _create_layout()
   _create_blueprint(player)
   _remove_layout(layout)
end

return blueprint