local gui = {}

local function _add_header(frame, size)
    local header = frame.add{type="flow", direction="horizontal", style="bpgn_header"}
    header.style.size = {size[1] - 24, 32}

    header.add{type="label", caption={"bpgn.frame_caption"}, style="bpgn_title"}
    header.add{type="empty-widget", style="bpgn_header_filler"}
    header.add{type="sprite-button", name="bpgn_close_button", style="cancel_close_button", sprite="utility/close"}

    return header
end

local function _add_main_content(frame, size)
    local main_flow = frame.add{type="flow", direction="vertical"}
    main_flow.style.size = {size[1] - 24, size[2] - 32 - 40 - 8 - 24}
    main_flow.style.horizontal_align = "left"
    main_flow.style.vertical_align = "top"

    return main_flow
end

local function _add_footer(frame, size)
    local footer = frame.add{type="flow", direction="horizontal", style="dialog_buttons_horizontal_flow"}
    footer.style.size = {size[1] - 24, 40}

    footer.add{type="empty-widget", style="bpgn_footer_filler"}

    local confirm_flow = footer.add{type="flow", direction="horizontal", style="two_module_spacing_horizontal_flow"}
    confirm_flow.add{type="button", name="bpgn_confirm", caption={"bpgn.button_confirm"}, style="confirm_button"}

    return header
end

function gui.destroy_gui(player)
    local element = player.gui.screen.bpgn_frame

    if element then
        element.destroy()
        player.opened = nil
    end
end

function gui.toggle_gui(player)
    local element = player.gui.screen.bpgn_frame

    if element then
        gui.destroy_gui(player)
    else
        local main_frame = player.gui.screen.add{type="frame", name="bpgn_frame", direction="vertical"}
        local main_frame_size = {800, 600}
        main_frame.style.size = main_frame_size
        main_frame.auto_center = true
        player.opened = main_frame

        _add_header(main_frame, main_frame_size)
        _add_main_content(main_frame, main_frame_size)
        _add_footer(main_frame, main_frame_size)
    end
end

return gui