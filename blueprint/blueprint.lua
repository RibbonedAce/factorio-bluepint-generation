package.path = "../?.lua"

local input = require("blueprint.input")
local output = require("blueprint.output")
local util = require("util")
local common = require("blueprint.common")
local Position = require("metatables.Position")
local rates = require("rates")


local blueprint = {}

local function _remove_layout(layout)
    for _, entity in ipairs(layout) do
        entity.destroy()
    end
end

local function _get_blueprint_area(entities)
    local left_top = Position.from(entities[1].position)
    local right_bottom = Position.from(entities[1].position)

    for _, entity in ipairs(entities) do
        left_top.x = math.min(left_top.x, entity.position.x)
        left_top.y = math.min(left_top.y, entity.position.y)
        right_bottom.x = math.max(right_bottom.x, entity.position.x)
        right_bottom.y = math.max(right_bottom.y, entity.position.y)
    end

    return {left_top=left_top, right_bottom=right_bottom}
end

local function _determine_crafting_machine(recipe)
    return recipe.has_category("smelting") and "electric-furnace"
            or recipe.has_category("chemistry") and "chemical-plant"
            or recipe.has_category("centrifuging") and "centrifuge"
            or recipe.has_category("oil-processing") and "oil-refinery"
            or "assembling-machine-3"
end

local function _put_into_player_cursor(player, entities, force)
    local player_stack = player.cursor_stack
    player_stack.set_stack("blueprint")
    player_stack.create_blueprint{surface=game.surfaces[1], force=force, area=_get_blueprint_area(entities)}
    player_stack.label = "Blueprint"

    return player_stack
end

local function _create_blueprint(player, entities, force)
    local player_stack = _put_into_player_cursor(player, entities, force)
    player.add_to_clipboard(player_stack)
    player.activate_paste()
end

local function _move_entities(player, entities, force, relative_position)
    game.print(math.random() .. ": Before move: " .. #entities)
    local player_stack = _put_into_player_cursor(player, entities, force)

    local area = _get_blueprint_area(entities)
    local center = Position.from({(area.right_bottom.x + area.left_top.x) / 2, (area.right_bottom.y + area.left_top.y) / 2})

    local moved_entities = player_stack.build_blueprint{surface=game.surfaces[1], force=force, position=center + relative_position + {5, 5}}
    game.print(math.random() .. ": After move: " .. #moved_entities)
    _remove_layout(entities)

    player.add_to_clipboard(player_stack)

    return moved_entities
end

local function _determine_modules(recipe, crafting_entity_name)
    local base_modules = recipe.group.name == "intermediate-products" and {"productivity-module-3", "productivity-module-3", "productivity-module-3", "productivity-module-3"}
            or {"efficiency-module-3", "efficiency-module-3", "efficiency-module-3", "speed-module-3"}

    return {unpack(base_modules, 1, prototypes.entity[crafting_entity_name].module_inventory_size)}
end

local function _get_ingredient_rates(recipe, product, product_rate)
    local crafting_entity_name = _determine_crafting_machine(recipe)
    local crafting_modules = _determine_modules(recipe, crafting_entity_name)

    return rates.get_input_rates(recipe, product, prototypes.entity[crafting_entity_name], crafting_modules, product_rate)
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

local function _create_layouts(recipe, product, requested_rate, force)
    local created_entities = {}

    local crafting_entity_name = _determine_crafting_machine(recipe)
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
            skeleton=blueprint_skeleton,
            force=force
        }
    end

    return created_entities
end

local function _generate_part_blueprint(player, recipe_args, force, built_entities)
    built_entities = built_entities or {}
    local output_rate = recipe_args.rate or -1

    local recipe = player.force.recipes[recipe_args.recipe]
    local ingredient_rates = _get_ingredient_rates(recipe, recipe_args.product, output_rate)

    for ingredient, i_rate in pairs(ingredient_rates) do
        local new_recipes = prototypes.get_recipe_filtered({
            {filter="has-product-item", elem_filters={{filter="name", name=ingredient}}},
            {filter="has-product-fluid", elem_filters={{filter="name", name=ingredient}}}
        })

        if #new_recipes > 0 then
            local new_recipe = nil
            for _, recipe in pairs(new_recipes) do
                new_recipe = recipe
                break
            end

            local new_recipe_args = {recipe=new_recipe.name, product=ingredient, rate=i_rate}
            game.print(math.random() .. ": Subrecipe: " .. new_recipe_args.recipe)
            _generate_part_blueprint(player, new_recipe_args, force, built_entities)
        end
    end

    local new_entities = _create_layouts(recipe, recipe_args.product, output_rate, force)

    local distance_to_move = 0
    if #built_entities > 0 then
        local current_entities_area = _get_blueprint_area(built_entities)
        local new_entities_area = _get_blueprint_area(new_entities)
        distance_to_move = current_entities_area.right_bottom.x - new_entities_area.left_top.x
    end

    game.print(math.random() .. ": Distance: " .. distance_to_move)
    local moved_entities = _move_entities(player, new_entities, force, {distance_to_move, 0})

    for _, new_entity in ipairs(moved_entities) do
        table.insert(built_entities, new_entity)
    end

    game.print(math.random() .. ": Current entities: " .. #built_entities)
end

function blueprint.generate_blueprint(player, recipe_args)
    local temp_force = game.create_force("bpgn_force")

    local layout = {}
    _generate_part_blueprint(player, recipe_args, temp_force, layout)
    _create_blueprint(player, layout, temp_force)
    _remove_layout(layout)

    game.merge_forces(temp_force, "player")
end

return blueprint