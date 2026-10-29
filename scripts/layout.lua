-- scripts/layout.lua
-- Turns "N machines" into the list of blueprint entities. Pure: it only builds
-- tables (it reads the constant table `defines`, but never the game world).
-- Positions are written as TILES (see scripts/grid.lua): the top-left tile an
-- entity covers, with y growing down the page.
--
-- The layout is one column of furnaces, drawn here as it looks from above
-- (north is up, items flow down). Each furnace is 2 tiles tall:
--
--   x:   0       1      2 3      4       5
--      input  input   furnace  output  output
--      belt  inserter (2x2)  inserter  belt
--
--        v      >      [F F]      >       v      <- top row of furnace 1
--        v      P      [F F]      P       v      <- bottom row of furnace 1 (P = pole)
--        v      >      [F F]      >       v      <- top row of furnace 2
--        v             [F F]              v
--
-- The input belt carries ore on one lane and coal on the other. Inserters move
-- ore and fuel from the belt into the furnace, and plates from the furnace onto
-- the output belt. Poles sit in the free bottom-row tiles, one per two furnaces
-- on each side, and are wired together.

local grid = require("scripts.grid")

local layout = {}

-- The tile column of each part of the layout (the x numbers in the diagram above).
-- The furnace covers its own column and the next one.
local INPUT_BELT_COLUMN = 0
local INPUT_INSERTER_COLUMN = 1
local FURNACE_COLUMN = 2
local OUTPUT_INSERTER_COLUMN = 4
local OUTPUT_BELT_COLUMN = 5

local MACHINE_SIZE = 2       -- a furnace covers 2 x 2 tiles
local MACHINES_PER_POLE = 2  -- a small pole's supply area covers two furnaces' inserters

-- A blueprint under construction. `add` stores an entity and numbers it, because
-- blueprints identify entities by number; `connect` records a copper wire.
local function new_blueprint()
  local blueprint = {entities = {}}

  function blueprint.add(entity)
    blueprint.entities[#blueprint.entities + 1] = entity
    entity.entity_number = #blueprint.entities
    return entity
  end

  -- Each wire is stored once, on the pole it starts from, as
  -- {from number, connector, to number, connector}.
  function blueprint.connect(from, to)
    local connector = defines.wire_connector_id.pole_copper
    from.wires = from.wires or {}
    from.wires[#from.wires + 1] = {from.entity_number, connector, to.entity_number, connector}
  end

  return blueprint
end

-- Both belts run south (down the page), the full height of the column.
local function add_belts(blueprint, machine_count, names)
  for row = 0, machine_count * MACHINE_SIZE - 1 do
    blueprint.add({name = names.belt, position = grid.position(INPUT_BELT_COLUMN, row), direction = defines.direction.south})
    blueprint.add({name = names.belt, position = grid.position(OUTPUT_BELT_COLUMN, row), direction = defines.direction.south})
  end
end

-- The poles for one furnace go in the free tiles below its two inserters.
local function add_poles(blueprint, top, names, poles)
  local row = top + 1
  poles.input[#poles.input + 1] = blueprint.add({name = names.pole, position = grid.position(INPUT_INSERTER_COLUMN, row)})
  poles.output[#poles.output + 1] = blueprint.add({name = names.pole, position = grid.position(OUTPUT_INSERTER_COLUMN, row)})
end

-- One furnace with its two inserters, and its poles if it is one of those that get them.
-- `index` counts furnaces from 0 down the column.
local function add_machine_row(blueprint, index, names, poles)
  local top = index * MACHINE_SIZE -- tile row of the furnace's top edge

  blueprint.add({name = names.machine, position = grid.position(FURNACE_COLUMN, top, MACHINE_SIZE, MACHINE_SIZE)})

  -- An inserter's `direction` is the side it PICKS UP from. Both inserters move
  -- things eastward (belt -> furnace, furnace -> belt), so both pick up from the west.
  blueprint.add({name = names.inserter, position = grid.position(INPUT_INSERTER_COLUMN, top), direction = defines.direction.west})
  blueprint.add({name = names.inserter, position = grid.position(OUTPUT_INSERTER_COLUMN, top), direction = defines.direction.west})

  if index % MACHINES_PER_POLE == 0 then
    add_poles(blueprint, top, names, poles)
  end
end

-- Returns the poles added, as {input = {...}, output = {...}}, top to bottom.
local function add_machines(blueprint, machine_count, names)
  local poles = {input = {}, output = {}}
  for index = 0, machine_count - 1 do
    add_machine_row(blueprint, index, names, poles)
  end
  return poles
end

-- Chain the poles down each side, then join the two sides at the top.
local function wire_poles(blueprint, poles)
  for i = 2, #poles.input do
    blueprint.connect(poles.input[i - 1], poles.input[i])
    blueprint.connect(poles.output[i - 1], poles.output[i])
  end
  blueprint.connect(poles.input[1], poles.output[1])
end

-- names: {machine, belt, inserter, pole} prototype names.
-- Returns a list of blueprint entities (tables with entity_number, name, position, ...).
function layout.build(machine_count, names)
  local blueprint = new_blueprint()
  add_belts(blueprint, machine_count, names)
  local poles = add_machines(blueprint, machine_count, names)
  wire_poles(blueprint, poles)
  return blueprint.entities
end

return layout
