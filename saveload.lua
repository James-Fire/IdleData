-- Save/Load System
-- Handles serialization and deserialization of game state

local SaveLoad = {}

-- Serialize a table to a Lua code string
local function serialize(tbl, indent)
    indent = indent or ""
    local result = "{\n"
    
    for k, v in pairs(tbl) do
        local key
        if type(k) == "string" then
            key = string.format('["%s"]', k)
        else
            key = string.format("[%s]", tostring(k))
        end
        
        local value
        if type(v) == "table" then
            value = serialize(v, indent .. "  ")
        elseif type(v) == "string" then
            -- Escape special characters in strings
            local escaped = v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
            value = string.format('"%s"', escaped)
        elseif type(v) == "boolean" then
            value = tostring(v)
        elseif type(v) == "number" then
            value = tostring(v)
        else
            value = "nil"
        end
        
        result = result .. indent .. "  " .. key .. " = " .. value .. ",\n"
    end
    
    result = result .. indent .. "}"
    return result
end

-- Deep copy a value, skipping functions and references
local function deepCopy(value, seen)
    seen = seen or {}
    
    if type(value) ~= "table" then
        return value
    end
    
    if seen[value] then
        return nil  -- Skip circular references
    end
    
    seen[value] = true
    local copy = {}
    
    for k, v in pairs(value) do
        if type(v) ~= "function" then
            copy[k] = deepCopy(v, seen)
        end
    end
    
    return copy
end

-- Save game state to a file
function SaveLoad.save(filename, gameState)
    -- First, assign save indices to all nodes
    for i, node in ipairs(gameState.nodes) do
        node._saveIndex = i
    end
    
    local saveData = {
        version = 1,
        nodes = {},
        connections = {},
        playerMoney = gameState.playerMoney,
        camera = {
            x = gameState.camera.x,
            y = gameState.camera.y,
            zoom = gameState.camera.zoom
        },
        contracts = {
            available = deepCopy(gameState.contracts.available),
            active = deepCopy(gameState.contracts.active)
        },
        contractRefreshTimer = gameState.contractRefreshTimer,
        autoAcceptContracts = gameState.autoAcceptContracts
    }
    
    -- Serialize nodes (skip parent references and functions)
    for i, node in ipairs(gameState.nodes) do
        local nodeData = {}
        for k, v in pairs(node) do
            -- Skip parent rack references and functions
            if k ~= "parentRack" and k ~= "_saveIndex" and type(v) ~= "function" then
                if k == "contents" then
                    -- Store rack contents as indices
                    nodeData.contents = {}
                    for j, item in ipairs(v) do
                        table.insert(nodeData.contents, item._saveIndex)
                    end
                else
                    nodeData[k] = deepCopy(v)
                end
            end
        end
        nodeData._saveIndex = i
        table.insert(saveData.nodes, nodeData)
    end
    
    -- Serialize connections (use node indices)
    for _, conn in ipairs(gameState.connections) do
        local connData = {
            fromIndex = conn.from._saveIndex,
            toIndex = conn.to._saveIndex,
            type = conn.type,
            isRackInternal = conn.isRackInternal,
            automatic = conn.automatic
        }
        table.insert(saveData.connections, connData)
    end
    
    -- Clean up save indices from nodes
    for _, node in ipairs(gameState.nodes) do
        node._saveIndex = nil
    end
    
    -- Write to file
    local success, serialized = pcall(function()
        return "return " .. serialize(saveData)
    end)
    
    if not success then
        return false, "Failed to serialize: " .. tostring(serialized)
    end
    
    local writeSuccess, writeErr = love.filesystem.write(filename, serialized)
    
    if not writeSuccess then
        return false, "Failed to write save file: " .. tostring(writeErr)
    end
    
    return true
end

-- Load game state from a file
function SaveLoad.load(filename)
    -- Check if file exists
    local info = love.filesystem.getInfo(filename)
    if not info then
        return nil, "Save file not found"
    end
    
    -- Load and execute the save file
    local chunk, err = love.filesystem.load(filename)
    if not chunk then
        return nil, "Failed to load save file: " .. tostring(err)
    end
    
    local success, saveData = pcall(chunk)
    if not success then
        return nil, "Failed to parse save file: " .. tostring(saveData)
    end
    
    -- Verify version
    if not saveData.version or saveData.version ~= 1 then
        return nil, "Incompatible save file version"
    end
    
    -- Rebuild node references
    local nodesByIndex = {}
    for _, nodeData in ipairs(saveData.nodes) do
        nodesByIndex[nodeData._saveIndex] = nodeData
    end
    
    -- Restore parent rack references and contents
    for _, nodeData in ipairs(saveData.nodes) do
        if nodeData.contents then
            local actualContents = {}
            for _, idx in ipairs(nodeData.contents) do
                local item = nodesByIndex[idx]
                if item then
                    item.parentRack = nodeData
                    table.insert(actualContents, item)
                end
            end
            nodeData.contents = actualContents
        end
    end
    
    -- Restore connections with node references
    local connections = {}
    for _, connData in ipairs(saveData.connections) do
        local conn = {
            from = nodesByIndex[connData.fromIndex],
            to = nodesByIndex[connData.toIndex],
            type = connData.type,
            isRackInternal = connData.isRackInternal,
            automatic = connData.automatic
        }
        if connData.isRackInternal then
            -- Find the rack node
            for _, node in ipairs(saveData.nodes) do
                if node.category == "rack" and node.contents then
                    for _, item in ipairs(node.contents) do
                        if item == conn.to or item == conn.from then
                            conn.rack = node
                            break
                        end
                    end
                end
            end
        end
        table.insert(connections, conn)
    end
    
    -- Remove _saveIndex from all nodes
    for _, nodeData in ipairs(saveData.nodes) do
        nodeData._saveIndex = nil
    end
    
    return {
        nodes = saveData.nodes,
        connections = connections,
        playerMoney = saveData.playerMoney,
        camera = saveData.camera,
        contracts = saveData.contracts,
        contractRefreshTimer = saveData.contractRefreshTimer,
        autoAcceptContracts = saveData.autoAcceptContracts
    }
end

-- Get list of save files
function SaveLoad.getSaveFiles()
    local files = love.filesystem.getDirectoryItems("")
    local saves = {}
    
    for _, file in ipairs(files) do
        if file:match("%.sav$") then
            local info = love.filesystem.getInfo(file)
            table.insert(saves, {
                name = file,
                modtime = info.modtime,
                size = info.size
            })
        end
    end
    
    -- Sort by modification time (newest first)
    table.sort(saves, function(a, b) return a.modtime > b.modtime end)
    
    return saves
end

return SaveLoad
