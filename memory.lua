local memory = {}

function memory.init(player_index)
    if not storage.bpgn_memory then
        storage.bpgn_memory = {}
    end

    if not storage.bpgn_memory[player_index] then
        storage.bpgn_memory[player_index] = {recipe="iron-plate", quantity=1}
    end
end

function memory.retrieve(player_index)
    memory.init(player_index)
    return storage.bpgn_memory[player_index]
end

function memory.save(player_index, key, value)
    memory.init(player_index)
    storage.bpgn_memory[player_index][key] = value
end

return memory