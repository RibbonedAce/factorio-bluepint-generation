package.path = "../../?.lua"

---@class BPGNGuiElement.add_frame_param:LuaGuiElement.add_param.frame
---@field type? "frame"

---@class BPGNGuiFrame:BPGNGuiElement
local BPGNGuiFrame = {}

---@param parent BPGNGuiElement
---@param gui_args BPGNGuiElement.add_frame_param
---@return BPGNGuiFrame
function BPGNGuiFrame.add(parent, gui_args)
    gui_args.type = "frame"
    return parent:add(gui_args, BPGNGuiFrame)
end

return BPGNGuiFrame
