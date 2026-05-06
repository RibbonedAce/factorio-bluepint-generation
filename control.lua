local gui = require("gui")
local blueprint = require("blueprint")


script.on_event(defines.events.on_gui_click, function(event)
    if event.element and event.element.name == "bpgn_confirm" then
        local player = game.players[event.player_index]
        blueprint.generate_blueprint(player)
        gui.toggle_gui(game.players[event.player_index])
    elseif event.element and event.element.name == "bpgn_close_button" then
        gui.toggle_gui(game.players[event.player_index])
    end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "blueprint-generation" then
        gui.toggle_gui(game.players[event.player_index])
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    if event.element and event.element.name == "bpgn_frame" then
        gui.toggle_gui(game.players[event.player_index])
    end
end)

script.on_configuration_changed(function(config_changed_data)
    for _, player in game.players do
        gui.destroy_gui(player)
    end
end)