local memory = require("memory")


local gui = {}

local function _add_header(args)
    local header = args.frame.add{type="flow", direction="horizontal", style="bpgn_header"}
    header.style.size = {args.size[1] - 24, 32}

    header.add{type="label", caption={"bpgn.frame_caption"}, style="bpgn_title"}
    header.add{type="empty-widget", style="bpgn_header_filler"}
    header.add{type="sprite-button", name="bpgn_close_button", style="cancel_close_button", sprite="utility/close"}

    return header
end

local function _add_main_content(args)
    local main_flow = args.frame.add{type="flow", direction="vertical"}
    main_flow.style.size = {args.size[1] - 24, args.size[2] - 32 - 40 - 8 - 24}

    local placeholder_recipe = args.memory_storage.recipe or "iron-plate"
    local recipe_button = main_flow.add{type="choose-elem-button", name="bpgn_recipe_button", elem_type="recipe", recipe=placeholder_recipe, style="slot_button"}
    args.gui_storage.recipe_button = recipe_button

    local placeholder_quantity = args.memory_storage.quantity and tostring(args.memory_storage.quantity) or "1"
    local quantity_text = main_flow.add{type="textfield", name="bpgn_quantity_text", text=placeholder_quantity, numeric=true, allow_decimal=false, allow_negative=false}
    args.gui_storage.quantity_text = quantity_text

    return main_flow
end

local function _add_footer(args)
    local footer = args.frame.add{type="flow", direction="horizontal", style="dialog_buttons_horizontal_flow"}
    footer.style.size = {args.size[1] - 24, 40}

    footer.add{type="empty-widget", style="bpgn_footer_filler"}

    local confirm_flow = footer.add{type="flow", direction="horizontal", style="two_module_spacing_horizontal_flow"}
    confirm_flow.add{type="button", name="bpgn_confirm", caption={"bpgn.button_confirm"}, style="confirm_button"}

    return header
end

local function _init(player_index)
    if not storage.bpgn_gui then
        storage.bpgn_gui = {}
    end

    storage.bpgn_gui[player_index] = {recipe_button=nil, quantity_text=nil}
end

function gui.get_recipe_data(player)
    local player_gui = storage.bpgn_gui[player.index]

    local button_element = player_gui.recipe_button
    local m_recipe = button_element and button_element.elem_value or nil

    local text_element = player_gui.quantity_text
    local m_quantity = text_element and tonumber(text_element.text) or 1

    return {recipe=m_recipe, quantity=m_quantity}
end

function gui.destroy(player)
    local element = player.gui.screen.bpgn_frame

    if element then
        element.destroy()
        player.opened = nil
    end

    _init(player.index)
end

function gui.toggle(player)
    local element = player.gui.screen.bpgn_frame

    if element then
        gui.destroy(player)
    else
        local main_frame = player.gui.screen.add{type="frame", name="bpgn_frame", direction="vertical"}
        local main_frame_size = {800, 600}
        main_frame.style.size = main_frame_size
        main_frame.auto_center = true
        player.opened = main_frame

        local gui_args = {
            frame=main_frame,
            gui_storage=storage.bpgn_gui[player.index],
            memory_storage=memory.retrieve(player.index),
            size=main_frame_size
        }

        _add_header(gui_args)
        _add_main_content(gui_args)
        _add_footer(gui_args)
    end
end

return gui