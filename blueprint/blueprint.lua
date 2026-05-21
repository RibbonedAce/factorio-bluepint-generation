package.path = "../?.lua"

local input = require("blueprint.input")
local output = require("blueprint.output")
local util = require("util")
local common = require("blueprint.common")
local Position = require("metatables.Position")
local rates = require("rates")


local blueprint = {}

local function _determine_modules(recipe, crafting_entity_name)
    local base_modules = recipe.group.name == "intermediate-products" and {"productivity-module-3", "productivity-module-3", "productivity-module-3", "productivity-module-3"}
            or {"efficiency-module-3", "efficiency-module-3", "efficiency-module-3", "speed-module-3"}

    return {unpack(base_modules, 1, prototypes.entity[crafting_entity_name].module_inventory_size)}
end

local function _create_layout(args)
    local m_mirror = args.parity == "even" and "vertical" or nil

    local crafting_entity = common.put(args){
        name=args.name,
        position={0, 0},
        modules=args.modules,
        recipe=args.recipe.name,
        direction=args.direction,
        mirror=m_mirror
    }

    args.crafting_entity = crafting_entity

    input.create_layout(args)
    output.create_layout(args)
end

local function _create_layouts(recipe, product, requested_rate)
    local created_entities = {}

    local crafting_entity_name = recipe.has_category("smelting") and "electric-furnace"
            or recipe.has_category("chemistry") and "chemical-plant"
            or recipe.has_category("centrifuging") and "centrifuge"
            or recipe.has_category("oil-processing") and "oil-refinery"
            or "assembling-machine-3"
    local crafting_modules = _determine_modules(recipe, crafting_entity_name)

    local output_rate = rates.get_output_rate(recipe, product, prototypes.entity[crafting_entity_name], crafting_modules)
    local num_crafting = math.ceil(requested_rate / output_rate)
    local blueprint_skeleton = rates.get_skeleton(recipe, crafting_modules, requested_rate / num_crafting)

    local crafting_entity_size = common.get_length(prototypes.entity[crafting_entity_name].selection_box)
    local crafting_direction = crafting_entity_name == "oil-refinery" and east or west

    for i = 1, num_crafting do
        local relative_position = Position.from{0, (i - 1) * crafting_entity_size}
        local parity = i % 2 == 0 and "even" or "odd"
        local placing = i == 1 and "first"
                or i == num_crafting and "last"
                or "middle"

        _create_layout{
            created_entities=created_entities,
            recipe=recipe,
            name=crafting_entity_name,
            position=relative_position,
            direction=crafting_direction,
            modules=crafting_modules,
            parity=parity,
            placing=placing,
            skeleton=blueprint_skeleton
        }
    end

    return created_entities
end

local function _create_blueprint(player)
    local player_stack = player.cursor_stack
    player_stack.set_stack("blueprint")
    player_stack.create_blueprint{surface=game.surfaces[1], force="player", area={left_top={-100, -100}, right_bottom={100, 100}}}
    player_stack.label = "Blueprint"

    player.add_to_clipboard(player_stack)
    player.activate_paste()
end

local function _remove_layout(layout)
    for _, entity in ipairs(layout) do
        entity.destroy()
    end
end

function blueprint.generate_blueprint(player, recipe_args)
    local recipe = player.force.recipes[recipe_args.recipe]
    local output_rate = recipe_args.rate or -1

    local layout = _create_layouts(recipe, recipe_args.product, output_rate)
    _create_blueprint(player)
    _remove_layout(layout)
end

return blueprint