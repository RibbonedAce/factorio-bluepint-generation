local function to_inventory_positions(items_array, inventory_slot)
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

local function add_header(frame, size)
    local header = frame.add{type="flow", direction="horizontal", style="bpgn_header"}
    header.style.size = {size[1] - 24, 32}

    header.add{type="label", caption={"bpgn.frame_caption"}, style="bpgn_title"}
    header.add{type="empty-widget", style="bpgn_header_filler"}
    header.add{type="sprite-button", name="bpgn_close_button", style="cancel_close_button", sprite="utility/close"}

    return header
end

local function add_main_content(frame, size)
    local main_flow = frame.add{type="flow", direction="vertical"}
    main_flow.style.size = {size[1] - 24, size[2] - 32 - 40 - 8 - 28}
    main_flow.style.horizontal_align = "left"
    main_flow.style.vertical_align = "top"

    return main_flow
end

local function add_footer(frame, size)
    local footer = frame.add{type="flow", direction="horizontal", style="dialog_buttons_horizontal_flow"}
    footer.style.size = {size[1] - 24, 40}

    footer.add{type="empty-widget", style="bpgn_footer_filler"}

    local confirm_flow = footer.add{type="flow", direction="horizontal", style="two_module_spacing_horizontal_flow"}
    confirm_flow.add{type="button", name="bpgn_confirm", caption={"bpgn.button_confirm"}, style="confirm_button"}

    return header
end

local function toggle_gui(player)
    local element = player.gui.screen.bpgn_frame

    if element then
        element.destroy()
        player.opened = nil
    else
        local main_frame = player.gui.screen.add{type="frame", name="bpgn_frame", direction="vertical"}
        local main_frame_size = {800, 600}
        main_frame.style.size = main_frame_size
        main_frame.auto_center = true
        player.opened = main_frame

        add_header(main_frame, main_frame_size)
        add_main_content(main_frame, main_frame_size)
        add_footer(main_frame, main_frame_size)
    end
end

local function create_ghost_entity(args)
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
        item.insert_plan = to_inventory_positions(args.modules, defines.inventory.crafter_modules)
    end

    return item
end

local function create_layout()
    local created_items = {}

    table.insert(created_items, create_ghost_entity{name="electric-furnace", position={0, 0}, modules={"productivity-module-3", "productivity-module-3"}})
    table.insert(created_items, create_ghost_entity{name="inserter", position={-2, -1}, direction=12, filter="iron-ore"})
    table.insert(created_items, create_ghost_entity{name="inserter", position={2, -1}, direction=12})
    table.insert(created_items, create_ghost_entity{name="express-transport-belt", position={-3, -1}, direction=8})
    table.insert(created_items, create_ghost_entity{name="express-transport-belt", position={3, -1}, direction=0})

    return created_items
end

local function create_blueprint(player)
    local player_stack = player.cursor_stack
    player_stack.set_stack("blueprint")
    player_stack.create_blueprint{surface=game.surfaces[1], force="player", area={left_top={-10, -10}, right_bottom={10, 10}}}
    player_stack.label = "Blueprint"
end

local function remove_layout(layout)
    for _, entity in ipairs(layout) do
        entity.destroy{}
    end
end

script.on_init(function()

end)

script.on_event(defines.events.on_player_created, function(event)

end)

script.on_event(defines.events.on_player_removed, function(event)

end)

script.on_event(defines.events.on_gui_click, function(event)
    if event.element and event.element.name == "bpgn_confirm" then
        local player = game.players[event.player_index]

        local layout = create_layout()
        create_blueprint(player)
        remove_layout(layout)
        toggle_gui(game.players[event.player_index])
    elseif event.element and event.element.name == "bpgn_close_button" then
        toggle_gui(game.players[event.player_index])
    end
end)

script.on_event(defines.events.on_gui_value_changed, function(event)

end)

script.on_event(defines.events.on_gui_text_changed, function(event)

end)

script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "blueprint-generation" then
        toggle_gui(game.players[event.player_index])
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    if event.element and event.element.name == "bpgn_frame" then
        toggle_gui(game.players[event.player_index])
    end
end)

script.on_configuration_changed(function(config_changed_data)

end)