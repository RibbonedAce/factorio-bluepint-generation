-- spec/support/builders.lua
-- Helpers that build the plain data the tests need, so a test body only has to
-- spell out the values its assertions depend on.
--
-- The rule for using them: a value a test's expectation depends on is passed in
-- by the test itself (`a_catalog{pole_wire_reach = 7}`), never left to a default
-- that the reader cannot see. Defaults are only for things the test does not care about.

local grid = require("scripts.grid")

local builders = {}

-- The prototype names the layout is given. They are labels here, nothing more.
builders.NAMES = {
  machine = "stone-furnace",
  belt = "transport-belt",
  inserter = "inserter",
  pole = "small-electric-pole",
}

--------------------------------------------------------------------------------
-- Blueprint entities. Positions are given as TILES: the top-left tile the entity
-- covers (see scripts/grid.lua), so `furnace(2, 0)` covers tiles x 2 to 3 and
-- y 0 to 1. The entity's centre position, which Factorio wants, is worked out
-- for you. Entity numbers are added by `blueprint_of`. Fractions are allowed to
-- build entities that are NOT lined up with the grid: `inserter(0.75, 0, ...)`.
--------------------------------------------------------------------------------

local MACHINE_SIZE = 2

-- Belts default to running south, like the generated ones; pass a direction to change that.
function builders.belt(tile_x, tile_y, direction)
  return {name = builders.NAMES.belt, position = grid.position(tile_x, tile_y), direction = direction or defines.direction.south}
end

function builders.furnace(tile_x, tile_y)
  return {name = builders.NAMES.machine, position = grid.position(tile_x, tile_y, MACHINE_SIZE, MACHINE_SIZE)}
end

function builders.inserter(tile_x, tile_y, direction)
  return {name = builders.NAMES.inserter, position = grid.position(tile_x, tile_y), direction = direction}
end

-- Poles can be given another prototype name, for tests that need a second kind of pole.
function builders.pole(tile_x, tile_y, name)
  return {name = name or builders.NAMES.pole, position = grid.position(tile_x, tile_y)}
end

-- Gives the entities their numbers (1, 2, 3, ... in the order passed) and
-- returns them as a list, the way a blueprint holds them.
function builders.blueprint_of(...)
  local entities = {...}
  for index, entity in ipairs(entities) do
    entity.entity_number = index
  end
  return entities
end

-- Adds a copper wire from pole `from` to pole `to`. Both must already be numbered
-- (see `blueprint_of`). The wire is stored on `from`, as the layout stores it.
function builders.wire_between(from, to)
  local connector = defines.wire_connector_id.pole_copper
  from.wires = from.wires or {}
  from.wires[#from.wires + 1] = {from.entity_number, connector, to.entity_number, connector}
end

--------------------------------------------------------------------------------
-- The validator's catalog (see spec/support/blueprint_validator.lua).
--------------------------------------------------------------------------------

-- Options (all optional):
--   pole_supply_radius   default 2.5
--   pole_wire_reach      default 7.5
--   machine_needs_power  default false
function builders.a_catalog(options)
  options = options or {}
  local names = builders.NAMES
  return {
    [names.machine] = {kind = "machine", width = 2, height = 2, needs_power = options.machine_needs_power or false},
    [names.belt] = {kind = "belt", width = 1, height = 1},
    [names.inserter] = {kind = "inserter", width = 1, height = 1, needs_power = true},
    [names.pole] = {
      kind = "pole", width = 1, height = 1,
      supply_radius = options.pole_supply_radius or 2.5,
      wire_reach = options.pole_wire_reach or 7.5,
    },
  }
end

return builders
