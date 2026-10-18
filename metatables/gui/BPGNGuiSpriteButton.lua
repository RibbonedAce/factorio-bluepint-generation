package.path = "../../?.lua"

---@class BPGNGuiElement.add_sprite_button_param:LuaGuiElement.add_param.sprite_button
---@field type? "sprite-button"

---@class BPGNGuiSpriteButton:BPGNGuiElement
local BPGNGuiSpriteButton = {}

---@param parent BPGNGuiElement
---@param gui_args BPGNGuiElement.add_sprite_button_param
---@return BPGNGuiSpriteButton
function BPGNGuiSpriteButton.add(parent, gui_args)
    gui_args.type = "sprite-button"
    return parent:add(gui_args, BPGNGuiSpriteButton)
end

return BPGNGuiSpriteButton
