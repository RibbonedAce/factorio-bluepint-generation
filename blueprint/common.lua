package.path = "../?.lua"

local bpgn_util = require("bpgn_util")
local direction_util = require("direction_util")
local Position = require("metatables.Position")
local BPGNBoundingBox = require("metatables.BPGNBoundingBox")
local BPGNCraftingMachine = require("blueprint-generation.metatables.entity.BPGNCraftingMachine")
local BPGNElectricPole = require("blueprint-generation.metatables.entity.BPGNElectricPole")
local BPGNTransportBelt = require("blueprint-generation.metatables.entity.BPGNTransportBelt")
local BPGNSplitter = require("blueprint-generation.metatables.entity.BPGNSplitter")
local BPGNUndergroundBelt = require("blueprint-generation.metatables.entity.BPGNUndergroundBelt")
local BPGNPipe = require("blueprint-generation.metatables.entity.BPGNPipe")
local BPGNUndergroundPipe = require("blueprint-generation.metatables.entity.BPGNUndergroundPipe")
local BPGNInserter = require("blueprint-generation.metatables.entity.BPGNInserter")

---@type table<string, EntityType>
local entity_type_map = {}
entity_type_map["pipe"] = "pipe"
entity_type_map["pipe-to-ground"] = "underground-pipe"
entity_type_map["medium-electric-pole"] = "electric-pole"
entity_type_map["transport-belt"] = "transport-belt"
entity_type_map["fast-transport-belt"] = "transport-belt"
entity_type_map["express-transport-belt"] = "transport-belt"
entity_type_map["underground-belt"] = "underground-belt"
entity_type_map["fast-underground-belt"] = "underground-belt"
entity_type_map["express-underground-belt"] = "underground-belt"
entity_type_map["splitter"] = "splitter"
entity_type_map["fast-splitter"] = "splitter"
entity_type_map["express-splitter"] = "splitter"
entity_type_map["inserter"] = "inserter"
entity_type_map["fast-inserter"] = "inserter"
entity_type_map["express-inserter"] = "inserter"
entity_type_map["electric-furnace"] = "crafting-machine"
entity_type_map["chemical-plant"] = "crafting-machine"
entity_type_map["centrifuge"] = "crafting-machine"
entity_type_map["oil-refinery"] = "crafting-machine"
entity_type_map["assembling-machine-3"] = "crafting-machine"

local common = {}

---@param product string
---@return LuaRecipePrototype[]
function common.get_recipes(product)
    local new_recipes = prototypes.get_recipe_filtered({
        {filter = "has-product-item", elem_filters = {{filter = "name", name = product}}},
        {filter = "has-product-fluid", elem_filters = {{filter = "name", name = product}}}
    })

    ---@type LuaRecipePrototype[]
    local actual_recipes = {}

    for _, recipe in pairs(new_recipes) do
        local original_as_nested_ingredient = false

        for _, ingredient in ipairs(recipe.ingredients) do
            local nested_recipes = prototypes.get_recipe_filtered({
                {filter = "has-product-item", elem_filters = {{filter = "name", name = ingredient}}},
                {filter = "has-product-fluid", elem_filters = {{filter = "name", name = ingredient}}}
            })

            for _, nested_recipe in pairs(nested_recipes) do
                for _, nested_ingredient in ipairs(nested_recipe.ingredients) do
                    if nested_ingredient.name == product then
                        original_as_nested_ingredient = true
                        break
                    end
                end

                if original_as_nested_ingredient then
                    break
                end
            end

            if original_as_nested_ingredient then
                break
            end
        end

        if not original_as_nested_ingredient then
            table.insert(actual_recipes, recipe)
        end
    end

    return actual_recipes
end

---@param flow_direction FlowDirection
---@param components (Ingredient | Product)[]
---@param args PlanPutArgs
---@return Position[]
function common.get_fluid_connection_positions(flow_direction, components, args)
    local fluid_positions = {}

    local has_fluid = false
    for _, component in ipairs(components) do
        if component.type == "fluid" then
            has_fluid = true
            break
        end
    end

    if not has_fluid then
        return fluid_positions
    end

    local fluidboxes = args.crafting_entity.fluidbox_prototypes

    for i = 1, #fluidboxes do
        local fluidbox = args.parity == "even" and fluidboxes[#fluidboxes - i + 1] or fluidboxes[i]
        local pipes = fluidbox.pipe_connections

        for j = 1, #pipes do
            local pipe = args.parity == "even " and pipes[#pipes - j + 1] or pipes[j]

            if pipe.flow_direction == flow_direction then
                local fluid_connection_offset = (flow_direction == "input" and 1 or -1) * direction_util.vector(args.crafting_direction)
                local pipe_position = pipe.positions[(args.machine_direction / 4) + 1] or error("Pipe position not found for machine direction: " .. args.machine_direction)
                local fluid_position = Position.from(pipe_position) + fluid_connection_offset
                table.insert(fluid_positions, fluid_position)
            end
        end
    end

    return fluid_positions
end

---@param entity_size integer
---@param fluid_positions Position[]
---@param direction FlowDirection
---@return Position[]
function common.get_item_inserter_positions(entity_size, fluid_positions, direction)
    local item_positions = {}

    local x_multiplier = direction == "output" and 1 or -1

    for i = -entity_size, entity_size do
        local position = Position.from{x_multiplier * (entity_size + 1), i}
        local already_fluid_position = false

        for _, fluid_position in ipairs(fluid_positions) do
            if fluid_position == position then
                already_fluid_position = true
                break
            end
        end

        if not already_fluid_position then
            table.insert(item_positions, position)
        end
    end

    return item_positions
end

---@class ComponentData
---@field num_item_rows integer
---@field num_fluid_rows integer
---@field items string[]
---@field fluids string[]

---@param components (Ingredient | Product)[]
---@return ComponentData
function common.get_component_data(components)
    ---@type table<"item" | "fluid", string[]>
    local components_by_type = {}

    for _, component in ipairs(components) do
        local type = component.type

        if not components_by_type[type] then
            components_by_type[type] = {}
        end

        table.insert(components_by_type[type], component.name)
    end

    local num_item_rows = components_by_type["item"] and math.ceil(#components_by_type["item"] / 2) or 0
    local num_fluid_rows = components_by_type["fluid"] and #components_by_type["fluid"] or 0

    return {
        num_item_rows = num_item_rows,
        num_fluid_rows = num_fluid_rows,
        items = components_by_type["item"],
        fluids = components_by_type["fluid"]
    }
end

---@param box BPGNBoundingBox
---@return integer
function common.get_length(box)
    return math.max(
        math.ceil(math.abs(box:get_left_top().x - box:get_right_bottom().x)),
        math.ceil(math.abs(box:get_left_top().y - box:get_right_bottom().y))
    )
end

---@param box BPGNBoundingBox
---@return integer
function common.get_half_length(box)
    return math.floor(common.get_length(box) / 2)
end

---@param args GhostEntityArgs
---@return BPGNGhostEntity
function common.create_ghost_entity(args)
    local direction = args.direction or north
    local filters = nil

    if args.filters then
        filters = {}

        for i, filter in ipairs(args.filters) do
            table.insert(filters, {name = filter, index = i})
        end
    end

    local mirror = false

    if args.mirror == "horizontal" then
        mirror = true
        direction = direction_util.get_horizontal_flip(direction) 
    elseif args.mirror == "vertical" then
        mirror = true
        direction = direction_util.get_vertical_flip(direction) 
    end

    local prototype = prototypes.entity[args.name]
    local position = args.position:to()

    if args.entity_type == "crafting-machine" then
        return BPGNCraftingMachine.create(
            {
                name = prototype,
                position = position,
                direction = direction,
                recipe = args.recipe
            },
            args.modules
        )
    elseif args.entity_type == "electric-pole" then
        return BPGNElectricPole.create({
            name = prototype,
            position = position
        })
    elseif args.entity_type == "transport-belt" then
        return BPGNTransportBelt.create({
            name = prototype,
            position = position,
            direction = direction
        })
    elseif args.entity_type == "underground-belt-belt" then
        return BPGNUndergroundBelt.create({
            name = prototype,
            position = position,
            direction = direction,
            type = args.type
        })
    elseif args.entity_type == "splitter" then
        return BPGNSplitter.create({
            name = prototype,
            position = position,
            direction = direction,
            output_priority = args.output_priority
        })
    elseif args.entity_type == "pipe" then
        return BPGNPipe.create({
            name = prototype,
            position = position
        })
    elseif args.entity_type == "underground-pipe" then
        return BPGNUndergroundPipe.create({
            name = prototype,
            position = position,
            direction = direction
        })
    elseif args.entity_type == "inserter" then
        return BPGNInserter.create({
            name = prototype,
            position = position,
            direction = direction,
            filters = filters,
            use_filters = filters ~= nil
        })
    end

    error("Unknown entity type " .. args.entity_type)
end

---@param origin_position Position
---@param planned_layout Layout
---@return fun(i_args: GhostEntityArgs)
function common.plan_put(origin_position, planned_layout)
    return function(i_args)
        i_args.position = Position.from(i_args.position) + origin_position
        i_args.entity_type = entity_type_map[i_args.name]
        planned_layout:add(i_args)
    end
end

---@param planned_entities table<GhostEntityArgs, Position[]>
---@return BPGNGhostEntity[]
function common.actual_put(planned_entities)
    local actual_entities = {}

    for entity, _ in pairs(planned_entities) do
        local new_entity = common.create_ghost_entity(entity)
        table.insert(actual_entities, new_entity)
    end

    return actual_entities
end

---@class MetaArgs
---@field flow_direction FlowDirection
---@field components (Ingredient | Product)[]

---@param args PlanPutArgs
---@param meta_args MetaArgs
function common.setup_args(args, meta_args)
    args.plan_put = common.plan_put(args.position, args.planned_layout)
    args.crafting_entity_size = common.get_half_length(BPGNBoundingBox.adapt(args.crafting_entity.selection_box))
    args.fluid_positions = common.get_fluid_connection_positions(meta_args.flow_direction, meta_args.components, args)
    args.item_positions = common.get_item_inserter_positions(args.crafting_entity_size, args.fluid_positions, meta_args.flow_direction)

    local bounding_box_length = common.get_length(BPGNBoundingBox.adapt(args.crafting_entity.selection_box))
    local should_use_electric_pole = args.parity == "odd"
            or prototypes.entity["medium-electric-pole"].get_supply_area_distance() < bounding_box_length
    args.electric_pole = should_use_electric_pole and prototypes.entity["medium-electric-pole"] or nil

    local ingredient_data = common.get_component_data(meta_args.components)
    bpgn_util.dict_insert_all(args, ingredient_data)
end

return common
