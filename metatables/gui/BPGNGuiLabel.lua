package.path = "../../?.lua"

---@class BPGNGuiElement.add_label_param:LuaGuiElement.add_param.base
---@field type? "label"

---@class BPGNGuiLabel:BPGNGuiElement
local BPGNGuiLabel = {}

---@param parent BPGNGuiElement
---@param gui_args BPGNGuiElement.add_label_param
---@return BPGNGuiLabel
function BPGNGuiLabel.add(parent, gui_args)
    gui_args.type = "label"
    return parent:add(gui_args, BPGNGuiLabel)
end

return BPGNGuiLabel
