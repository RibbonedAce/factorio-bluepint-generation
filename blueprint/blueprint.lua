package.path = "../?.lua"

local input = require("blueprint.input")
local output = require("blueprint.output")
local bpgn_util = require("bpgn_util")
local common = require("blueprint.common")
local Position = require("metatables.Position")
local Layout = require("metatables.Layout")
local BPGNBoundingBox = require("metatables.BPGNBoundingBox")
local rates = require("rates")


local blueprint = {}

---@param layout BPGNGhostEntity[]
local function _remove_layout(layout)
    for _, entity in ipairs(layout) do
        entity:destroy()
    end
end

---@param positions Position[]
---@return BPGNBoundingBox
local function _get_blueprint_area(positions)
    if not positions or #positions == 0 or not positions[1] then
        return BPGNBoundingBox.adapt({{0, 0}, {0, 0}})
    end

    local left_top = {x = positions[1].x, y = positions[1].y}
    local right_bottom = {x = positions[1].x, y = positions[1].y}

    for _, position in ipairs(positions) do
        left_top.x = math.min(left_top.x, position.x)
        left_top.y = math.min(left_top.y, position.y)
        right_bottom.x = math.max(right_bottom.x, position.x)
        right_bottom.y = math.max(right_bottom.y, position.y)
    end

    return BPGNBoundingBox.adapt{left_top, right_bottom}
end

---@param recipe LuaRecipe
---@return string
local function _determine_crafting_machine(recipe)
    return recipe.has_category("smelting") and "electric-furnace"
            or recipe.has_category("chemistry") and "chemical-plant"
            or recipe.has_category("centrifuging") and "centrifuge"
            or recipe.has_category("oil-processing") and "oil-refinery"
            or "assembling-machine-3"
end

---@param player LuaPlayer
---@param entities BPGNGhostEntity[]
---@return LuaItemStack
local function _put_into_player_cursor(player, entities)
    local player_stack = player.cursor_stack
    if not player_stack then
        error("Cannot invoke blueprint generation as a spectator")
    end

    player_stack.set_stack("blueprint")
    player_stack.label = "Blueprint"

    local area = _get_blueprint_area(bpgn_util.map(entities, function(e) return e.position end))

    local blueprint_mapping = player_stack.create_blueprint{surface = player.surface, force = player.force, area = area:get_raw()}
    ---@type table<string, integer>
    local index_mapping = {}

    for index, entity in pairs(blueprint_mapping) do
        local entity_identifier = entity.name .. ": (" .. entity.position.x .. ", " .. entity.position.y .. ")"
        index_mapping[entity_identifier] = index
    end

    ---@type BlueprintEntity[]
    local new_blueprint_entities = {}
    local current_blueprint_entities = player_stack.get_blueprint_entities()
    if not current_blueprint_entities then
        error("Do not clear the blueprint from the player stack before using it")
    end

    for _, entity in ipairs(entities) do
        local entity_identifier = entity:to_key()
        local entity_num = index_mapping[entity_identifier]
        if entity_num then
            table.insert(new_blueprint_entities, current_blueprint_entities[entity_num])
        end
    end

    player_stack.set_blueprint_entities(new_blueprint_entities)

    return player_stack
end

---@param player LuaPlayer
---@param entities BPGNGhostEntity[]
local function _create_blueprint(player, entities)
    local player_stack = _put_into_player_cursor(player, entities)
    player.add_to_clipboard(player_stack)
    player.activate_paste()
end

---@param layout Layout
---@param connection_args ConnectionArgs
local function _connect_parts(layout, connection_args)
    local con_input = connection_args.input()
    local con_output = connection_args.output and connection_args.output() or connection_args.input()
    local layer = connection_args.layer

    local plan_put = common.plan_put(Position.from{0, 0}, layout)

    if connection_args.type == "fluid" then
        if layout.positions[tostring(con_output)] then
            plan_put{name = "pipe", position = Position.from{con_output.x, con_output.y - 1}}
        else
            plan_put{name = "pipe-to-ground", position = Position.from{con_output.x, con_output.y - 1}, direction = north}
        end

        for y = con_output.y - 2, con_output.y - layer + 1, -1 do
            plan_put{name = "pipe", position = Position.from{con_output.x, y}}
        end

        for x = con_output.x, con_input.x - 2 do
            plan_put{name = "pipe", position = Position.from{x, con_output.y - layer}}
        end

        plan_put{name = "pipe", position = Position.from{con_input.x - 1, con_output.y - layer}}
        for y = con_input.y - 1, con_output.y - layer, -1 do
            plan_put{name = "pipe", position = Position.from{con_input.x, y}}
        end

        if layout.positions[tostring(Position.from{con_input.x, con_output.y})] then
            plan_put{name = "pipe", position = Position.from{con_input.x, con_output.y}}
        end
    else
        for y = con_output.y - 1, con_output.y - layer + 1, -1 do
            plan_put{name = "express-transport-belt", position = Position.from{con_output.x, y}, direction = north}
        end

        for x = con_output.x, con_input.x - 2 do
            plan_put{name = "express-transport-belt", position = Position.from{x, con_output.y - layer}, direction = east}
        end

        if connection_args.side == "right" then
            plan_put{name = "express-transport-belt", position = Position.from{con_input.x - 1, con_output.y - layer}, direction = south}
        else
            plan_put{name = "express-transport-belt", position = Position.from{con_input.x - 1, con_output.y - layer}, direction = east}
            for y = con_input.y - 1, con_output.y - layer, -1 do
                plan_put{name = "express-transport-belt", position = Position.from{con_input.x, y}, direction = south}
            end
        end
    end
end

---@param recipe LuaRecipe
---@param crafting_entity_name string
---@return string[]
local function _determine_modules(recipe, crafting_entity_name)
    local base_modules = recipe.group.name == "intermediate-products" and {"productivity-module-3", "productivity-module-3", "productivity-module-3", "productivity-module-3"}
            or {"efficiency-module-3", "efficiency-module-3", "efficiency-module-3", "speed-module-3"}

    local prototype = prototypes.entity[crafting_entity_name]
    if not prototype.module_inventory_size then
        error("Cannot put modules into an entity with no module slots: " .. crafting_entity_name)
    end
    
    return {table.unpack(base_modules, 1, prototype.module_inventory_size)}
end

---@param recipe LuaRecipe
---@param product string
---@param product_rate double
---@return table<string, double>
local function _get_ingredient_rates(recipe, product, product_rate)
    local crafting_entity_name = _determine_crafting_machine(recipe)
    local crafting_modules = _determine_modules(recipe, crafting_entity_name)

    return rates.get_input_rates(recipe, product, prototypes.entity[crafting_entity_name], crafting_modules, product_rate)
end

---@alias EntityType "crafting-machine" | "electric-pole" | "inserter" | "pipe" | "underground-pipe" | "transport-belt" | "underground-belt" | "splitter"

---@class GhostEntityArgs
---@field name string
---@field entity_type? EntityType
---@field position Position
---@field modules? string[]
---@field recipe? string
---@field direction? defines.direction
---@field filters? string[]
---@field type? "input" | "output"
---@field output_priority? "left" | "right"
---@field mirror? "vertical" | "horizontal"

---@param args PlanPutArgs
local function _create_layout(args)
    ---@type GhostEntityArgs
    local ghostEntityArgs = {
        name = args.name,
        entity_type = "crafting-machine",
        position = Position.from{0, 0},
        modules = args.modules,
        recipe = args.recipe.name,
        direction = args.machine_direction,
        mirror = args.parity == "even" and "vertical" or nil
    }

    common.plan_put(args.position, args.planned_layout)(ghostEntityArgs)

    input.create_layout(args)
    output.create_layout(args)
end

---@class PlanPutArgs
---@field planned_layout Layout
---@field position Position
---@field parity "even" | "odd"
---@field recipe LuaRecipe
---@field placing "first" | "middle" | "last"
---@field modules? string[]
---@field skeleton BlueprintSkeleton
---@field name string
---@field crafting_direction defines.direction
---@field machine_direction defines.direction
---@field crafting_entity LuaEntityPrototype
---@field plan_put fun(args: GhostEntityArgs)
---@field crafting_entity_size integer
---@field electric_pole LuaEntityPrototype
---@field item_positions Position[]
---@field fluid_positions Position[]
---@field num_item_rows integer
---@field num_fluid_rows integer
---@field items string[]
---@field fluids string[]
---@field fluid_row_offset integer

---@param args LayoutArgs
---@return Layout
local function _create_layouts(args)
    local planned_layout = Layout.new()
    planned_layout:exclude_from_box("medium-electric-pole")
    
    local crafting_entity_size = common.get_length(BPGNBoundingBox.adapt(prototypes.entity[args.crafting_entity_name].selection_box))
    local crafting_direction = west
    local machine_direction = args.crafting_entity_name == "oil-refinery" and east or west

    for i = 1, args.num_crafting do
        local relative_position = Position.from{0, (i - 1) * crafting_entity_size}
        local parity = i % 2 == 0 and "even" or "odd"
        local placing = i == 1 and "first"
                or i == args.num_crafting and "last"
                or "middle"

        ---@type PlanPutArgs
        local plan_put_args = {
            planned_layout = planned_layout,
            recipe = args.recipe,
            name = args.crafting_entity_name,
            position = relative_position,
            crafting_direction = crafting_direction,
            machine_direction = machine_direction,
            modules = args.crafting_modules,
            parity = parity,
            placing = placing,
            skeleton = args.blueprint_skeleton,
            crafting_entity = prototypes.entity[args.crafting_entity_name],
            electric_pole = prototypes.entity["medium-electric-pole"]
        }

        _create_layout(plan_put_args)
    end

    return planned_layout
end

---@class LayoutArgs
---@field recipe LuaRecipe
---@field num_crafting integer
---@field crafting_entity_name string
---@field crafting_modules string[]
---@field blueprint_skeleton BlueprintSkeleton

---@class ConnectionArgs
---@field layer integer
---@field side? "left" | "right"
---@field type ItemType
---@field product string
---@field input fun(): Position
---@field output? fun(): Position

---@param player LuaPlayer
---@param recipe_data RecipeData
---@param connection_args? ConnectionArgs
---@param planned_layout Layout
local function _generate_part_blueprint(player, recipe_data, connection_args, planned_layout)
    if not player.force.recipes then
        error("Something went wrong as player has no recipes available")
    end

    local requested_rate = recipe_data.rate or -1
    
    local recipe = player.force.recipes[recipe_data.recipe]
    local ingredient_rates = _get_ingredient_rates(recipe, recipe_data.product, requested_rate)

    local ingredient_layers = 1
    local item_layers = 1
    local fluid_layers = 1

    local crafting_entity_name = _determine_crafting_machine(recipe)
    local crafting_modules = _determine_modules(recipe, crafting_entity_name)

    local output_rate = rates.get_output_rate(recipe, recipe_data.product, prototypes.entity[crafting_entity_name], crafting_modules)
    local num_crafting = math.ceil(requested_rate / output_rate)
    local blueprint_skeleton = rates.get_skeleton(recipe, recipe.products[1], crafting_modules, requested_rate / num_crafting)

    ---@type LayoutArgs
    local layout_args = {
        recipe = recipe,
        crafting_entity_name = crafting_entity_name,
        crafting_modules = crafting_modules,
        num_crafting = num_crafting,
        blueprint_skeleton = blueprint_skeleton
    }

    local new_layout = _create_layouts(layout_args)

    local current_item_inputs = {}
    for i = #new_layout.item_input_positions, 1, -1 do
        local cur_input = new_layout.item_input_positions[i]
        table.insert(current_item_inputs, Position.from{cur_input.x, cur_input.y})
    end

    local current_fluid_inputs = {}
    for i = #new_layout.fluid_input_positions, 1, -1 do
        local cur_input = new_layout.fluid_input_positions[i]
        table.insert(current_fluid_inputs, Position.from{cur_input.x, cur_input.y})
    end

    local current_outputs = {}

    for i = 1, #new_layout.item_output_positions do
        local cur_output = new_layout.item_output_positions[i]
        table.insert(current_outputs, Position.from{cur_output.x, cur_output.y})
    end

    for i = 1, #new_layout.fluid_output_positions do
        local cur_output = new_layout.fluid_output_positions[i]
        table.insert(current_outputs, Position.from{cur_output.x, cur_output.y})
    end

    for i = 1, #blueprint_skeleton.input_layers do
        local input_entry = blueprint_skeleton.input_layers[i]

        local new_layer = ingredient_layers + 1
        local new_item_layer = item_layers
        local new_fluid_layer = fluid_layers

        if input_entry.type == "fluid" and input_entry.fluid then
            local i_rate = ingredient_rates[input_entry.fluid]
            local new_recipes = common.get_recipes(input_entry.fluid)

            if #new_recipes > 0 and new_recipes[1] then
                local new_recipe_data = {recipe = new_recipes[1].name, product = input_entry.fluid, rate = i_rate}
                local new_connection_args = {
                    layer = new_layer,
                    type = "fluid",
                    product = input_entry.fluid,
                    input = function() return current_fluid_inputs[new_fluid_layer] end,
                    output = function() error("Not implemented") end
                }

                _generate_part_blueprint(player, new_recipe_data, new_connection_args, new_layout)

                fluid_layers = fluid_layers + 1
            end
        elseif input_entry.items then
            if input_entry.items[1] then
                local item = input_entry.items[1]
                local i_rate = ingredient_rates[item]
                local new_recipes = common.get_recipes(item)

                if #new_recipes > 0 then
                    local new_recipe_data = {recipe = new_recipes[1].name, product = item, rate = i_rate}
                    local new_connection_args = {
                        layer = new_layer,
                        side = "left",
                        type = "item",
                        product = item,
                        input = function() return current_item_inputs[new_item_layer] end
                    }

                    _generate_part_blueprint(player, new_recipe_data, new_connection_args, new_layout)
                end
            end

            if input_entry.items[2] then
                local item = input_entry.items[2]
                local i_rate = ingredient_rates[item]
                local new_recipes = common.get_recipes(item)

                if #new_recipes > 0 then
                    local new_recipe = new_recipes[1]
                    local new_recipe_data = {recipe = new_recipe.name, product = item, rate = i_rate}
                    
                    local new_connection_args = {
                        layer = new_layer + 1,
                        side = "right",
                        type = "item",
                        product = item,
                        input = function() return current_item_inputs[new_item_layer] end
                    }
                    _generate_part_blueprint(player, new_recipe_data, new_connection_args, new_layout)
                    ingredient_layers = ingredient_layers + 1
                end
            end

            item_layers = item_layers + 1
        end

        ingredient_layers = ingredient_layers + 1
    end

    local distance_to_move = 0.0
    if planned_layout.num_entities > 0 then
        distance_to_move = planned_layout.box:get_left_top().x - new_layout.box:get_right_bottom().x - 1
        if blueprint_skeleton.output_values[1].type == "fluid" then
            distance_to_move = distance_to_move - 1
        end
    end

    new_layout:move(Position.from{distance_to_move, 0})
    planned_layout:add_all(new_layout)

    if connection_args then
        connection_args.output = function() return current_outputs[blueprint_skeleton.output_values[connection_args.product].layer] + {distance_to_move, 0} end
        _connect_parts(planned_layout, connection_args)
    end
end

---@param player LuaPlayer
---@param entities BPGNGhostEntity[]
local function _create_blueprint(player, entities)
    if not entities or #entities == 0 or not entities[1] then
        return
    end

    local left_top = entities[1]:get_position()
    local right_bottom = entities[1]:get_position()

    for _, entity in ipairs(entities) do
        left_top.x = math.min(left_top.x, entity:get_position().x)
        left_top.y = math.min(left_top.y, entity:get_position().y)
        right_bottom.x = math.max(right_bottom.x, entity:get_position().x)
        right_bottom.y = math.max(right_bottom.y, entity:get_position().y)
    end

    local player_stack = player.cursor_stack
    if not player_stack then
        error("Cannot generate blueprint as a spectator")
    end

    player_stack.set_stack("blueprint")
    player_stack.create_blueprint{surface = game.surfaces[1], force = player.force, area = {{left_top.x, left_top.y}, {right_bottom.x, right_bottom.y}}}
    player_stack.label = "Blueprint"

    player.add_to_clipboard(player_stack)
    player.activate_paste()
end

---@param player LuaPlayer
---@param recipe_data RecipeData
function blueprint.generate_blueprint(player, recipe_data)
    local planned_layout = Layout.new()
    planned_layout:exclude_from_box("medium-electric-pole")
    _generate_part_blueprint(player, recipe_data, nil, planned_layout)
    local actual_layout = common.actual_put(planned_layout.entities)
    _create_blueprint(player, actual_layout)
    _remove_layout(actual_layout)
end

return blueprint
