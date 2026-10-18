local memory = {}

---@alias MainMemory RecipeData

---@class BPGNStorage
---@field bpgn_memory table<integer, MainMemory>
---@field bpgn_gui table<integer, GUIMemory>

---@type BPGNStorage
storage = storage

---@param player_index integer
function memory.init(player_index)
    if not storage.bpgn_memory then
        storage.bpgn_memory = {}
    end

    if not storage.bpgn_memory[player_index] then
        ---@type MainMemory
        storage.bpgn_memory[player_index] = {recipe = "iron-plate", product = "iron-plate", rate = 1}
    end
end

---@param player_index integer
---@return MainMemory
function memory.retrieve(player_index)
    memory.init(player_index)
    return storage.bpgn_memory[player_index]
end

---@param player_index integer
---@param key string
---@param value any
function memory.save(player_index, key, value)
    memory.init(player_index)
    storage.bpgn_memory[player_index][key] = value
end

return memory
