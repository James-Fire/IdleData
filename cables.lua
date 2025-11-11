-- Cable/Connection Type Definitions
-- This file contains all cable/connection specifications

Cables = {}

-- Cable variants - each type has different properties
Cables.variants = {
    ethernet = {
        id = "ethernet",
        displayName = "Ethernet Cable",
        category = "network",
        speedLimit = 100,  -- Mbps
        color = {0.3, 0.6, 0.9},
        lineWidth = 2,
        hotkey = "4"
    },
    
    fiber = {
        id = "fiber",
        displayName = "Fiber Cable",
        category = "network",
        speedLimit = 1000,  -- Mbps
        color = {0.9, 0.4, 0.2},
        lineWidth = 3,
        hotkey = "4"
    },
    
    power = {
        id = "power",
        displayName = "Power Cable",
        category = "power",
        powerLimit = 20,  -- Watts
        color = {0.9, 0.9, 0.2},
        lineWidth = 2,
        hotkey = "5"
    },
    
    highVoltage = {
        id = "highVoltage",
        displayName = "High Voltage Cable",
        category = "power",
        powerLimit = 100,  -- Watts
        color = {0.9, 0.2, 0.2},
        lineWidth = 4,
        hotkey = "5"
    }
}

-- List of cable types for cycling through placement options
Cables.cableTypes = {"ethernet", "fiber", "power", "highVoltage"}

-- Get cable variant info
function Cables.getVariant(cableId)
    return Cables.variants[cableId]
end

-- Get color for a cable type
function Cables.getColor(cableId)
    local variant = Cables.variants[cableId]
    return variant and variant.color or {0.5, 0.5, 0.5}
end

-- Get line width for a cable type
function Cables.getLineWidth(cableId)
    local variant = Cables.variants[cableId]
    return variant and variant.lineWidth or 2
end

-- Check if cable type is network cable
function Cables.isNetworkCable(cableId)
    local variant = Cables.variants[cableId]
    return variant and variant.category == "network"
end

-- Check if cable type is power cable
function Cables.isPowerCable(cableId)
    local variant = Cables.variants[cableId]
    return variant and variant.category == "power"
end

return Cables
