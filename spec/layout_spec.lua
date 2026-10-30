-- spec/layout_spec.lua
-- What the furnace-column layout builds. Positions are TILES read off the diagram
-- at the top of scripts/layout.lua (the top-left tile an entity covers, y growing
-- down; see scripts/grid.lua): x = 0 input belt, 1 input inserters, 2 furnace
-- (covering columns 2 and 3), 4 output inserters, 5 output belt. Every furnace is
-- two tiles tall, so furnace number i (from 0) starts at y = 2i.
---@diagnostic disable: undefined-field  -- luassert's `assert` has fields (`assert.are`, `assert.is_nil`, ...) the editor cannot see

local builders = require("spec.support.builders")
local layout = require("scripts.layout")
local grid = require("scripts.grid")
local validator = require("spec.support.blueprint_validator")

local NAMES = builders.NAMES

-- Helpers that only look things up in the result.

local function entities_named(entities, name)
  local found = {}
  for _, entity in ipairs(entities) do
    if entity.name == name then
      found[#found + 1] = entity
    end
  end
  return found
end

local function count_named(entities, name)
  return #entities_named(entities, name)
end

-- The entity whose top-left tile is (tile_x, tile_y), or nil. `size` is how many
-- tiles wide and tall it is (default 1, a furnace is 2).
local function entity_at(entities, tile_x, tile_y, size)
  for _, entity in ipairs(entities) do
    local tile = grid.top_left_tile(entity.position, size, size)
    if tile.x == tile_x and tile.y == tile_y then
      return entity
    end
  end
end

-- What stands on a tile, as a name; nil if nothing does.
local function name_at(entities, tile_x, tile_y, size)
  local entity = entity_at(entities, tile_x, tile_y, size)
  return entity and entity.name
end

-- Which way the entity on a tile faces; nil if nothing stands there.
local function direction_at(entities, tile_x, tile_y)
  local entity = entity_at(entities, tile_x, tile_y)
  return entity and entity.direction
end

-- The top-left tiles of 1x1 entities, in order.
local function tiles_of(entities)
  local tiles = {}
  for _, entity in ipairs(entities) do
    tiles[#tiles + 1] = grid.top_left_tile(entity.position)
  end
  return tiles
end

local function directions_of(entities)
  local directions = {}
  for _, entity in ipairs(entities) do
    directions[#directions + 1] = entity.direction
  end
  return directions
end

local function count_wires(entities)
  local total = 0
  for _, entity in ipairs(entities) do
    total = total + #(entity.wires or {})
  end
  return total
end

describe("layout", function()
  describe("how many of each thing", function()
    it("gives three furnaces three furnaces", function()
      local entities = layout.build(3, NAMES)

      assert.are.equal(3, count_named(entities, NAMES.machine))
    end)

    it("gives three furnaces twelve belts, because each furnace adds two rows to both belts", function()
      local entities = layout.build(3, NAMES)

      assert.are.equal(12, count_named(entities, NAMES.belt)) -- 3 furnaces x 2 rows x 2 belts
    end)

    it("gives three furnaces six inserters, one in and one out each", function()
      local entities = layout.build(3, NAMES)

      assert.are.equal(6, count_named(entities, NAMES.inserter))
    end)

    it("gives one furnace two poles, one on each side", function()
      local entities = layout.build(1, NAMES)

      assert.are.equal(2, count_named(entities, NAMES.pole))
    end)

    it("lets two furnaces share their poles, so they still need only two", function()
      local entities = layout.build(2, NAMES)

      assert.are.equal(2, count_named(entities, NAMES.pole))
    end)

    it("needs a new pair of poles for a third furnace", function()
      local entities = layout.build(3, NAMES)

      assert.are.equal(4, count_named(entities, NAMES.pole))
    end)

    it("needs six poles for five furnaces", function()
      local entities = layout.build(5, NAMES)

      assert.are.equal(6, count_named(entities, NAMES.pole))
    end)

    it("makes exactly 25 entities for three furnaces, with nothing else added", function()
      local entities = layout.build(3, NAMES)

      assert.are.equal(25, #entities) -- 3 furnaces + 12 belts + 6 inserters + 4 poles
    end)

    it("numbers the entities 1 to n in order, one number each", function()
      local entities = layout.build(1, NAMES)

      local numbers = {}
      for _, entity in ipairs(entities) do
        numbers[#numbers + 1] = entity.entity_number
      end
      assert.are.same({1, 2, 3, 4, 5, 6, 7, 8, 9}, numbers) -- 4 belts + furnace + 2 inserters + 2 poles
    end)
  end)

  describe("where things stand", function()
    it("makes both belts run the full four tiles for two furnaces, side by side", function()
      local entities = layout.build(2, NAMES)

      local belts = entities_named(entities, NAMES.belt)

      assert.are.same({
        {x = 0, y = 0}, {x = 5, y = 0},
        {x = 0, y = 1}, {x = 5, y = 1},
        {x = 0, y = 2}, {x = 5, y = 2},
        {x = 0, y = 3}, {x = 5, y = 3},
      }, tiles_of(belts))
    end)

    it("makes every belt run south", function()
      local entities = layout.build(1, NAMES)

      local belts = entities_named(entities, NAMES.belt)

      local south = defines.direction.south
      assert.are.same({south, south, south, south}, directions_of(belts))
    end)

    it("reads input belt, input inserter, furnace, output inserter, output belt along the first furnace's top row", function()
      local entities = layout.build(1, NAMES)

      assert.are.equal(NAMES.belt, name_at(entities, 0, 0))
      assert.are.equal(NAMES.inserter, name_at(entities, 1, 0))
      assert.are.equal(NAMES.machine, name_at(entities, 2, 0, 2))
      assert.are.equal(NAMES.inserter, name_at(entities, 4, 0))
      assert.are.equal(NAMES.belt, name_at(entities, 5, 0))
    end)

    it("puts the second furnace two tiles below the first", function()
      local entities = layout.build(2, NAMES)

      assert.are.equal(NAMES.machine, name_at(entities, 2, 0, 2))
      assert.are.equal(NAMES.machine, name_at(entities, 2, 2, 2))
    end)

    it("makes both inserters face west, picking up from the west and dropping to the east", function()
      local entities = layout.build(1, NAMES)

      local input_direction = direction_at(entities, 1, 0) -- picks up from the input belt, drops into the furnace
      local output_direction = direction_at(entities, 4, 0) -- picks up from the furnace, drops onto the output belt

      assert.are.equal(defines.direction.west, input_direction)
      assert.are.equal(defines.direction.west, output_direction)
    end)

    it("puts poles in the free tile below each inserter, for every second furnace", function()
      local entities = layout.build(3, NAMES)

      local poles = entities_named(entities, NAMES.pole)

      assert.are.same({
        {x = 1, y = 1}, {x = 4, y = 1}, -- below the first furnace's inserters
        {x = 1, y = 5}, {x = 4, y = 5}, -- below the third furnace's inserters
      }, tiles_of(poles))
    end)
  end)

  describe("wires", function()
    it("joins one furnace's two poles with a single wire", function()
      local entities = layout.build(1, NAMES)

      assert.are.equal(1, count_wires(entities))
    end)

    it("joins four poles with three wires: one down each side and one across the top", function()
      local entities = layout.build(3, NAMES)

      assert.are.equal(3, count_wires(entities))
    end)
  end)

  describe("the whole blueprint, checked by the generic validator", function()
    for _, furnace_count in ipairs({1, 2, 3, 4, 5, 24}) do
      it("passes the validator for " .. furnace_count .. " furnaces", function()
        local small_pole_catalog = builders.a_catalog{pole_supply_radius = 2.5, pole_wire_reach = 7.5}

        local entities = layout.build(furnace_count, NAMES)
        local problems = validator.validate(entities, small_pole_catalog)

        assert.are.same({}, problems)
      end)
    end
  end)
end)
