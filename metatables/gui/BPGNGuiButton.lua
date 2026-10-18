package.path = "../../?.lua"

---@class BPGNGuiElement.add_button_param:LuaGuiElement.add_param.button
---@field type? "button"

---@class BPGNGuiButton:BPGNGuiElement
local BPGNGuiButton = {}

---@param parent BPGNGuiElement
---@param gui_args BPGNGuiElement.add_button_param
---@return BPGNGuiButton
function BPGNGuiButton.add(parent, gui_args)
    gui_args.type = "button"
    return parent:add(gui_args, BPGNGuiButton)
end

return BPGNGuiButton
