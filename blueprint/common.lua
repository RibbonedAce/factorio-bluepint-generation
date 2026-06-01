package.path = "../?.lua"

local util = require("util")
local Position = require("metatables.Position")


local common = {}

local function _vector_in_direction(direction)
    local radians = math.pi * ((direction / -8) + 0.5)
    return Position.from{math.cos(radians), math.sin(radians)}
end

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
                local fluid_connection_offset = (flow_direction == "input" and 1 or -1) * _vector_in_direction(args.crafting_direction)
                local fluid_position = Position.from(pipe.positions[(args.machine_direction / 4) + 1]) + fluid_connection_offset
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
    return math.max(
            math.ceil(math.abs(box.left_top.x - box.right_bottom.x)),
            math.ceil(math.abs(box.left_top.y - box.right_bottom.y))
    )
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
        entity.insert_plan = _to_inventory_positions(args.modules, defines.inventory.crafter_modules)
    end

    return entity
end

function common.plan_put(args)
    local function put(i_args)
        i_args.position = Position.from(i_args.position) + args.position

        local selection_box = prototypes.entity[i_args.name].selection_box
        local box_dims = Position.from{
                math.ceil(math.abs(selection_box.left_top.x - selection_box.right_bottom.x)),
                math.ceil(math.abs(selection_box.left_top.y - selection_box.right_bottom.y))
        }

        if i_args.direction and i_args.direction % 4 ~= 0 then
            box_dims = Position.from{box_dims.y, box_dims.x}
        end

        local planned_box = {
                {x=math.ceil(i_args.position.x - box_dims.x / 2), y=math.ceil(i_args.position.y - box_dims.y / 2)},
                {x=math.floor(i_args.position.x + box_dims.x / 2), y=math.floor(i_args.position.y + box_dims.y / 2)},
        }

        table.insert(args.planned_entities, i_args)

        for x = planned_box[1].x, planned_box[2].x do
            for y = planned_box[1].y, planned_box[2].y do
                args.planned_positions[tostring(Position.from{x, y})] = i_args.name
            end
        end
    end

    return put
end

function common.actual_put(planned_entities)
    local actual_entities = {}

    for _, entity in ipairs(planned_entities) do
        local new_entity = common.create_ghost_entity(entity)
        table.insert(actual_entities, new_entity)
    end

    return actual_entities
end

function common.setup_args(args, meta_args)
    args.plan_put = common.plan_put(args)
    args.crafting_entity_size = common.get_half_length(args.crafting_entity.selection_box)
    args.fluid_positions = common.get_fluid_connection_positions(meta_args.flow_direction, meta_args.components, args)
    args.item_positions = common.get_item_inserter_positions(args.crafting_entity_size, args.fluid_positions, meta_args.flow_direction)

    args.belts = {}
    args.inserters = {}
    for _, skeleton_entry in pairs(args.skeleton[meta_args.flow_direction]) do
        table.insert(args.belts, skeleton_entry.belt)
        table.insert(args.inserters, skeleton_entry.inserter)
    end

    local should_use_electric_pole = args.parity == "odd"
            or prototypes.entity["medium-electric-pole"].get_supply_area_distance() < common.get_length(args.crafting_entity.selection_box)
    args.electric_pole = should_use_electric_pole and prototypes.entity["medium-electric-pole"] or nil

    local ingredient_data = common.get_component_data(meta_args.components)
    util.insert_all(args, ingredient_data)
end

return common