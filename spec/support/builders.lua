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
---@type bpgen.Names
builders.NAMES = {
  machine = "stone-furnace",
  belt = "transport-belt",
  inserter = "inserter",
  pole = "small-electric-pole",
}

-- `{name = "iron-ore", amount = 1}` written as `amount_of(1, "iron-ore")`.
---@param amount number
---@param name string
---@return bpgen.RecipeItem
function builders.amount_of(amount, name)
  return {name = name, amount = amount}
end

--------------------------------------------------------------------------------
-- Blueprint entities. Positions are given as TILES: the top-left tile the entity
-- covers (see scripts/grid.lua), so `furnace(2, 0)` covers tiles x 2 to 3 and
-- y 0 to 1. The entity's centre position, which Factorio wants, is worked out
-- for you. Entity numbers are added by `blueprint_of`. Fractions are allowed to
-- build entities that are NOT lined up with the grid: `inserter(0.75, 0, ...)`.
--------------------------------------------------------------------------------

local MACHINE_SIZE = 2

-- Belts default to running south, like the generated ones; pass a direction to change that.
---@param tile_x number
---@param tile_y number
---@param direction? defines.direction  default south
---@return table  an entity without its number yet (see `blueprint_of`)
function builders.belt(tile_x, tile_y, direction)
  return {name = builders.NAMES.belt, position = grid.position(tile_x, tile_y), direction = direction or defines.direction.south}
end

---@param tile_x number
---@param tile_y number
---@return table  an entity without its number yet (see `blueprint_of`)
function builders.furnace(tile_x, tile_y)
  return {name = builders.NAMES.machine, position = grid.position(tile_x, tile_y, MACHINE_SIZE, MACHINE_SIZE)}
end

---@param tile_x number
---@param tile_y number
---@param direction? defines.direction
---@return table  an entity without its number yet (see `blueprint_of`)
function builders.inserter(tile_x, tile_y, direction)
  return {name = builders.NAMES.inserter, position = grid.position(tile_x, tile_y), direction = direction}
end

-- Poles can be given another prototype name, for tests that need a second kind of pole.
---@param tile_x number
---@param tile_y number
---@param name? string  another pole prototype name
---@return table  an entity without its number yet (see `blueprint_of`)
function builders.pole(tile_x, tile_y, name)
  return {name = name or builders.NAMES.pole, position = grid.position(tile_x, tile_y)}
end

-- Gives the entities their numbers (1, 2, 3, ... in the order passed) and
-- returns them as a list, the way a blueprint holds them.
---@param ... table  entities from the builders above
---@return bpgen.Entity[]
function builders.blueprint_of(...)
  local entities = {...}
  for index, entity in ipairs(entities) do
    entity.entity_number = index
  end
  return entities
end

-- Adds a copper wire from pole `from` to pole `to`. Both must already be numbered
-- (see `blueprint_of`). The wire is stored on `from`, as the layout stores it.
---@param from bpgen.Entity  already numbered
---@param to bpgen.Entity  already numbered
function builders.wire_between(from, to)
  local connector = defines.wire_connector_id.pole_copper
  from.wires = from.wires or {}
  ---@diagnostic disable-next-line: assign-type-mismatch  -- the fake `defines` uses strings, not Factorio's numbers
  from.wires[#from.wires + 1] = {from.entity_number, connector, to.entity_number, connector}
end

--------------------------------------------------------------------------------
-- The validator's catalog (see spec/support/blueprint_validator.lua).
--------------------------------------------------------------------------------

-- Options (all optional):
--   pole_supply_radius   default 2.5
--   pole_wire_reach      default 7.5
--   machine_needs_power  default false
---@param options? {pole_supply_radius?: number, pole_wire_reach?: number, machine_needs_power?: boolean}
---@return table<string, bpgen.CatalogEntry>
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

--------------------------------------------------------------------------------
-- A stand-in for the game's `prototypes` table, for generator tests.
--------------------------------------------------------------------------------

-- Options (all optional):
--   furnace_speed   the stone furnace's crafting speed, default 1
--   belt_speed      the transport belt's speed, default 0.03125
--   recipe_energy   seconds per craft of the plate recipes, default 3.2
-- The result can be changed afterwards, for example `fake.entity["inserter"] = nil`.
---@param options? {furnace_speed?: number, belt_speed?: number, recipe_energy?: number}
---@return table  a stand-in for the game's `prototypes`
function builders.fake_prototypes(options)
  options = options or {}
  local furnace_speed = options.furnace_speed or 1
  local belt_speed = options.belt_speed or 0.03125
  local recipe_energy = options.recipe_energy or 3.2

  local function entity(name, crafting_speed, speed)
    return {
      localised_name = {"entity-name." .. name},
      get_crafting_speed = function() return crafting_speed end,
      belt_speed = speed,
    }
  end
  local function recipe(ore)
    local plate = (ore:gsub("%-ore$", "-plate")) -- "iron-ore" -> "iron-plate"
    return {
      energy = recipe_energy,
      ingredients = {{type = "item", name = ore, amount = 1}},
      products = {{type = "item", name = plate, amount = 1}},
      get_product_amount = function() return 1 end,
    }
  end
  local function item(name)
    return {localised_name = {"item-name." .. name}}
  end

  return {
    entity = {
      ["stone-furnace"] = entity("stone-furnace", furnace_speed, nil),
      ["transport-belt"] = entity("transport-belt", nil, belt_speed),
      ["inserter"] = entity("inserter", nil, nil),
      ["small-electric-pole"] = entity("small-electric-pole", nil, nil),
    },
    recipe = {
      ["iron-plate"] = recipe("iron-ore"),
      ["copper-plate"] = recipe("copper-ore"),
    },
    item = {
      ["iron-plate"] = item("iron-plate"), ["copper-plate"] = item("copper-plate"),
      ["iron-ore"] = item("iron-ore"), ["copper-ore"] = item("copper-ore"),
      ["coal"] = item("coal"),
    },
  }
end

return builders
