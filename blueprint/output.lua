package.path = "../?.lua"

local common = require("blueprint.common")
local util = require("util")


local output = {}

local function _place_single_fluid_row(args)
   local x_position = args.crafting_entity_size + 1

   for i = -args.crafting_entity_size, args.crafting_entity_size do
       args.put{name="pipe", position={x_position, i}}
   end
end

local function _place_multiple_fluid_rows(args)
   for i, m_position in ipairs(args.output_fluid_positions) do
       local x_position = m_position.x

       for j = 0, i - 1 do
           x_position = m_position.x + j
           args.put{name="pipe", position={x_position, m_position.y}}
       end

       if m_position.y - 1 >= -args.crafting_entity_size then
           if m_position.y - 2 >= -args.crafting_entity_size then
               args.put{name="pipe-to-ground", position={x_position, m_position.y - 1}, direction=south}
           else
               args.put{name="pipe", position={x_position, m_position.y - 1}}
           end
       end

       if m_position.y + 1 <= args.crafting_entity_size then
           if m_position.y + 2 <= args.crafting_entity_size then
               args.put{name="pipe-to-ground", position={x_position, m_position.y + 1}, direction=north}
           else
               args.put{name="pipe", position={x_position, m_position.y + 1}}
           end
       end
   end
end

local function _place_fluid_rows(args)
    if args.num_fluid_rows <= 0 then
        return
    end

    if args.num_fluid_rows == 1 then
        _place_single_fluid_row(args)
    else
        _place_multiple_fluid_rows(args)
    end
end

local function _place_single_item_row(args)
    args.output_index = args.parity == "even" and 1 or #args.output_item_positions
    args.output_item_position = args.output_item_positions[args.output_index]

    args.put{name="inserter", position=args.output_item_position, direction=west}

    for i = -args.crafting_entity_size, args.crafting_entity_size do
        args.put{name="express-transport-belt", position={args.crafting_entity_size + 2, i}, direction=north}
    end

    if args.electric_pole then
        if #args.output_item_positions == 1 then
            args.put{name=args.electric_pole.name, position=common.add_positions(args.output_item_positions, {2, 0})}
        else
            args.put{name=args.electric_pole.name, position=args.output_item_positions[#args.output_item_positions - 1]}
        end
    end
end

local function _place_electric_poles_without_inserters(args)
    if args.electric_pole then
        local electric_pole_length = common.get_length(args.electric_pole.selection_box) / 2

        for x = 1, math.floor(args.electric_pole.get_supply_area_distance()) do
            for y = -args.crafting_entity_size, args.crafting_entity_size do
                local candidate_position = common.add_positions({args.crafting_entity_size + x, y}, args.position, {0.5, 0.5})

                local entities_in_area = game.surfaces[1].find_entities({
                    common.add_positions(candidate_position, {-electric_pole_length, -electric_pole_length}),
                    common.add_positions(candidate_position, {electric_pole_length, electric_pole_length})
                })

                if #entities_in_area == 0 then
                    args.put{name="medium-electric-pole", position=common.add_positions(candidate_position, {-args.position.x, -args.position.y}, {-0.5, -0.5})}
                    return
                end
            end
        end
    end
end

local function _place_item_rows(args)
    if args.num_item_rows > 0 then
        _place_single_item_row(args)
    else
        _place_electric_poles_without_inserters(args)
    end
end

function output.create_layout(args)
    args.put = common.put(args)
    args.crafting_entity_size = common.get_half_length(args.crafting_entity.bounding_box)
    args.output_fluid_positions = common.get_fluid_connection_positions(args.crafting_entity, args.position, "output")
    args.output_item_positions = common.get_item_inserter_positions(args.crafting_entity_size, args.output_fluid_positions, "output")

    local should_use_electric_pole = args.parity == "odd" or prototypes.entity["medium-electric-pole"].get_supply_area_distance() < common.get_length(args.crafting_entity.bounding_box)
    args.electric_pole = should_use_electric_pole and prototypes.entity["medium-electric-pole"] or nil

    local product_data = common.get_component_data(args.recipe.products)
    util.insert_all(args, product_data)

    _place_fluid_rows(args)
    _place_item_rows(args)
end

return output