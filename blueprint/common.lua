package.path = "../?.lua"

local util = require("util")
local Position = require("metatables.Position")


local common = {}

local function _to_inventory_positions(items_array, inventory_slot)
    local inventory_positions = {}
    local dict = {}

    for i, item_name in ipairs(items_array) do
        if not dict[item_name] then
            dict[item_name] = {}
        end

        table.insert(dict[item_name], i - 1)
    end

    for item_name, stacks in pairs(dict) do
        local m_in_inventory = {}

        for _, m_stack in ipairs(stacks) do
           table.insert(m_in_inventory, {inventory=inventory_slot, stack=m_stack})
        end

        table.insert(inventory_positions, {id={name=item_name}, items={in_inventory=m_in_inventory}})
    end

    return inventory_positions
end

local function _flip_entities(entities)
    if not entities or not #entities or #entities == 0 then
        return
    end

    local top = entities[1].selection_box.left_top.y
    local bottom = entities[1].selection_box.right_bottom.y

    for _, entity in ipairs(entities) do
        top = math.min(top, entity.selection_box.left_top.y)
        bottom = math.max(bottom, entity.selection_box.right_bottom.y)
    end

    local entities = game.surfaces[1].find_entities(area)

    for _, entity in ipairs(entities) do
        local new_y_position = bottom + top - entity.position.y
        entity.teleport({x=entity.position.x, y=new_y_position})
        entity.mirroring = not entity.mirroring

        if entity.direction == north or entity.direction == south then
            entity.rotate()
            entity.rotate()
        end
    end
end

function common.get_fluid_connection_positions(entity, position, direction)
    local fluid_positions = {}
    local fluidbox = entity.fluidbox

    for i = 1, #fluidbox do
        for _, pipe in ipairs(fluidbox.get_pipe_connections(i)) do
            if pipe.flow_direction == direction then
                local abs_fluid_position = Position.from(pipe.target_position) - {0.5, 0.5}
                local fluid_position = abs_fluid_position - position
                table.insert(fluid_positions, fluid_position)
            end
        end
    end

    return fluid_positions
end

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

function common.get_component_data(components)
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
        num_item_rows=num_item_rows,
        num_fluid_rows=num_fluid_rows,
        items=components_by_type["item"],
        fluids=components_by_type["fluid"]
    }
end

function common.get_length(box)
    return math.max(math.abs(box.left_top.x - box.right_bottom.x), math.abs(box.left_top.y - box.right_bottom.y))
end

function common.get_half_length(box)
    return math.floor(common.get_length(box) / 2)
end

function common.create_ghost_entity(args)
    local m_direction = args.direction or north
    local m_filters = nil

    if args.filters then
        m_filters = {}

        for i, filter in ipairs(args.filters) do
            table.insert(m_filters, {name=filter, index=i})
        end
    end

    local m_mirror = false

    if args.mirror == "horizontal" then
        m_mirror = true

        if m_direction == east or m_direction == west then
            m_direction = (m_direction + 8) % 16
        end
    elseif args.mirror == "vertical" then
        m_mirror = true

        if m_direction == north or m_direction == south then
            m_direction = (m_direction + 8) % 16
        end
    end

    local entity = game.surfaces[1].create_entity{
        inner_name=args.name,
        position=args.position,
        direction=m_direction,
        filters=m_filters,
        use_filters=m_filters ~= nil,
        name="entity-ghost",
        force="player",
        recipe=args.recipe,
        type=args.type,
        output_priority=args.output_priority,
        mirror=m_mirror
    }

    if args.modules then
        local m_modules = {unpack(args.modules, 1, entity.ghost_prototype.module_inventory_size)}
        entity.insert_plan = _to_inventory_positions(m_modules, defines.inventory.crafter_modules)
    end

    return entity
end

function common.put(args)
    local function put(i_args)
        i_args.position = Position.from(i_args.position) + args.position
        local new_entity = common.create_ghost_entity(i_args)
        table.insert(args.created_entities, new_entity)
        return new_entity
    end

    return put
end

function common.setup_args(args, meta_args)
    args.put = common.put(args)
    args.crafting_entity_size = common.get_half_length(args.crafting_entity.bounding_box)
    args.fluid_positions = common.get_fluid_connection_positions(args.crafting_entity, args.position, meta_args.flow_direction)
    args.item_positions = common.get_item_inserter_positions(args.crafting_entity_size, args.fluid_positions, meta_args.flow_direction)

    local should_use_electric_pole = args.parity == "odd"
            or prototypes.entity["medium-electric-pole"].get_supply_area_distance() < common.get_length(args.crafting_entity.bounding_box)
    args.electric_pole = should_use_electric_pole and prototypes.entity["medium-electric-pole"] or nil

    local ingredient_data = common.get_component_data(meta_args.components)
    util.insert_all(args, ingredient_data)
end

return common