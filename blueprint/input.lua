package.path = "../?.lua"

local common = require("blueprint.common")
local util = require("util")
local Position = require("metatables.Position")


local input = {}

local function _get_fluid_row_offset(item_rows)
    return item_rows == 0 and 0
            or item_rows <= 2 and item_rows + 2
            or item_rows * 3 + 2
end

local function _place_single_fluid_row(args)
    local x_position = -1 * (args.crafting_entity_size + 1 + args.fluid_row_offset)

    for i = -args.crafting_entity_size, args.crafting_entity_size do
        args.put{name="pipe", position={x_position, i}}
    end
end

local function _place_multiple_fluid_rows(args)
    for i, m_position in ipairs(args.fluid_positions) do
        m_position = m_position - {args.fluid_row_offset, 0}

        for j = 0, i - 1 do
            args.put{name="pipe", position=m_position - {j, 0}}
        end

        m_position = m_position - {i - 1, 0}

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

local function _place_pipe_trench(args)
   for _, m_position in ipairs(args.fluid_positions) do
       args.put{name="pipe-to-ground", position=m_position, direction=east}
       args.put{name="pipe-to-ground", position=m_position + {1 - args.fluid_row_offset, 0}, direction=west}
   end
end

local function _place_fluid_rows(args)
    if args.num_fluid_rows <= 0 then
        return
    end

    args.fluid_row_offset = _get_fluid_row_offset(args.num_item_rows)

    if args.num_fluid_rows == 1 then
        _place_single_fluid_row(args)
    else
        _place_multiple_fluid_rows(args)
    end

    if args.fluid_row_offset > 0 then
        _place_pipe_trench(args)
    end
end

local function _get_input_filters(entity, items)
    if entity.ghost_type == "assembling-machine" then
        return nil
    end

    local input_filters = {}

    for _, item_name in ipairs(items) do
        table.insert(input_filters, item_name)
    end

    return input_filters
end

local function _place_single_item_row(args)
    args.put{name="bulk-inserter", position=args.input_item_position, filters=args.input_filters, direction=west}
    local x_position = -1 * (args.crafting_entity_size + 2)

    for i = -args.crafting_entity_size, args.crafting_entity_size do
        args.put{name="express-transport-belt", position={x_position, i}, direction=south}
    end

    if args.electric_pole then
        if #args.item_positions == 1 then
            args.put{name=args.electric_pole.name, position=args.input_item_position - {2, 0}}
        else
            args.put{name=args.electric_pole.name, position=args.item_positions[#args.item_positions - 1]}
        end
    end
end

local function _place_double_item_rows(args)
    args.put{name="bulk-inserter", position=args.item_positions[#args.item_positions - (args.input_index - 1)], filters=args.input_filters, direction=west}
    args.put{name="bulk-inserter", position=args.input_item_position, filters=args.input_filters, direction=west}

    for j = -args.crafting_entity_size, args.crafting_entity_size do
        if j == args.input_item_position.y - 1 then
            args.put{name="express-underground-belt", position={args.input_item_position.x - 1, j}, type="input", direction=south}
            args.put{name="express-transport-belt", position={args.input_item_position.x - 2, j}, direction=south}
        elseif j == args.input_item_position.y then
            args.put{name="express-splitter", position={args.input_item_position.x - 1, j}, output_priority="left", direction=south}
        elseif j == args.input_item_position.y + 1 then
            args.put{name="express-underground-belt", position={args.input_item_position.x - 1, j}, type="output", direction=south}
            args.put{name="express-transport-belt", position={args.input_item_position.x - 2, j}, direction=south}
        else
            args.put{name="express-transport-belt", position={args.input_item_position.x - 1, j}, direction=south}
            args.put{name="express-transport-belt", position={args.input_item_position.x - 2, j}, direction=south}
        end
    end

    if args.electric_pole then
        if #args.item_positions == 2 then
            args.put{name=args.electric_pole.name, position=args.item_positions[2] - {3, 0}}
        else
            args.put{name=args.electric_pole.name, position=args.item_positions[#args.item_positions - 1]}
        end
    end
end

local function _place_multiple_item_rows(args)
    for i = 1, args.num_item_rows do
        args.input_index = args.parity == "even" and i or #args.item_positions - (i - 1)
        args.input_item_position = args.item_positions[args.input_index]

        args.put{name="bulk-inserter", position=args.input_item_position, filters=args.input_filters, direction=west}
        local y_offset = args.input_item_position.y == args.crafting_entity_size and 1 or 0
        local base_position = args.input_item_position + {-3 * i, y_offset - 1}

        for j = -args.crafting_entity_size, args.crafting_entity_size do
            if j ~= base_position.y then
                args.put{name="express-transport-belt", position={base_position.x, j}, direction=south}
            end
        end

        args.put{name="express-splitter", position=base_position + {1, 0}, output_priority="left", direction=south}
        args.put{name="express-transport-belt", position=base_position + {1, 1}, direction=east}

        local covering_multiple = base_position.y + 1 == -args.crafting_entity_size or base_position.y == args.crafting_entity_size

        for j = base_position.x + 2, args.input_item_position.x - 2, 6 do
            args.put{name="express-underground-belt", position={j, base_position.y + 1}, type="input", direction=east}

            local underground_exit_x_position = math.min(j + 6, args.input_item_position.x - 2)
            if not covering_multiple and underground_exit_x_position == args.input_item_position.x - 2 then
                 underground_exit_x_position = underground_exit_x_position + 1
            end

            args.put{name="express-underground-belt", position={underground_exit_x_position, base_position.y + 1}, type="output", direction=east}
        end

        if covering_multiple then
            args.put{name="express-transport-belt", position={args.input_item_position.x - 1, base_position.y + 1}, direction=north}
        end

        for j = 1, y_offset do
            if j == y_offset then
                args.put{name="express-underground-belt", position={args.input_item_position.x - 1, base_position.y + 1 - j}, type="input", direction=north}
            else
                args.put{name="express-transport-belt", position={args.input_item_position.x - 1, base_position.y + 1 - j}, direction=north}
            end
        end
    end

    if args.electric_pole then
        local electric_pole_position = args.item_positions[2] - {2, 0}
        args.put{name=args.electric_pole.name, position=electric_pole_position}
    end
end

local function _place_item_rows(args)
    if args.num_item_rows <= 0 then
        return
    end

    args.input_index = args.parity == "even" and 1 or #args.item_positions
    args.input_item_position = args.item_positions[args.input_index]
    args.input_filters = _get_input_filters(args.crafting_entity, args.items)

    if args.num_item_rows == 1 then
        _place_single_item_row(args)
    elseif args.num_item_rows == 2 then
        _place_double_item_rows(args)
    else
        _place_multiple_item_rows(args)
    end
end

function input.create_layout(args)
    common.setup_args(args, {components=args.recipe.ingredients, flow_direction="input"})

    _place_fluid_rows(args)
    _place_item_rows(args)
end

return input