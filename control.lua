local gui = require("gui")
local blueprint = require("blueprint.blueprint")


script.on_init(function()
    for _, player in pairs(game.players) do
        gui.destroy_gui(player)
    end
end)

script.on_event(defines.events.on_singleplayer_init, function(event)
    gui.destroy_gui(game.players[1])
end)

script.on_event(defines.events.on_player_joined_game, function(event)
    gui.destroy_gui(game.players[event.player_index])
end)

script.on_event(defines.events.on_gui_click, function(event)
    if event.element and event.element.name == "bpgn_confirm" then
        local player = game.players[event.player_index]
        local recipe_data = gui.get_recipe_data(player)
        blueprint.generate_blueprint(player, recipe_data)
        gui.toggle_gui(player)
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
    for _, player in pairs(game.players) do
        gui.destroy_gui(player)
    end
end)