-- spec/generator_spec.lua
-- The generator reads the game's prototype data (here a stand-in assigned to
-- the global `prototypes`) and ties the planner and layout together.
--
-- Each test says which prototypes exist: the recipe it needs, and the furnace and
-- belt speeds its numbers depend on. A furnace of speed 1 on a 3.2 s recipe makes
-- 60 / 3.2 = 18.75 items a minute. Which items can be generated is decided by
-- scripts/config.lua, so the tests use `iron-plate` and `stone-brick` for the two
-- recipe shapes; the shapes, not the names, are what is being tested.
--
-- Busted runs each spec file in its own sandbox, where a plain assignment would
-- only be visible inside the spec. The generator reads the REAL global
-- `prototypes`, so the specs assign `_G.prototypes` explicitly.
---@diagnostic disable: undefined-field  -- luassert's `assert` has fields (`assert.are`, `assert.is_nil`, ...) the editor cannot see
---@diagnostic disable: need-check-nil  -- the assertion before each use fails the test first if the result is nil
---@diagnostic disable: global-in-non-module  -- `_G.prototypes = ...` is how a spec fakes the game's global (see the note above)

local builders = require("spec.support.builders")
local generator = require("scripts.generator")

local fake_prototypes = builders.fake_prototypes
local a_recipe = builders.a_recipe
local amount_of = builders.amount_of

local function count_named(entities, name)
  local total = 0
  for _, entity in ipairs(entities) do
    if entity.name == name then
      total = total + 1
    end
  end
  return total
end

-- The distinct entity names used, sorted, as a list.
local function distinct_names_of(entities)
  local seen, names = {}, {}
  for _, entity in ipairs(entities) do
    if entity.name and not seen[entity.name] then
      seen[entity.name] = true
      names[#names + 1] = entity.name
    end
  end
  table.sort(names)
  return names
end

describe("generator", function()
  describe("a recipe of one ingredient to one product", function()
    it("needs three stone furnaces for 50 items a minute", function()
      _G.prototypes = fake_prototypes{
        furnace_speed = 1,
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result = generator.generate("iron-plate", 50)

      assert.are.equal(3, count_named(result.entities, "stone-furnace")) -- 50 / 18.75 = 2.67, rounded up
    end)

    it("brings four small electric poles with three furnaces", function()
      _G.prototypes = fake_prototypes{
        furnace_speed = 1,
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result = generator.generate("iron-plate", 50)

      assert.are.equal(4, count_named(result.entities, "small-electric-pole"))
    end)

    it("uses only the four buildings the game provides, each under its own name", function()
      _G.prototypes = fake_prototypes{
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result = generator.generate("iron-plate", 50)

      assert.are.same(
        {"inserter", "small-electric-pole", "stone-furnace", "transport-belt"},
        distinct_names_of(result.entities))
    end)

    it("names the furnaces, the real rate achieved, the ingredient and the fuel in the message", function()
      _G.prototypes = fake_prototypes{
        furnace_speed = 1,
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result = generator.generate("iron-plate", 50)

      assert.are.same({
        "blueprint-generation.generated",
        "3",                           -- furnaces
        {"entity-name.stone-furnace"},
        "56.25",                       -- 3 x 18.75 achieved
        {"item-name.iron-plate"},
        "50",                          -- what was asked for
        {"item-name.iron-ore"},
        {"item-name.coal"},
      }, result.message)
    end)

    it("prints whole numbers without decimals", function()
      _G.prototypes = fake_prototypes{
        furnace_speed = 1,
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result = generator.generate("iron-plate", 60)

      assert.are.equal("75", result.message[4]) -- 4 furnaces x 18.75, not "75.00"
      assert.are.equal("60", result.message[6])
    end)

    it("gives the blueprint a description with the rate achieved and the furnaces used", function()
      _G.prototypes = fake_prototypes{
        furnace_speed = 1,
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result = generator.generate("iron-plate", 50)

      assert.are.equal("iron-plate: 56.25 per minute from 3 x stone-furnace", result.description)
    end)

    it("refuses a rate above one belt lane, naming the standard belt's 450 a minute", function()
      _G.prototypes = fake_prototypes{
        belt_speed = 0.03125,
        furnace_speed = 1,
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result, error_message = generator.generate("iron-plate", 1000)

      assert.is_nil(result)
      assert.are.same({"blueprint-generation.error-rate-too-high", "450"}, error_message)
    end)
  end)

  describe("a recipe of two of one ingredient to one product", function()
    it("allows exactly 225 items a minute with 12 furnaces, which fill the ingredient lane", function()
      _G.prototypes = fake_prototypes{
        belt_speed = 0.03125,
        furnace_speed = 1,
        recipes = {["stone-brick"] = a_recipe{energy = 3.2, ingredients = {amount_of(2, "stone")}, products = {amount_of(1, "stone-brick")}}},
      }

      local result = generator.generate("stone-brick", 225)

      assert.are.equal(12, count_named(result.entities, "stone-furnace")) -- 12 x 37.5 ingredients = 450, one lane
    end)

    it("refuses 300 items a minute, naming 225 as the most, because the ingredient lane fills before the product lane", function()
      _G.prototypes = fake_prototypes{
        belt_speed = 0.03125,
        furnace_speed = 1,
        recipes = {["stone-brick"] = a_recipe{energy = 3.2, ingredients = {amount_of(2, "stone")}, products = {amount_of(1, "stone-brick")}}},
      }

      local result, error_message = generator.generate("stone-brick", 300)

      assert.is_nil(result)
      assert.are.same({"blueprint-generation.error-rate-too-high", "225"}, error_message) -- 12 furnaces x 18.75
    end)
  end)

  describe("a recipe of one ingredient to two products", function()
    it("reads how many items a craft makes from the recipe, so 75 a minute needs two furnaces", function()
      _G.prototypes = fake_prototypes{
        furnace_speed = 1,
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(2, "iron-plate")}}},
      }

      local result = generator.generate("iron-plate", 75)

      assert.are.equal(2, count_named(result.entities, "stone-furnace")) -- 75 / (18.75 crafts x 2 items)
    end)
  end)

  describe("the belt's speed sets the limit, not a constant", function()
    it("allows 800 items a minute on a belt twice as fast, with 43 furnaces", function()
      _G.prototypes = fake_prototypes{
        belt_speed = 0.0625, -- a lane holds 900 a minute
        furnace_speed = 1,
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result = generator.generate("iron-plate", 800)

      assert.are.equal(43, count_named(result.entities, "stone-furnace")) -- 800 / 18.75 = 42.7, rounded up
    end)

    it("refuses 1000 items a minute on a belt twice as fast, naming 900 as the most", function()
      _G.prototypes = fake_prototypes{
        belt_speed = 0.0625,
        furnace_speed = 1,
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result, error_message = generator.generate("iron-plate", 1000)

      assert.is_nil(result)
      assert.are.same({"blueprint-generation.error-rate-too-high", "900"}, error_message) -- 48 furnaces x 18.75
    end)
  end)

  describe("refusals", function()
    it("refuses an item that is not supported", function()
      _G.prototypes = fake_prototypes{}

      local result, error_message = generator.generate("iron-gear-wheel", 10)

      assert.is_nil(result)
      assert.are.same({"blueprint-generation.error-unsupported-item"}, error_message)
    end)

    it("refuses when a building prototype is missing", function()
      _G.prototypes = fake_prototypes{
        missing_entities = {"inserter"},
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result, error_message = generator.generate("iron-plate", 10)

      assert.is_nil(result)
      assert.are.same({"blueprint-generation.error-missing-prototype"}, error_message)
    end)

    it("refuses when the recipe is missing", function()
      _G.prototypes = fake_prototypes{recipes = {}}

      local result, error_message = generator.generate("iron-plate", 10)

      assert.is_nil(result)
      assert.are.same({"blueprint-generation.error-missing-prototype"}, error_message)
    end)

    it("refuses a recipe with two different ingredients", function()
      _G.prototypes = fake_prototypes{
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore"), amount_of(1, "coal")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result, error_message = generator.generate("iron-plate", 10)

      assert.is_nil(result)
      assert.are.same({"blueprint-generation.error-unsupported-recipe"}, error_message)
    end)

    it("refuses a machine that cannot craft", function()
      _G.prototypes = fake_prototypes{
        furnace_speed = false,
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result, error_message = generator.generate("iron-plate", 10)

      assert.is_nil(result)
      assert.are.same({"blueprint-generation.error-missing-prototype"}, error_message)
    end)

    it("refuses a belt entity without a belt speed", function()
      _G.prototypes = fake_prototypes{
        belt_speed = false,
        recipes = {["iron-plate"] = a_recipe{energy = 3.2, ingredients = {amount_of(1, "iron-ore")}, products = {amount_of(1, "iron-plate")}}},
      }

      local result, error_message = generator.generate("iron-plate", 10)

      assert.is_nil(result)
      assert.are.same({"blueprint-generation.error-missing-prototype"}, error_message)
    end)
  end)
end)
