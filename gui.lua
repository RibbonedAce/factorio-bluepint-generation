local BPGNGuiElement = require("metatables.gui.BPGNGuiElement")
local BPGNGuiChooseElemButton = require("metatables.gui.BPGNGuiChooseElemButton")
local BPGNGuiFlow = require("metatables.gui.BPGNGuiFlow")
local BPGNGuiLabel = require("metatables.gui.BPGNGuiLabel")
local BPGNGuiEmpty = require("metatables.gui.BPGNGuiEmpty")
local BPGNGuiSpriteButton = require("metatables.gui.BPGNGuiSpriteButton")
local BPGNGuiButton = require("metatables.gui.BPGNGuiButton")
local BPGNGuiTextField = require("metatables.gui.BPGNGuiTextField")
local BPGNGuiFrame = require("metatables.gui.BPGNGuiFrame")

local memory = require("memory")


local gui = {}

---@class GUIMemory
---@field recipe_button? BPGNGuiChooseElemButton
---@field item_button? BPGNGuiChooseElemButton
---@field rate_text? BPGNGuiTextField

---@param player_index integer
---@param gui_memory GUIMemory
local function _init(player_index, gui_memory)
    if not storage.bpgn_gui then
        storage.bpgn_gui = {}
    end

    ---@type GUIMemory
    storage.bpgn_gui[player_index] = gui_memory
end

---@param gui_storage GUIMemory
---@param recipe_button BPGNGuiChooseElemButton
---@param stored_product? string
local function _update_item(gui_storage, recipe_button, stored_product)
    if not recipe_button or not recipe_button:get_parent() then
        error("Trying to update item with no active recipe button") 
    end

    if gui_storage.item_button then
        gui_storage.item_button:destroy()
        gui_storage.item_button = nil
    end

    local products = prototypes.recipe[recipe_button:get_value()].products
    local product_names = {}
    local can_use_stored_item = false
    ---@type ElemType
    local elem_type = "item"

    for _, product in ipairs(products) do
        elem_type = product.type
        table.insert(product_names, product.name)
        if stored_product == product.name then
            can_use_stored_item = true
        end
    end

    gui_storage.item_button = BPGNGuiChooseElemButton.add(recipe_button:get_parent(), {
        name = "bpgn_item_button",
        elem_type = elem_type,
        item = can_use_stored_item and stored_product or product_names[1],
        fluid = can_use_stored_item and stored_product or product_names[1],
        style = "slot_button",
        elem_filters = {{filter = "name", name = product_names}},
        enabled = #product_names > 1,
        visible = #product_names > 1
    })
end

---@param args GuiArgs
---@return BPGNGuiFlow
local function _add_header(args)
    local header = BPGNGuiFlow.add(args.frame, {direction = "horizontal", style = "bpgn_header"})
    local header_style = header:get_style()
    header_style.size = {args.size[1] - 24, 32}

    BPGNGuiLabel.add(header, {caption = {"bpgn.frame_caption"}, style = "bpgn_title"})
    BPGNGuiEmpty.add(header, {style = "bpgn_header_filler"})
    BPGNGuiSpriteButton.add(header, {name = "bpgn_close_button", style = "cancel_close_button", sprite = "utility/close"})

    return header
end

---@param args GuiArgs
---@return BPGNGuiFlow
local function _add_main_content(args)
    local main_flow = BPGNGuiFlow.add(args.frame, {direction = "vertical"})
    local main_flow_style = main_flow:get_style()
    main_flow_style.size = {args.size[1] - 24, args.size[2] - 32 - 40 - 8 - 24}

    local recipe_flow = BPGNGuiFlow.add(main_flow, {direction = "horizontal"})
    local recipe_flow_style = recipe_flow:get_style()
    recipe_flow_style.padding = 2

    local placeholder_recipe = args.memory_storage.recipe or "iron-plate"
    args.gui_storage.recipe_button = BPGNGuiChooseElemButton.add(recipe_flow, {name = "bpgn_recipe_button", elem_type = "recipe", recipe = placeholder_recipe, style = "slot_button"})

    _update_item(args.gui_storage, args.gui_storage.recipe_button, args.memory_storage.product)

    local placeholder_rate = args.memory_storage.rate and tostring(args.memory_storage.rate) or "1"
    args.gui_storage.rate_text = BPGNGuiTextField.add(main_flow, {name = "bpgn_rate_text", text = placeholder_rate, numeric = true, allow_decimal = true, allow_negative = false})

    return main_flow
end

---@param args GuiArgs
---@return BPGNGuiFlow
local function _add_footer(args)
    local footer = BPGNGuiFlow.add(args.frame, {direction = "horizontal", style = "dialog_buttons_horizontal_flow"})
    local footer_style = footer:get_style()
    footer_style.size = {args.size[1] - 24, 40}

    BPGNGuiEmpty.add(footer, {style = "bpgn_footer_filler"})

    local confirm_flow = BPGNGuiFlow.add(footer, {direction = "horizontal", style = "two_module_spacing_horizontal_flow"})
    BPGNGuiButton.add(confirm_flow, {name = "bpgn_confirm", caption = {"bpgn.button_confirm"}, style = "confirm_button"})

    return footer
end

---@param player_index integer
---@param recipe_button BPGNGuiChooseElemButton
function gui.update_item(player_index, recipe_button)
    _update_item(storage.bpgn_gui[player_index], recipe_button, nil)
end

---@class RecipeData
---@field recipe string
---@field product string
---@field rate double

---@param player LuaPlayer
---@return RecipeData
function gui.get_recipe_data(player)
    local player_gui = storage.bpgn_gui[player.index]

    local recipe_element = player_gui.recipe_button
    local recipe = recipe_element and recipe_element:get_value() or nil

    local product_element = player_gui.item_button
    local product = product_element and product_element:get_value() or nil

    local text_element = player_gui.rate_text
    local rate = text_element and tonumber(text_element:get_text()) or 1

    return {
        ---@cast recipe string
        recipe = recipe, 
        ---@cast product string
        product = product, 
        rate = rate
    }
end

---@param player LuaPlayer
function gui.destroy(player)
    local element = player.gui.screen.bpgn_frame

    if element then
        element.destroy()
        player.opened = nil
        _init(player.index, {})
    end
end

---@class GuiArgs
---@field frame BPGNGuiFrame
---@field gui_storage table
---@field memory_storage MainMemory
---@field size [integer, integer]

---@param player LuaPlayer
function gui.toggle(player)
    local element = BPGNGuiFrame.adapt(player.gui.screen.bpgn_frame)

    if element then
        gui.destroy(player)
    else
        local screen = BPGNGuiElement.adapt(player.gui.screen)
        local main_frame = BPGNGuiFrame.add(screen, {name = "bpgn_frame", direction = "vertical"})
        local main_frame_size = {800, 600}
        local main_frame_style = main_frame:get_style()
        main_frame_style.size = main_frame_size
        main_frame:set_auto_center(true)
        player.opened = main_frame:get_raw()

        ---@type GuiArgs
        local gui_args = {
            frame = main_frame,
            gui_storage = storage.bpgn_gui[player.index],
            memory_storage = memory.retrieve(player.index),
            size = main_frame_size
        }

        _add_header(gui_args)
        _add_main_content(gui_args)
        _add_footer(gui_args)
    end
end

return gui
