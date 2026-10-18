package.path = "../../?.lua"

---@class BPGNGuiElement.add_flow_param:LuaGuiElement.add_param.flow
---@field type? "flow"

---@class BPGNGuiFlow:BPGNGuiElement
local BPGNGuiFlow = {}

---@param parent BPGNGuiElement
---@param gui_args BPGNGuiElement.add_flow_param
---@return BPGNGuiFlow
function BPGNGuiFlow.add(parent, gui_args)
    gui_args.type = "flow"
    return parent:add(gui_args, BPGNGuiFlow)
end

return BPGNGuiFlow
