-- spec/blueprint_validator_spec.lua
-- A checker that never complains proves nothing, so these specs hand-build tiny
-- blueprints, break them in one specific way, and expect that problem (and only
-- a problem of that kind) to be reported. The blueprints do not come from the
-- layout, so each example shows every coordinate it relies on.
--
-- Coordinates are tiles: (x, y) is the top-left tile an entity covers, with y
-- growing downward (see scripts/grid.lua). The 2x2 furnace at (2, 0) covers
-- tiles x 2 to 3 and y 0 to 1. An inserter at (1, 0) facing west picks up from
-- tile (0, 0) and drops onto tile (2, 0).
---@diagnostic disable: undefined-field  -- luassert's `assert` has fields (`assert.are`, `assert.is_nil`, ...) the editor cannot see
---@diagnostic disable: need-check-nil  -- entities come from `blueprint_of`, which numbers every one
---@diagnostic disable: param-type-mismatch  -- some entities are damaged on purpose, and the fake `defines` holds strings, not Factorio's numbers

local builders = require("spec.support.builders")
local validator = require("spec.support.blueprint_validator")

local belt, furnace, inserter, pole = builders.belt, builders.furnace, builders.inserter, builders.pole
local blueprint_of, wire_between, a_catalog = builders.blueprint_of, builders.wire_between, builders.a_catalog
local west, north = defines.direction.west, defines.direction.north

describe("blueprint validator", function()
  describe("a blueprint that is fine", function()
    it("a belt feeding a furnace through a powered inserter has no problems", function()
      local entities = blueprint_of(belt(0, 0), inserter(1, 0, west), furnace(2, 0), pole(1, 1))

      local problems = validator.validate(entities, a_catalog{})

      assert.are.same({}, problems)
    end)

    it("belts alone are fine, whichever way they turn", function()
      local entities = blueprint_of(belt(0, 0, defines.direction.east), belt(1, 0, north))

      local problems = validator.validate(entities, a_catalog{})

      assert.are.same({}, problems)
    end)
  end)

  describe("names, numbers and the tile grid", function()
    it("an entity the catalog does not know is reported", function()
      local mystery_belt = belt(0, 0)
      mystery_belt.name = "mystery-belt"
      local entities = blueprint_of(mystery_belt)

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("not in the catalog", problems)
    end)

    it("an entity without a number is reported", function()
      local numberless = belt(0, 0) -- not passed through blueprint_of, so it has no number

      local problems = validator.validate({numberless}, a_catalog{})

      assert.has_item_containing("has no entity number", problems)
    end)

    it("two entities sharing a number are reported", function()
      local entities = blueprint_of(belt(0, 0), belt(0, 1))
      entities[2].entity_number = entities[1].entity_number

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("reuses an entity number", problems)
    end)

    it("a 1x1 entity off the half-tile grid is reported", function()
      local entities = blueprint_of(inserter(0.75, 0, west))

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("not aligned to the tile grid", problems)
    end)

    it("a 2x2 furnace on a half tile is reported, because it belongs on a whole tile", function()
      local entities = blueprint_of(furnace(2.5, 0))

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("not aligned to the tile grid", problems)
    end)
  end)

  describe("overlaps", function()
    it("two poles on the same tile are reported", function()
      local entities = blueprint_of(pole(1, 1), pole(1, 1))

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("overlaps", problems)
    end)

    it("a pole standing on one corner tile of a furnace is reported", function()
      local entities = blueprint_of(furnace(2, 0), pole(2, 0)) -- the furnace covers tile (2, 0)

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("overlaps", problems)
    end)
  end)

  describe("inserters", function()
    it("an inserter without a direction is reported", function()
      local entities = blueprint_of(inserter(1, 0, nil), pole(1, 1))

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("no usable direction", problems)
    end)

    it("an inserter with nothing on its pickup tile is reported", function()
      local entities = blueprint_of(inserter(1, 0, west), furnace(2, 0), pole(1, 1)) -- tile (0, 0) is empty

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("nothing to pick up from", problems)
    end)

    it("an inserter picking up from a pole is reported, because a pole holds no items", function()
      local entities = blueprint_of(pole(0, 0), inserter(1, 0, west), furnace(2, 0))

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("nothing to pick up from", problems)
    end)

    it("an inserter with nothing on its drop tile is reported", function()
      local entities = blueprint_of(belt(0, 0), inserter(1, 0, west), pole(1, 1)) -- tile (2, 0) is empty

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("nothing to drop onto", problems)
    end)

    it("an inserter pointing north at open ground and a pole is reported on both ends", function()
      -- Facing north it picks up from tile (1, -1), which is empty, and drops onto tile (1, 1), a pole.
      local entities = blueprint_of(inserter(1, 0, north), furnace(2, 0), pole(1, 1))

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("nothing to pick up from", problems)
      assert.has_item_containing("nothing to drop onto", problems)
    end)

    it("an inserter moving items from one belt to another is reported, because no machine is involved", function()
      local entities = blueprint_of(belt(0, 0), inserter(1, 0, west), belt(2, 0), pole(1, 1))

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("does not touch a machine", problems)
    end)
  end)

  describe("power: supply area", function()
    it("an inserter with no pole at all is reported as unpowered", function()
      local entities = blueprint_of(belt(0, 0), inserter(1, 0, west), furnace(2, 0))

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("outside every pole's supply area", problems)
    end)

    it("a pole two tiles away powers a 1x1 inserter when its supply radius is 2.5", function()
      local entities = blueprint_of(belt(0, 0), inserter(1, 0, west), furnace(2, 0), pole(1, 2))

      local problems = validator.validate(entities, a_catalog{pole_supply_radius = 2.5})

      assert.are.same({}, problems)
    end)

    it("a pole three tiles away only touches the inserter's edge, which does not power it", function()
      -- The pole on tile row 3 is centred at y = 3.5, so it powers everything down to
      -- y = 1.0 (3.5 - 2.5). The inserter covers y = 0 to 1, so the two only share an
      -- edge, not any floor space.
      local entities = blueprint_of(belt(0, 0), inserter(1, 0, west), furnace(2, 0), pole(1, 3))

      local problems = validator.validate(entities, a_catalog{pole_supply_radius = 2.5})

      assert.has_item_containing("outside every pole's supply area", problems)
    end)

    it("a pole sideways beside a 2x2 machine powers it when the supply area overlaps its edge", function()
      local entities = blueprint_of(furnace(2, 0), pole(5, 1)) -- its centre is 2.5 tiles from the furnace's centre, but only 1.5 from its edge

      local problems = validator.validate(entities, a_catalog{machine_needs_power = true, pole_supply_radius = 2.5})

      assert.are.same({}, problems)
    end)

    it("a pole too far sideways from a 2x2 machine does not power it", function()
      local entities = blueprint_of(furnace(2, 0), pole(7, 1)) -- its centre is 4.5 tiles from the furnace's centre, 3.5 from its edge

      local problems = validator.validate(entities, a_catalog{machine_needs_power = true, pole_supply_radius = 2.5})

      assert.has_item_containing("outside every pole's supply area", problems)
    end)

    it("a pole below a 2x2 machine powers it when the supply area overlaps its edge", function()
      local entities = blueprint_of(furnace(2, 0), pole(1, 3)) -- its centre is 2.5 tiles below the furnace's centre, 1.5 below its edge

      local problems = validator.validate(entities, a_catalog{machine_needs_power = true, pole_supply_radius = 2.5})

      assert.are.same({}, problems)
    end)

    it("a pole too far below a 2x2 machine does not power it", function()
      local entities = blueprint_of(furnace(2, 0), pole(1, 5)) -- its centre is 4.5 tiles below the furnace's centre, 3.5 below its edge

      local problems = validator.validate(entities, a_catalog{machine_needs_power = true, pole_supply_radius = 2.5})

      assert.has_item_containing("outside every pole's supply area", problems)
    end)
  end)

  describe("power: wires and networks", function()
    it("two poles joined by a wire form one network", function()
      local first, second = pole(0, 0), pole(5, 0)
      local entities = blueprint_of(first, second)
      wire_between(first, second)

      local problems = validator.validate(entities, a_catalog{pole_wire_reach = 7.5})

      assert.are.same({}, problems)
    end)

    it("two poles with no wire are reported as separate networks", function()
      local entities = blueprint_of(pole(0, 0), pole(5, 0))

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("separate networks", problems)
    end)

    it("a wire exactly as long as the reach is fine", function()
      local first, second = pole(0, 0), pole(7, 0) -- 7 tiles apart
      local entities = blueprint_of(first, second)
      wire_between(first, second)

      local problems = validator.validate(entities, a_catalog{pole_wire_reach = 7})

      assert.are.same({}, problems)
    end)

    it("a wire longer than the reach is reported", function()
      local first, second = pole(0, 0), pole(8, 0) -- 8 tiles apart
      local entities = blueprint_of(first, second)
      wire_between(first, second)

      local problems = validator.validate(entities, a_catalog{pole_wire_reach = 7})

      assert.has_item_containing("longer than its reach", problems)
    end)

    it("a wire is limited by the SHORTER reach of its two poles", function()
      local first = pole(0, 0)                  -- reach 7.5
      local second = pole(5, 0, "short-pole")   -- reach 3, 5 tiles away
      local catalog = a_catalog{pole_wire_reach = 7.5}
      catalog["short-pole"] = {kind = "pole", width = 1, height = 1, supply_radius = 1, wire_reach = 3}
      local entities = blueprint_of(first, second)
      wire_between(first, second)

      local problems = validator.validate(entities, catalog)

      assert.has_item_containing("longer than its reach", problems)
    end)

    it("a wire listed on an entity it does not start from is reported", function()
      local first, second = pole(0, 0), pole(5, 0)
      local entities = blueprint_of(first, second)
      wire_between(first, second)
      first.wires[1][1] = second.entity_number -- now claims to start on the second pole

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("starts on another entity", problems)
    end)

    it("a wire to something that is not a pole is reported", function()
      local a_pole, a_belt = pole(0, 0), belt(3, 0)
      local entities = blueprint_of(a_pole, a_belt)
      wire_between(a_pole, a_belt)

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("does not join two poles", problems)
    end)

    it("a wire to a misaligned pole is reported as a problem, not a crash", function()
      local first, second = pole(0, 0), pole(4.75, 0) -- the second is off the tile grid
      local entities = blueprint_of(first, second)
      wire_between(first, second)

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("not aligned to the tile grid", problems)
    end)

    it("a wire to a misaligned pole does not hide that the other poles are separate", function()
      local first, second, misaligned = pole(0, 0), pole(5, 0), pole(9.75, 0)
      local entities = blueprint_of(first, second, misaligned)
      wire_between(first, misaligned) -- the first and second poles are still not connected to each other

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("separate networks", problems)
    end)

    it("a wire that does not use the copper connector is reported", function()
      local first, second = pole(0, 0), pole(5, 0)
      local entities = blueprint_of(first, second)
      wire_between(first, second)
      first.wires[1][2] = "something_else"

      local problems = validator.validate(entities, a_catalog{})

      assert.has_item_containing("copper connector", problems)
    end)
  end)
end)
