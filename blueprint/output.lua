package.path = "../?.lua"

local common = require("blueprint.common")
local util = require("util")
local Position = require("metatables.Position")


local output = {}

local function _place_single_fluid_row(args)
   local x_position = args.crafting_entity_size + 1

   for i = -args.crafting_entity_size, args.crafting_entity_size do
       args.put{name="pipe", position={x_position, i}}
   end
end

local function _place_multiple_fluid_rows(args)
    for i, m_position in ipairs(args.fluid_positions) do
        for j = 0, i - 1 do
            args.put{name="pipe", position=m_position + {j, 0}}
        end

        m_position = m_position + {i - 1, 0}

        if m_position.y - 1 >= -args.crafting_entity_size then
            if m_position.y - 2 >= -args.crafting_entity_size then
                args.put{name="pipe-to-ground", position=m_position - {0, 1}, direction=south}
            else
                args.put{name="pipe", position=m_position - {0, 1}}
            end
        end

        if m_position.y + 1 <= args.crafting_entity_size then
            if m_position.y + 2 <= args.crafting_entity_size then
                args.put{name="pipe-to-ground", position=m_position + {0, 1}, direction=north}
            else
                args.put{name="pipe", position=m_position + {0, 1}}
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
    args.output_index = args.parity == "even" and 1 or #args.item_positions
    args.output_item_position = args.item_positions[args.output_index]

    args.put{name="bulk-inserter", position=args.output_item_position, direction=west}

    for i = -args.crafting_entity_size, args.crafting_entity_size do
        args.put{name="express-transport-belt", position={args.crafting_entity_size + 2, i}, direction=north}
    end

    if args.electric_pole then
        if #args.item_positions == 1 then
            args.put{name=args.electric_pole.name, position=args.item_positions[1] + {2, 0}}
        else
            args.put{name=args.electric_pole.name, position=args.item_positions[#args.item_positions - 1]}
        end
    end
end

local function _place_electric_poles_without_inserters(args)
    if args.electric_pole then
        local electric_pole_length = common.get_length(args.electric_pole.selection_box) / 2

        for x = 1, math.floor(args.electric_pole.get_supply_area_distance()) do
            for y = -args.crafting_entity_size, args.crafting_entity_size do
                local candidate_position = Position.from{x, y} + {args.crafting_entity_size, 0} + args.position + {0.5, 0.5}

                local entities_in_area = game.surfaces[1].find_entities({
                    candidate_position - {electric_pole_length, electric_pole_length},
                    candidate_position + {electric_pole_length, electric_pole_length}
                })

                if #entities_in_area == 0 then
                    args.put{name="medium-electric-pole", position=candidate_position - args.position - {0.5, 0.5}}
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
    common.setup_args(args, {components=args.recipe.products, flow_direction="output"})

    _place_fluid_rows(args)
    _place_item_rows(args)
end

return output