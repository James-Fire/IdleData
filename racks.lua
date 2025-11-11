-- Rack Management System
-- Handles rack placement, validation, and internal connections

Racks = {}

-- Find rack at a given position
function Racks.getRackAtPosition(x, y, nodes)
    for _, node in ipairs(nodes) do
        if node.category == "rack" then
            local hw = require("hardware")
            local height = hw.getDisplayHeight("rack")
            if x >= node.x - node.width/2 and x <= node.x + node.width/2 and
               y >= node.y - height/2 and y <= node.y + height/2 then
                return node
            end
        end
    end
    return nil
end

-- Check if a node can be placed in a rack
function Racks.canPlaceInRack(variantId, rack)
    local hw = require("hardware")
    local placement = hw.getRackPlacement(variantId)
    local space = hw.getRackSpace(variantId)
    local variant = hw.getVariant(variantId)
    
    -- Check if variant is allowed in racks
    if placement == hw.RackPlacement.DISALLOWED then
        return false, "This hardware cannot be placed in a rack"
    end
    
    -- Check if expansion card requires a server in the rack
    if variant.requiresServer then
        local hasServer = false
        local server = nil
        for _, node in ipairs(rack.contents) do
            if node.category == "server" then
                hasServer = true
                server = node
                break
            end
        end
        if not hasServer then
            return false, "Expansion cards require at least one server in the rack"
        end
        
        -- Check if server has available expansion slots
        if server then
            local expansionCount = 0
            for _, node in ipairs(rack.contents) do
                if node.category == "expansion" then
                    expansionCount = expansionCount + 1
                end
            end
            local maxSlots = server.maxExpansionSlots or 4
            if expansionCount >= maxSlots then
                return false, "Server expansion slots full (" .. expansionCount .. "/" .. maxSlots .. ")"
            end
        end
    end
    
    -- Check if rack has enough space
    if rack.usedUnits + space > rack.maxUnits then
        return false, "Not enough rack space (" .. space .. " units needed, " .. 
                     (rack.maxUnits - rack.usedUnits) .. " available)"
    end
    
    return true, nil
end

-- Place a node in a rack
function Racks.placeInRack(node, rack)
    local hw = require("hardware")
    local space = hw.getRackSpace(node.variantId)
    
    node.parentRack = rack
    table.insert(rack.contents, node)
    rack.usedUnits = rack.usedUnits + space
    
    -- Position node inside rack visually (offset from rack center)
    local rackHeight = hw.getDisplayHeight("rack")
    local slotIndex = #rack.contents
    local yOffset = -rackHeight/2 + 20 + (slotIndex - 1) * 15
    node.x = rack.x
    node.y = rack.y + yOffset
end

-- Remove a node from its rack
function Racks.removeFromRack(node)
    if not node.parentRack then
        return
    end
    
    local rack = node.parentRack
    local hw = require("hardware")
    local space = hw.getRackSpace(node.variantId)
    
    -- Remove from rack contents
    for i, rackNode in ipairs(rack.contents) do
        if rackNode == node then
            table.remove(rack.contents, i)
            break
        end
    end
    
    rack.usedUnits = rack.usedUnits - space
    node.parentRack = nil
end

-- Update automatic internal rack connections
function Racks.updateRackConnections(rack, connections)
    -- Remove old internal connections for this rack
    for i = #connections, 1, -1 do
        if connections[i].isRackInternal and connections[i].rack == rack then
            table.remove(connections, i)
        end
    end
    
    -- Create automatic power connections from rack to all contents
    for _, node in ipairs(rack.contents) do
        if node.powerDraw then
            table.insert(connections, {
                from = rack,
                to = node,
                type = "power",
                isRackInternal = true,
                rack = rack,
                automatic = true
            })
        end
    end
    
    -- Find switches/routers in rack
    local networkDevices = {}
    for _, node in ipairs(rack.contents) do
        if node.category == "switch" or node.category == "router" then
            table.insert(networkDevices, node)
        end
    end
    
    -- Create automatic ethernet connections from network devices to other rack contents
    for _, netDevice in ipairs(networkDevices) do
        for _, node in ipairs(rack.contents) do
            if node ~= netDevice and node.category ~= "switch" and node.category ~= "router" then
                table.insert(connections, {
                    from = netDevice,
                    to = node,
                    type = "ethernet",
                    isRackInternal = true,
                    rack = rack,
                    automatic = true
                })
            end
        end
    end
end

-- Check if rack has a network device (switch or router)
function Racks.hasNetworkDevice(rack)
    for _, node in ipairs(rack.contents) do
        if node.category == "switch" or node.category == "router" then
            return true, node
        end
    end
    return false, nil
end

-- Get the network device in a rack (for external connections)
function Racks.getNetworkDevice(rack)
    for _, node in ipairs(rack.contents) do
        if node.category == "switch" or node.category == "router" then
            return node
        end
    end
    return nil
end

-- Validate connection involving racks
function Racks.validateConnection(from, to, connType)
    -- If connecting to a rack with ethernet/fiber, rack must have switch/router
    if from.category == "rack" and (connType == "ethernet" or connType == "fiber") then
        if not Racks.hasNetworkDevice(from) then
            return false, "Rack needs a switch or router for network connections"
        end
    end
    
    if to.category == "rack" and (connType == "ethernet" or connType == "fiber") then
        if not Racks.hasNetworkDevice(to) then
            return false, "Rack needs a switch or router for network connections"
        end
    end
    
    return true, nil
end

return Racks
