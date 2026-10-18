package.path = "../../?.lua"


---@class BPGNGuiElement.add_choose_elem_button_param:LuaGuiElement.add_param.choose_elem_button
---@field type? "choose-elem-button"

---@class BPGNGuiChooseElemButton:BPGNGuiElement
local BPGNGuiChooseElemButton = {}

---@param parent BPGNGuiElement
---@param gui_args BPGNGuiElement.add_choose_elem_button_param
---@return BPGNGuiChooseElemButton
function BPGNGuiChooseElemButton.add(parent, gui_args)
    gui_args.type = "choose-elem-button"
    return parent:add(gui_args, BPGNGuiChooseElemButton)
end

---@return string
function BPGNGuiChooseElemButton:get_value()
    return self:get_raw().elem_value
end

return BPGNGuiChooseElemButton
