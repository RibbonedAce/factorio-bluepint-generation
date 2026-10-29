-- scripts/planner.lua
-- Pure maths: how many machines does a product rate need?
-- It never touches the game (no `game`, no `prototypes`), so it can be tested
-- outside Factorio. The caller passes in plain tables with the numbers.

local planner = {}

-- Decimal numbers like 3.2 cannot be stored exactly, so 18.75 / 18.749999999999996
-- can come out as 1.0000000000000002 and round up to a whole extra machine.
-- Subtracting a tiny amount before rounding up avoids that.
local EPSILON = 1e-9

-- Add up how many of `item_name` one craft of the recipe makes.
local function amount_made(recipe, item_name)
  local total = 0
  for _, product in ipairs(recipe.products) do
    if product.name == item_name then
      total = total + product.amount
    end
  end
  return total
end

-- How many items ONE LANE of a belt carries per minute, from the belt's speed
-- (the `belt_speed` of the belt entity prototype). The prototype docs define the
-- speed as tiles travelled per tick relative to a full belt, and a full lane holds
-- 4 items per tile, so a lane moves belt_speed * 4 items/tick * 60 ticks/second.
-- (The standard belt's speed, 0.03125, gives 7.5 items/s, which is 450 per minute.)
local ITEMS_PER_LANE_PER_TILE = 4
local TICKS_PER_SECOND = 60
local SECONDS_PER_MINUTE = 60

function planner.lane_items_per_minute(belt_speed)
  return belt_speed * ITEMS_PER_LANE_PER_TILE * TICKS_PER_SECOND * SECONDS_PER_MINUTE
end

-- Whether this planner can handle the recipe: it must make the product, have
-- exactly one ingredient, and take time to craft.
local function is_supported(recipe, made_per_craft)
  return made_per_craft > 0 and #recipe.ingredients == 1 and recipe.energy > 0
end

-- What ONE machine does each minute: how much it makes and how much it eats.
local function rates_per_machine(recipe, machine_speed, made_per_craft)
  local crafts_per_minute = 60 * machine_speed / recipe.energy
  return crafts_per_minute * made_per_craft, crafts_per_minute * recipe.ingredients[1].amount
end

local function machines_needed(rate_per_minute, output_per_machine)
  return math.max(1, math.ceil(rate_per_minute / output_per_machine - EPSILON))
end

-- The input and the output each travel on one belt lane, so the busier of the
-- two decides how many machines one column can serve.
local function machines_per_lane(lane_items_per_minute, output_per_machine, input_per_machine)
  local busiest_flow = math.max(output_per_machine, input_per_machine)
  return math.floor(lane_items_per_minute / busiest_flow + EPSILON)
end

-- product_name        item the player wants
-- rate_per_minute     how many of it per minute
-- recipe              {energy = seconds,
--                      ingredients = {{name = ..., amount = ...}},
--                      products = {{name = ..., amount = ...}}}
-- machine_speed       the machine's crafting speed
-- lane_items_per_minute  how many items one belt lane can carry per minute
--
-- On success returns a plan table:
--   {machines, output_per_minute, ingredient, ingredient_per_minute}
-- On failure returns nil, a reason string, and sometimes an extra value:
--   "unsupported-recipe"        the recipe is not "one ingredient -> product"
--   "rate-too-high", max_rate   one belt lane cannot carry that rate; max_rate is the
--                               most a single column can make per minute
function planner.plan(product_name, rate_per_minute, recipe, machine_speed, lane_items_per_minute)
  local made_per_craft = amount_made(recipe, product_name)
  if not is_supported(recipe, made_per_craft) then
    return nil, "unsupported-recipe"
  end

  local output_per_machine, input_per_machine = rates_per_machine(recipe, machine_speed, made_per_craft)
  local machines = machines_needed(rate_per_minute, output_per_machine)
  local max_machines = machines_per_lane(lane_items_per_minute, output_per_machine, input_per_machine)
  if machines > max_machines then
    return nil, "rate-too-high", max_machines * output_per_machine
  end

  return {
    machines = machines,
    output_per_minute = machines * output_per_machine,
    ingredient = recipe.ingredients[1].name,
    ingredient_per_minute = machines * input_per_machine,
  }
end

return planner
