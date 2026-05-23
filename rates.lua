local util = require("util")

local rates = {}

local function _combine_effects(modules)
    local module_effects = {speed = 0.0, productivity = 0.0}

    for _, module_name in ipairs(modules) do
        local effects = prototypes.item[module_name].get_module_effects()
        module_effects.speed = module_effects.speed + (effects.speed or 0)
        module_effects.productivity = module_effects.productivity + (effects.productivity or 0)
    end

    return module_effects
end

local function _get_module_effects(crafting_entity)
    local modules = {}

    for _, plan in ipairs(crafting_entity.insert_plan) do
        local quantity = 0

        for _, inventory_position in plan.items.in_inventory do
            if inventory_position.inventory == defines.inventory.crafter_modules then
                quantity = quantity + inventory_position.count
            end
        end

        for i = 1, quantity do
            tables.add(modules, plan.id)
        end
    end

    return _combine_effects(modules)
end

local function _get_best_transport_belt(rate)
    return {normal="express-transport-belt", underground="express-underground-belt", splitter="express-splitter"}
end

local function _get_best_inserter(rate, belt_speed)
    local force = game.forces["player"]

    for _, inserter in ipairs(inserters) do
        local prototype = prototypes.entity[inserter]

        local stack_bonus = prototype.bulk and force.bulk_inserter_capacity_bonus or force.inserter_stack_size_bonus
        local rotation_rate = prototype.get_inserter_rotation_speed() * 60
        local items_per_second = (stack_bonus + 1) / (stack_bonus / belt_speed + 1 / rotation_rate)

        if items_per_second > rate then
            return inserter
        end
    end

    return inserters[#inserters]
end

function rates.get_output_rate(recipe, product, crafting_entity, modules)
    local module_effects = _combine_effects(modules)
    local base_rate = crafting_entity.get_crafting_speed()
            * (1 + module_effects.speed)
            * (1 + module_effects.productivity)
            / recipe.energy

    for _, c_product in ipairs(recipe.products) do
        if c_product.name == product then
            return base_rate * c_product.amount
        end
    end

    error("Could not find product for recipe: " .. product .. ", " .. recipe)
end

function rates.get_input_rates(recipe, product, crafting_entity, modules, product_rate)
    local result = {}

    local module_effects = _combine_effects(modules)
    local base_rate = crafting_entity.get_crafting_speed()
            * (1 + module_effects.speed)
            / recipe.energy

    local output_rate = rates.get_output_rate(recipe, product, crafting_entity, modules)
    local relative_rate = product_rate / output_rate

    for _, ingredient in ipairs(recipe.ingredients) do
        result[ingredient.name] = base_rate * ingredient.amount * relative_rate
    end

    return result
end

function rates.get_skeleton(recipe, modules, output_rate)
    local result = {}
    result.input = {}
    result.output = {}

    local output = recipe.products[1]

    local input_multiplier = output_rate / output.amount / (1 + _combine_effects(modules).productivity)
    local input_rates = {}

    for _, ingredient in ipairs(recipe.ingredients) do
        if ingredient.type == "item" then
            table.insert(input_rates, {name=ingredient.name, rate=ingredient.amount * input_multiplier})
        end
    end

    table.sort(input_rates, function(a, b) return a.rate < b.rate end)

    for i = 1, #input_rates, 2 do
        if i == #input_rates then
            local current_item = input_rates[i]

            local current_belt = _get_best_transport_belt(current_item.rate)
            local current_inserter = _get_best_inserter(current_item.rate, prototypes.entity[current_belt.normal].belt_speed * 60 * 4)

            result.input[{current_item.name}] = {belt=current_belt, inserter=current_inserter}
        else
            local current_item = input_rates[i]
            local next_item = input_rates[i + 1]

            local current_belt = _get_best_transport_belt(math.max(current_item.rate, next_item.rate))
            local current_inserter = _get_best_inserter(current_item.rate + next_item.rate, prototypes.entity[current_belt.normal].belt_speed * 60 * 4)

            result.input[{current_item.name, next_item.name}] = {belt=current_belt, inserter=current_inserter}
        end
    end

    if output.type == "item" then
        local output_belt = _get_best_transport_belt(output_rate)
        local output_inserter = _get_best_inserter(output_rate, prototypes.entity[output_belt.normal].belt_speed * 60 * 4)

        result.output[{output.name}] = {belt=output_belt, inserter=output_inserter}
    end

    return result
end

return rates