-- scripts/generator.lua
-- The one place that reads the game's prototype data (recipes, machines) and
-- connects it to the pure planner and layout modules. Only call it from event
-- handlers: `prototypes` does not exist while control.lua is first loading.

local config = require("scripts.config")
local planner = require("scripts.planner")
local layout = require("scripts.layout")

local generator = {}

-- Turn a number into short text for messages: 56.25 -> "56.25", 60 -> "60".
-- (`string.format` rounds to 2 decimals; the gsub then trims trailing zeros.
-- The extra parentheses keep only gsub's first result, the text.)
---@param value number
---@return string
local function format_number(value)
  return (string.format("%.2f", value):gsub("%.?0+$", ""))
end

-- Copy a recipe prototype into a plain table for the planner.
---@param recipe_name string
---@return bpgen.Recipe|nil
local function read_recipe(recipe_name)
  local prototype = prototypes.recipe[recipe_name]
  if not prototype then
    return nil
  end

  local recipe = {energy = prototype.energy, ingredients = {}, products = {}}
  for _, ingredient in ipairs(prototype.ingredients) do
    recipe.ingredients[#recipe.ingredients + 1] = {name = ingredient.name, amount = ingredient.amount}
  end
  for index, product in ipairs(prototype.products) do
    -- get_product_amount gives the average amount per craft, which also covers
    -- products with a random or ranged amount.
    recipe.products[#recipe.products + 1] = {name = product.name, amount = prototype.get_product_amount(index)}
  end
  return recipe
end

-- A LocalisedString for an error: the key is looked up in the locale file.
---@param key string  a key of the [blueprint-generation] section of the locale file
---@param ... LocalisedString|number|string  values for __1__, __2__ ... in the text
---@return LocalisedString
local function error_message(key, ...)
  return {"blueprint-generation." .. key, ...} --[[@as LocalisedString]]
end

-- The prototype names the layout is given.
---@param product bpgen.Product
---@return bpgen.Names
local function names_for(product)
  return {
    machine = product.machine,
    belt = config.entities.belt,
    inserter = config.entities.inserter,
    pole = config.entities.pole,
  }
end

-- Everything about the game that generating needs, copied into plain values.
-- Returns nil if something is missing (another mod could have removed or renamed
-- it): a building, the recipe, the machine's speed, or the belt's speed.
---@class bpgen.GameData  the game values generating needs, as plain data
---@field recipe bpgen.Recipe
---@field machine_speed number
---@field belt_speed number

---@param product bpgen.Product
---@param names bpgen.Names
---@return bpgen.GameData|nil
local function read_game_data(product, names)
  for _, entity_name in pairs(names) do
    if not prototypes.entity[entity_name] then
      return nil
    end
  end
  local recipe = read_recipe(product.recipe)
  local machine_speed = prototypes.entity[names.machine].get_crafting_speed()
  -- `belt_speed` is nil unless the entity really is a transport belt.
  local belt_speed = prototypes.entity[names.belt].belt_speed
  if not recipe or not machine_speed or not belt_speed then
    return nil
  end
  return {recipe = recipe, machine_speed = machine_speed, belt_speed = belt_speed}
end

-- Why the planner said no, as a message for the player.
---@param reason string  the planner's refusal reason
---@param max_rate number|nil
---@return LocalisedString
local function refusal_message(reason, max_rate)
  if reason == "rate-too-high" then
    ---@cast max_rate number -- the planner always gives it with this reason
    return error_message("error-rate-too-high", format_number(max_rate))
  end
  return error_message("error-unsupported-recipe")
end

---@param item_name string
---@param product bpgen.Product
---@param plan bpgen.Plan
---@return string
local function describe_blueprint(item_name, product, plan)
  return string.format("%s: %s per minute from %d x %s",
    item_name, format_number(plan.output_per_minute), plan.machines, product.machine)
end

-- The LocalisedString shown to the player when a blueprint is ready. The locale
-- entry fills __1__ to __8__ from the values below, in this order.
---@param item_name string
---@param product bpgen.Product
---@param plan bpgen.Plan
---@param rate_per_minute number
---@return LocalisedString
local function success_message(item_name, product, plan, rate_per_minute)
  return {
    "blueprint-generation.generated",
    string.format("%d", plan.machines),
    prototypes.entity[product.machine].localised_name,
    format_number(plan.output_per_minute),
    prototypes.item[item_name].localised_name,
    format_number(rate_per_minute),
    prototypes.item[plan.ingredient].localised_name,
    prototypes.item[product.fuel].localised_name,
  }
end

-- Make the blueprint for `rate_per_minute` of `item_name`.
-- On success returns a table {entities, description, message}:
--   entities     the blueprint entities, ready for set_blueprint_entities
--   description  text for the blueprint's description field
--   message      a LocalisedString to show the player
-- On failure returns nil and a LocalisedString explaining why.
---@param item_name string
---@param rate_per_minute number
---@return bpgen.Generated|nil
---@return LocalisedString|nil error_message
function generator.generate(item_name, rate_per_minute)
  local product = config.products[item_name]
  if not product then
    return nil, error_message("error-unsupported-item")
  end

  local names = names_for(product)
  local game = read_game_data(product, names)
  if not game then
    return nil, error_message("error-missing-prototype")
  end

  local lane_items_per_minute = planner.lane_items_per_minute(game.belt_speed)
  local plan, reason, max_rate = planner.plan(
    item_name, rate_per_minute, game.recipe, game.machine_speed, lane_items_per_minute)
  if not plan then
    ---@cast reason string -- the planner always gives a reason when it gives no plan
    return nil, refusal_message(reason, max_rate)
  end

  return {
    entities = layout.build(plan.machines, names),
    description = describe_blueprint(item_name, product, plan),
    message = success_message(item_name, product, plan, rate_per_minute),
  }
end

return generator
