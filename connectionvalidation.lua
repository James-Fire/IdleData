-- Connection Validation
-- Handles all rules for valid connections between hardware nodes

local ConnectionValidation = {}

-- Count connections of a specific cable type for a node
function ConnectionValidation.countConnections(node, connections, cableType)
    local count = 0
    for _, conn in ipairs(connections) do
        if (conn.from == node or conn.to == node) and conn.type == cableType then
            count = count + 1
        end
    end
    return count
end

-- Count all ethernet and fiber connections separately
function ConnectionValidation.countPortUsage(node, connections)
    local ethernetCount = 0
    local fiberCount = 0
    
    for _, conn in ipairs(connections) do
        if conn.from == node or conn.to == node then
            if conn.type == "ethernet" then
                ethernetCount = ethernetCount + 1
            elseif conn.type == "fiber" then
                fiberCount = fiberCount + 1
            end
        end
    end
    
    return ethernetCount, fiberCount
end

-- Check if server has fiber capability
function ConnectionValidation.serverHasFiber(server)
    if not server.parentRack then
        return false
    end
    
    local Hardware = require("hardware")
    local bonuses = Hardware.calculateServerBonuses(server)
    return bonuses.hasFiber
end

-- Validate connection between two nodes
function ConnectionValidation.validate(from, to, cableType, connections)
    local Cables = require("cables")
    local Hardware = require("hardware")
    
    local cable = Cables.getVariant(cableType)
    if not cable then
        return false, "Unknown cable type: " .. tostring(cableType)
    end
    
    -- Check if it's a network or power cable
    local isNetwork = Cables.isNetworkCable(cableType)
    local isPower = Cables.isPowerCable(cableType)
    
    -- POWER CABLE RULES
    if isPower then
        if cableType == "power" then
            -- Normal power cables (20W limit)
            -- Can connect: rack <-> PSU, power_distributor <-> devices
            -- CANNOT connect to PSU anymore (need highVoltage)
            if from.category == "psu" or to.category == "psu" then
                return false, "PSU requires high voltage cable"
            end
            
            if from.category == "power_distributor" or to.category == "power_distributor" then
                -- Allow power distributor to connect to most devices
                return true, nil
            end
            
            -- Allow rack to devices (legacy power connections)
            if from.category == "rack" or to.category == "rack" then
                return true, nil
            end
            
        elseif cableType == "highVoltage" then
            -- High voltage cables (100W limit)
            -- Can connect: PSU <-> power_distributor, power_distributor <-> power_distributor
            local validFrom = (from.category == "psu" or from.category == "power_distributor")
            local validTo = (to.category == "psu" or to.category == "power_distributor")
            
            if not (validFrom and validTo) then
                return false, "High voltage cables only connect PSU and Power Distributors"
            end
            
            return true, nil
        end
    end
    
    -- NETWORK CABLE RULES
    if isNetwork then
        -- Check port limits
        local fromEthernet, fromFiber = ConnectionValidation.countPortUsage(from, connections)
        local toEthernet, toFiber = ConnectionValidation.countPortUsage(to, connections)
        
        if cableType == "ethernet" then
            -- Check ethernet port limits
            if from.maxEthernetPorts and fromEthernet >= from.maxEthernetPorts then
                return false, from.name .. " ethernet ports full (" .. fromEthernet .. "/" .. from.maxEthernetPorts .. ")"
            end
            if to.maxEthernetPorts and toEthernet >= to.maxEthernetPorts then
                return false, to.name .. " ethernet ports full (" .. toEthernet .. "/" .. to.maxEthernetPorts .. ")"
            end
            
            -- MODEM RESTRICTIONS
            if from.category == "modem" then
                -- Modem cannot connect to switch
                if to.category == "switch" then
                    return false, "Modems cannot connect to switches (use router)"
                end
            end
            if to.category == "modem" then
                if from.category == "switch" then
                    return false, "Modems cannot connect to switches (use router)"
                end
            end
            
        elseif cableType == "fiber" then
            -- Check fiber port limits
            if from.maxFiberPorts and fromFiber >= from.maxFiberPorts then
                return false, from.name .. " fiber ports full (" .. fromFiber .. "/" .. from.maxFiberPorts .. ")"
            end
            if to.maxFiberPorts and toFiber >= to.maxFiberPorts then
                return false, to.name .. " fiber ports full (" .. toFiber .. "/" .. to.maxFiberPorts .. ")"
            end
            
            -- MODEM RESTRICTIONS  
            if from.category == "modem" then
                if to.category == "switch" then
                    return false, "Modems cannot connect to switches (use router)"
                end
            end
            if to.category == "modem" then
                if from.category == "switch" then
                    return false, "Modems cannot connect to switches (use router)"
                end
            end
            
            -- SERVER FIBER RESTRICTIONS
            if from.category == "server" then
                if not ConnectionValidation.serverHasFiber(from) then
                    return false, from.name .. " needs fiber expansion card"
                end
            end
            if to.category == "server" then
                if not ConnectionValidation.serverHasFiber(to) then
                    return false, to.name .. " needs fiber expansion card"
                end
            end
        end
        
        -- ROUTER-TO-ROUTER RESTRICTIONS
        if from.category == "router" and to.category == "router" then
            -- Routers can only connect to each other through a modem
            return false, "Routers cannot connect directly to each other"
        end
        
        -- Check if network segment would have multiple routers (TODO: implement network traversal)
        -- This is complex and requires graph traversal, skipping for now
        
        return true, nil
    end
    
    -- Rack validation (handled by Racks module)
    local Racks = require("racks")
    return Racks.validateConnection(from, to, cableType)
end

return ConnectionValidation
