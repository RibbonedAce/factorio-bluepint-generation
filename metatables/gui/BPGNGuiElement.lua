package.path = "../../?.lua"


---@class BPGNGuiElement
---@field _raw LuaGuiElement
local BPGNGuiElement = {}

---@param element LuaGuiElement
---@param metatable? table
---@return BPGNGuiElement
function BPGNGuiElement.adapt(element, metatable)
    local bpgn_gui_element = {_raw = element}
    return setmetatable(bpgn_gui_element, metatable or BPGNGuiElement)
end

---@param gui_args LuaGuiElement.add_param
---@param metatable? table
---@return BPGNGuiElement
function BPGNGuiElement:add(gui_args, metatable)
    local new_element = self._raw.add(gui_args)
    return BPGNGuiElement.adapt(new_element, metatable)
end

---@return LuaStyle
function BPGNGuiElement:get_style()
    return self._raw.style
end

function BPGNGuiElement:destroy()
    self._raw.destroy()
end

---@param auto_center boolean
function BPGNGuiElement:set_auto_center(auto_center)
    self._raw.auto_center = auto_center
end

---@return BPGNGuiElement
function BPGNGuiElement:get_parent()
    if not self._raw.parent then
        error("Cannot get parent of screen")
    end

    return BPGNGuiElement.adapt(self._raw.parent)
end

---@return LuaGuiElement
function BPGNGuiElement:get_raw()
    return self._raw
end

return BPGNGuiElement
