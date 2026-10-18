package.path = "../../?.lua"


---@class BPGNGuiElement.add_empty_param:LuaGuiElement.add_param.base
---@field type? "empty-widget"

---@class BPGNGuiEmpty:BPGNGuiElement
local BPGNGuiEmpty = {}

---@param parent BPGNGuiElement
---@param gui_args BPGNGuiElement.add_empty_param
---@return BPGNGuiEmpty
function BPGNGuiEmpty.add(parent, gui_args)
    gui_args.type = "empty-widget"
    return parent:add(gui_args, BPGNGuiEmpty)
end

return BPGNGuiEmpty
