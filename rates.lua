local BlueprintSkeleton = require("blueprint-generation.metatables.BlueprintSkeleton")
local rates = {}

local belt_prefixes = {"", "fast-", "express-"}
local inserters = {"inserter", "fast-inserter", "bulk-inserter"}

---@param modules string[]
---@return table<string, double>
local function _combine_effects(modules)
    local module_effects = {speed = 0.0, productivity = 0.0}

    for _, module_name in ipairs(modules) do
        local effects = prototypes.item[module_name].get_module_effects()
        if not effects then
            error("Module " .. module_name .. " has no effects")
        end

        module_effects.speed = module_effects.speed + (effects.speed or 0)
        module_effects.productivity = module_effects.productivity + (effects.productivity or 0)
    end

    return module_effects
end

---@param crafting_entity BPGNGhostEntity
---@return table<string, double>
local function _get_module_effects(crafting_entity)
    local modules = {}

    for _, plan in ipairs(crafting_entity:get_insert_plan()) do
        local quantity = 0

        for _, inventory_position in plan.items.in_inventory do
            if inventory_position.inventory == defines.inventory.crafter_modules then
                quantity = quantity + inventory_position.count
            end
        end

        for i = 1, quantity do
            table.insert(modules, plan.id)
        end
    end

    return _combine_effects(modules)
end

---@class BeltFamily
---@field normal string
---@field underground string
---@field splitter string

---@param rate double
---@return BeltFamily
local function _get_best_transport_belt(rate)
    return {normal = "express-transport-belt", underground = "express-underground-belt", splitter = "express-splitter"}
end

---@param rate double
---@param belt_speed double
---@return string
local function _get_best_inserter(rate, belt_speed)
    local force = game.forces["player"]

    for _, inserter in ipairs(inserters) do
        local prototype = prototypes.entity[inserter]

        local stack_bonus = prototype.bulk and force.bulk_inserter_capacity_bonus or force.inserter_stack_size_bonus
        local rotation_rate = (prototype.get_inserter_rotation_speed() or 0) * 60
        local items_per_second = (stack_bonus + 1) / (stack_bonus / belt_speed + 1 / rotation_rate)

        if items_per_second > rate then
            return inserter
        end
    end

    return inserters[#inserters]
end

---@param recipe LuaRecipe
---@param product string
---@param crafting_entity LuaEntityPrototype
---@param modules string[]
---@return double
function rates.get_output_rate(recipe, product, crafting_entity, modules)
    local module_effects = _combine_effects(modules)
    local base_rate = crafting_entity.get_crafting_speed()
            * (1 + module_effects.speed)
            * (1 + module_effects.productivity)
            / recipe.energy

    for _, c_product in ipairs(recipe.products) do
        if c_product.name == product and c_product.amount then
            return base_rate * c_product.amount
        end
    end

    error("Could not find product for recipe: " .. product .. ", " .. recipe)
end

---@param recipe LuaRecipe
---@param product string
---@param crafting_entity LuaEntityPrototype
---@param modules string[]
---@param product_rate double
---@return table<string, double>
function rates.get_input_rates(recipe, product, crafting_entity, modules, product_rate)
    ---@type table<string, double>
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

---@param recipe LuaRecipe
---@param output Product
---@param modules string[]
---@param output_rate double
---@return BlueprintSkeleton
function rates.get_skeleton(recipe, output, modules, output_rate)
    local result = BlueprintSkeleton.new()

    local output_amount = nil
    for _, product in ipairs(recipe.products) do
        if product.name == output.name and product.amount then
            output_amount = product.amount
            break
        end
    end

    if not output_amount then
        error("Could not find product " .. output .. " in recipe") 
    end

    local input_multiplier = output_rate / output_amount / (1 + _combine_effects(modules).productivity)
    local output_multiplier = output_rate / output_amount
    
    ---@type {name: string, rate: double}[]
    local item_input_rates = {}
    ---@type {name: string, rate: double}[]
    local fluid_input_rates = {}

    for _, ingredient in ipairs(recipe.ingredients) do
        if ingredient.type == "item" then
            table.insert(item_input_rates, {name = ingredient.name, rate = ingredient.amount * input_multiplier})
        else
            table.insert(fluid_input_rates, {name = ingredient.name, rate = ingredient.amount * input_multiplier})
        end
    end

    ---@type {name: string, rate: double}[]
    local output_rates = {}

    for _, product in ipairs(recipe.products) do
        if product.amount then
            table.insert(output_rates, {name = product.name, rate = product.amount * output_multiplier})
        end
    end

    table.sort(item_input_rates, function(a, b) return a.rate < b.rate end)
    table.sort(fluid_input_rates, function(a, b) return a.rate < b.rate end)

    local input_layer = 1

    for i = 1, #item_input_rates, 2 do
        if i == #item_input_rates then
            local current_item = item_input_rates[i]

            local current_belt = _get_best_transport_belt(current_item.rate)
            local current_inserter = _get_best_inserter(current_item.rate, (prototypes.entity[current_belt.normal].belt_speed or 0) * 60 * 4)

            result.input_values[current_item.name] = {side = "left", layer = input_layer, rate = current_item.rate}
            table.insert(result.input_layers, {belt = current_belt, inserter = current_inserter, type = "item", items = {current_item.name}})
        else
            local current_item = item_input_rates[i]
            local next_item = item_input_rates[i + 1]
            if not next_item then
                break
            end

            local current_belt = _get_best_transport_belt(math.max(current_item.rate, next_item.rate))
            local current_inserter = _get_best_inserter(current_item.rate + next_item.rate, (prototypes.entity[current_belt.normal].belt_speed or 0) * 60 * 4)

            result.input_values[current_item.name] = {side = "left", layer = input_layer, rate = current_item.rate}
            result.input_values[next_item.name] = {side = "right", layer = input_layer, rate = next_item.rate}
            table.insert(result.input_layers, {belt = current_belt, inserter = current_inserter, type = "item", items = {current_item.name, next_item.name}})
        end

        input_layer = input_layer + 1
    end

    for i = 1, #fluid_input_rates do
        result.input_values[fluid_input_rates[i].name] = {layer = input_layer, rate = fluid_input_rates[i].rate}
        table.insert(result.input_layers, {type = "fluid", fluid = fluid_input_rates[i].name})
        input_layer = input_layer + 1
    end

    if output.probability < 1 and output.type == "item" then
        local new_output_names = {}
        local total_output_rate = 0.0

        for _, o_rate in ipairs(output_rates) do
            table.insert(new_output_names, o_rate.name)
            total_output_rate = total_output_rate + o_rate.rate
        end

        local output_belt = _get_best_transport_belt(total_output_rate)
        local output_inserter = _get_best_inserter(total_output_rate, (prototypes.entity[output_belt.normal].belt_speed or 0) * 60 * 4)
        
        for _, new_output in ipairs(output_rates) do
            result.output_values[new_output.name] = {layer = 1, rate = new_output.rate}
        end
        table.insert(result.output_layers, {belt = output_belt, inserter = output_inserter, type = "item", items = new_output_names})
    else
        for i = 1, #output_rates do
            local new_output = output_rates[i]

            if output.type == "item" then
                local output_belt = _get_best_transport_belt(new_output.rate)
                local output_inserter = _get_best_inserter(new_output.rate, (prototypes.entity[output_belt.normal].belt_speed or 0) * 60 * 4)

                result.output_values[new_output.name] = {layer = i, rate = new_output.rate}
                table.insert(result.output_layers, {belt = output_belt, inserter = output_inserter, type = "item", items = {new_output.name}})
            else
                result.output_values[new_output.name] = {layer = i, rate = new_output.rate}
                table.insert(result.output_layers, {type = "fluid", fluid = new_output.name})
            end
        end
    end

    return result
end

return rates
