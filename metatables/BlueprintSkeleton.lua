package.path = "../?.lua"


---@class SkeletonValue
---@field side? "left" | "right"
---@field layer integer
---@field rate double

---@class SkeletonLayer
---@field belt BeltFamily
---@field inserter string
---@field type ItemType
---@field items string[]
---@field fluid string

---@class BlueprintSkeleton
---@field input_values table<string, SkeletonValue>
---@field output_values table<string, SkeletonValue>
---@field input_layers SkeletonLayer[]
---@field output_layers SkeletonLayer[]
---@operator tostring: string
local BlueprintSkeleton = {}

---@return BlueprintSkeleton
function BlueprintSkeleton.new()
    local blueprint_skeleton = {
        input_values = {},
        output_values = {},
        input_layers = {},
        output_layers = {}
    }
    
    return setmetatable(blueprint_skeleton, BlueprintSkeleton)
end

---@return string
function BlueprintSkeleton:toString()
    return "Input: " .. serpent.block(self.input_values) .. "\nOutput: " .. serpent.block(self.output_values) 
end

return BlueprintSkeleton
