package.path = "../../?.lua"

---@class BPGNGuiElement.add_textfield_param:LuaGuiElement.add_param.textfield
---@field type? "textfield"

---@class BPGNGuiTextField:BPGNGuiElement
local BPGNGuiTextField = {}

---@param parent BPGNGuiElement
---@param gui_args BPGNGuiElement.add_textfield_param
---@return BPGNGuiTextField
function BPGNGuiTextField.add(parent, gui_args)
    gui_args.type = "textfield"
    return parent:add(gui_args, BPGNGuiTextField)
end

---@return string
function BPGNGuiTextField:get_text()
    return self:get_raw().text
end

return BPGNGuiTextField
