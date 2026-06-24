local gui = require("gui")
local memory = require("memory")
local blueprint = require("blueprint.blueprint")
    

local function _init(player)
    gui.destroy(player)
    memory.init(player.index)
end

script.on_init(function()
    for _, player in pairs(game.players) do
        _init(player)
    end
end)

script.on_event(defines.events.on_singleplayer_init, function(event)
    _init(game.players[1])
end)

script.on_event(defines.events.on_player_joined_game, function(event)
    _init(game.players[event.player_index])
end)

script.on_event(defines.events.on_gui_click, function(event)
    if event.element and event.element.name == "bpgn_confirm" then
        local player = game.players[event.player_index]
        local recipe_data = gui.get_recipe_data(player)
        blueprint.generate_blueprint(player, recipe_data)
        gui.toggle(player)
    elseif event.element and event.element.name == "bpgn_close_button" then
        gui.toggle(game.players[event.player_index])
    end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name == "blueprint-generation" then
        gui.toggle(game.players[event.player_index])
    end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
    if event.element and event.element.name == "bpgn_recipe_button" then
        memory.save(event.player_index, "recipe", event.element.elem_value)
        gui.update_item(event.player_index, event.element.elem_value)
    elseif event.element and event.element.name == "bpgn_item_button" then
        memory.save(event.player_index, "item", event.element.elem_value)
    end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    if event.element and event.element.name == "bpgn_rate_text" then
        memory.save(event.player_index, "rate", tonumber(event.element.text))
    end
end)

script.on_event(defines.events.on_gui_closed, function(event)
    if event.element and event.element.name == "bpgn_frame" then
        gui.toggle(game.players[event.player_index])
    end
end)

script.on_configuration_changed(function(config_changed_data)
    for _, player in pairs(game.players) do
        _init(player)
    end
end)