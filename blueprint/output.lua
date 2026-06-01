package.path = "../?.lua"

local common = require("blueprint.common")
local util = require("util")
local Position = require("metatables.Position")


local output = {}

local function _place_single_fluid_row(args)
   local x_position = args.crafting_entity_size + 1

   for i = -args.crafting_entity_size, args.crafting_entity_size do
       args.plan_put{name="pipe", position={x_position, i}}
   end
end

local function _place_multiple_fluid_rows(args)
    for i, m_position in ipairs(args.fluid_positions) do
        for j = 0, i - 1 do
            args.plan_put{name="pipe", position=m_position + {j, 0}}
        end

        m_position = m_position + {i - 1, 0}

        if m_position.y - 1 >= -args.crafting_entity_size then
            if m_position.y - 2 >= -args.crafting_entity_size then
                args.plan_put{name="pipe-to-ground", position=m_position - {0, 1}, direction=south}
            else
                args.plan_put{name="pipe", position=m_position - {0, 1}}
            end
        end

        if m_position.y + 1 <= args.crafting_entity_size then
            if m_position.y + 2 <= args.crafting_entity_size then
                args.plan_put{name="pipe-to-ground", position=m_position + {0, 1}, direction=north}
            else
                args.plan_put{name="pipe", position=m_position + {0, 1}}
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

    args.plan_put{name=args.inserters[1], position=args.output_item_position, direction=west}

    for i = -args.crafting_entity_size, args.crafting_entity_size do
        args.plan_put{name=args.belts[1].normal, position={args.crafting_entity_size + 2, i}, direction=north}
    end
end

local function _place_item_rows(args)
    if args.num_item_rows > 0 then
        _place_single_item_row(args)
    end
end

local function _place_electric_poles(args)
    if not args.electric_pole then
        return
    end

    for x = 1, math.floor(args.electric_pole.get_supply_area_distance() + 1) do
        for y = args.crafting_entity_size, -args.crafting_entity_size, -1 do
            local candidate_position = Position.from{x, y} + {args.crafting_entity_size, 0}

            if not args.planned_positions[tostring(candidate_position + args.position)] then
                args.plan_put{name="medium-electric-pole", position=candidate_position}
                return
            end
        end
    end
end

function output.create_layout(args)
    common.setup_args(args, {components=args.recipe.products, flow_direction="output"})

    _place_fluid_rows(args)
    _place_item_rows(args)
    _place_electric_poles(args)
end

return output