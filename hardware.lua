-- Hardware Definitions
-- This file contains all hardware node specifications

-- Define all hardware types and their properties
Hardware = {}

-- Rack placement modes
Hardware.RackPlacement = {
    REQUIRED = "required",    -- Must be placed in a rack
    ALLOWED = "allowed",      -- Can be placed in rack or freely
    DISALLOWED = "disallowed" -- Cannot be placed in rack
}

-- Hardware variants - each category can have multiple models
Hardware.variants = {
    -- Racks
    rack = {
        id = "rack",
        displayName = "Server Rack",
        category = "rack",
        maxUnits = 7,
        displayHeight = 120,
        color = {0.25, 0.25, 0.3},
        rackPlacement = Hardware.RackPlacement.DISALLOWED,
        rackSpace = 0,
        purchaseCost = 200,
        hotkey = "2"
    },
    
    -- Servers
    server_basic = {
        id = "server_basic",
        displayName = "Basic Server",
        category = "server",
        powerDraw = 5,
        cpus = {{cores = 8, speed = 1.0}},  -- Array of CPU entries
        gpus = {},  -- Array of GPU entries (empty by default)
        ssdStorage = 1000.0,
        hddStorage = 4000.0,
        maxDownloadSpeed = 100,  -- Mbps
        maxExpansionSlots = 4,
        displayHeight = 80,
        color = {0.3, 0.7, 0.4},
        rackPlacement = Hardware.RackPlacement.REQUIRED,
        rackSpace = 2,
        purchaseCost = 300,
        hotkey = "3"
    },
    
    -- Expansion Cards (sub-server hardware that augments servers)
    expansion_cpu = {
        id = "expansion_cpu",
        displayName = "CPU Expansion",
        category = "expansion",
        powerDraw = 2,
        addCpu = {cores = 8, speed = 1.0},  -- Adds a CPU entry to server
        displayHeight = 60,
        color = {0.8, 0.4, 0.6},
        rackPlacement = Hardware.RackPlacement.REQUIRED,
        rackSpace = 1,
        purchaseCost = 100,
        hotkey = "3",
        requiresServer = true
    },
    
    expansion_storage = {
        id = "expansion_storage",
        displayName = "Storage Expansion",
        category = "expansion",
        powerDraw = 1,
        addSsdStorage = 2000.0,
        addHddStorage = 8000.0,
        displayHeight = 60,
        color = {0.6, 0.5, 0.8},
        rackPlacement = Hardware.RackPlacement.REQUIRED,
        rackSpace = 1,
        purchaseCost = 50,
        hotkey = "3",
        requiresServer = true
    },
    
    expansion_gpu = {
        id = "expansion_gpu",
        displayName = "GPU Expansion",
        category = "expansion",
        powerDraw = 8,
        addGpu = {cores = 500, speed = 0.1},  -- Adds a GPU entry to server
        displayHeight = 60,
        color = {0.9, 0.5, 0.3},
        rackPlacement = Hardware.RackPlacement.REQUIRED,
        rackSpace = 1,
        purchaseCost = 200,
        hotkey = "3",
        requiresServer = true
    },
    
    expansion_fiber = {
        id = "expansion_fiber",
        displayName = "Fiber Card",
        category = "expansion",
        powerDraw = 1,
        enablesFiber = true,  -- Allows server to use fiber connections
        replaceDownloadSpeed = 1000,  -- Mbps - replaces server's download speed
        displayHeight = 60,
        color = {0.9, 0.4, 0.2},
        rackPlacement = Hardware.RackPlacement.REQUIRED,
        rackSpace = 1,
        purchaseCost = 150,
        hotkey = "3",
        requiresServer = true
    },
    
    -- Switches
    switch_1gb = {
        id = "switch_1gb",
        displayName = "1Gb Switch",
        category = "switch",
        powerDraw = 1,
        dataSpeed = 1000,
        maxEthernetPorts = 8,
        maxFiberPorts = 1,
        ethernetBandwidth = 100,  -- Mbps per port
        fiberBandwidth = 1000,    -- Mbps per port
        displayHeight = 60,
        color = {0.4, 0.5, 0.9},
        rackPlacement = Hardware.RackPlacement.REQUIRED,
        rackSpace = 1,
        purchaseCost = 150,
        hotkey = "4"
    },
    
    -- Routers
    router_1gb = {
        id = "router_1gb",
        displayName = "1Gb Router",
        category = "router",
        powerDraw = 1,
        dataSpeed = 1000,
        maxEthernetPorts = 4,
        maxFiberPorts = 4,
        ethernetBandwidth = 100,  -- Mbps per port
        fiberBandwidth = 1000,    -- Mbps per port
        displayHeight = 60,
        color = {0.9, 0.6, 0.3},
        rackPlacement = Hardware.RackPlacement.REQUIRED,
        rackSpace = 1,
        purchaseCost = 250,
        hotkey = "4"
    },
    
    -- Modems
    modem_100mb = {
        id = "modem_100mb",
        displayName = "100Mb Modem",
        category = "modem",
        powerDraw = 1,
        dataSpeed = 100,
        maxEthernetPorts = 1,
        maxFiberPorts = 1,
        displayHeight = 60,
        color = {0.5, 0.9, 0.9},
        rackPlacement = Hardware.RackPlacement.DISALLOWED,
        rackSpace = 0,
        purchaseCost = 80,
        hotkey = "4",
        internetCostPerSecond = 0.01  -- $0.01/sec = $0.6/min = $36/hr = $864/day
    },
    
    -- PSUs
    psu_20w = {
        id = "psu_20w",
        displayName = "20W PSU",
        category = "psu",
        powerCapacity = 20,
        displayHeight = 60,
        color = {0.9, 0.85, 0.2},
        rackPlacement = Hardware.RackPlacement.DISALLOWED,
        rackSpace = 0,
        purchaseCost = 50,
        hotkey = "5",
        powerCostPerWattSecond = 0.0001  -- $0.0001 per watt-second = $0.36/hr for 1000W
    },
    
    -- Power Distribution
    power_distributor = {
        id = "power_distributor",
        displayName = "Power Distributor",
        category = "power_distributor",
        powerCapacity = 100,  -- Can distribute up to 100W
        displayHeight = 60,
        color = {0.7, 0.2, 0.2},
        rackPlacement = Hardware.RackPlacement.DISALLOWED,
        rackSpace = 0,
        purchaseCost = 50,
        hotkey = "5"
    },
}

-- Lists of variant IDs for cycling through placement options
Hardware.hardwareVariants = {"server_basic", "expansion_cpu", "expansion_gpu", "expansion_network", "expansion_fiber", "expansion_storage", "psu_20w", "power_distributor"}  -- Basic hardware on key [2]
Hardware.networkVariants = {"switch_1gb", "router_1gb", "modem_100mb"}  -- Network hardware on key [3]
Hardware.rackVariant = "rack"  -- Racks on key [4]

-- Create a new hardware node from a variant
function Hardware.createNode(variantId, x, y, nodeCount)
    local variant = Hardware.variants[variantId]
    if not variant then
        error("Unknown hardware variant: " .. variantId)
    end
    
    local node = {
        id = (nodeCount + 1),
        variantId = variantId,
        category = variant.category,
        name = variant.displayName .. " #" .. (nodeCount + 1),
        x = x,
        y = y,
        width = 100,
        height = 60
    }
    
    -- Apply specifications based on category
    if variant.category == "rack" then
        node.maxUnits = variant.maxUnits
        node.usedUnits = 0
        node.contents = {}
        node.powered = false
        node.parentRack = nil
    elseif variant.category == "server" then
        node.powerDraw = variant.powerDraw
        node.powered = false
        -- Deep copy CPU array
        node.cpus = {}
        if variant.cpus then
            for _, cpu in ipairs(variant.cpus) do
                table.insert(node.cpus, {cores = cpu.cores, speed = cpu.speed})
            end
        end
        -- Deep copy GPU array
        node.gpus = {}
        if variant.gpus then
            for _, gpu in ipairs(variant.gpus) do
                table.insert(node.gpus, {cores = gpu.cores, speed = gpu.speed})
            end
        end
        node.ssdStorage = variant.ssdStorage
        node.hddStorage = variant.hddStorage
        node.storedBytes = 0
        node.maxDownloadSpeed = variant.maxDownloadSpeed or 100
        node.maxExpansionSlots = variant.maxExpansionSlots or 4
        node.parentRack = nil
    elseif variant.category == "switch" or variant.category == "router" or variant.category == "modem" then
        node.powerDraw = variant.powerDraw
        node.powered = false
        node.dataSpeed = variant.dataSpeed
        node.maxEthernetPorts = variant.maxEthernetPorts or 0
        node.maxFiberPorts = variant.maxFiberPorts or 0
        node.ethernetBandwidth = variant.ethernetBandwidth or 100
        node.fiberBandwidth = variant.fiberBandwidth or 1000
        node.parentRack = nil
    elseif variant.category == "psu" then
        node.powerCapacity = variant.powerCapacity
        node.powerUsed = 0
    elseif variant.category == "power_distributor" then
        node.powerCapacity = variant.powerCapacity
        node.powerUsed = 0
    elseif variant.category == "expansion" then
        node.powerDraw = variant.powerDraw
        node.powered = false
        node.parentRack = nil
        -- Store expansion bonuses
        if variant.addCpu then
            node.addCpu = {cores = variant.addCpu.cores, speed = variant.addCpu.speed}
        end
        if variant.addGpu then
            node.addGpu = {cores = variant.addGpu.cores, speed = variant.addGpu.speed}
        end
        node.addSsdStorage = variant.addSsdStorage or 0
        node.addHddStorage = variant.addHddStorage or 0
        node.replaceDownloadSpeed = variant.replaceDownloadSpeed or 0
        node.enablesFiber = variant.enablesFiber or false
    end
    
    return node
end

-- Get display height for a variant or node
function Hardware.getDisplayHeight(variantIdOrNode)
    local variantId = type(variantIdOrNode) == "table" and variantIdOrNode.variantId or variantIdOrNode
    local variant = Hardware.variants[variantId]
    return variant and variant.displayHeight or 60
end

-- Get color for a variant or node
function Hardware.getColor(variantIdOrNode)
    local variantId = type(variantIdOrNode) == "table" and variantIdOrNode.variantId or variantIdOrNode
    local variant = Hardware.variants[variantId]
    return variant and variant.color or {0.5, 0.5, 0.5}
end

-- Get rack placement mode for a variant
function Hardware.getRackPlacement(variantId)
    local variant = Hardware.variants[variantId]
    return variant and variant.rackPlacement or Hardware.RackPlacement.DISALLOWED
end

-- Get rack space required for a variant
function Hardware.getRackSpace(variantId)
    local variant = Hardware.variants[variantId]
    return variant and variant.rackSpace or 0
end

-- Get variant info
function Hardware.getVariant(variantId)
    return Hardware.variants[variantId]
end

-- Calculate bonuses for a server from expansion cards in the same rack
function Hardware.calculateServerBonuses(server)
    if not server.parentRack then
        return {addedCpus = {}, addedGpus = {}, ssdStorage = 0, hddStorage = 0, downloadSpeed = 0, hasFiber = false, usedSlots = 0}
    end
    
    local bonuses = {addedCpus = {}, addedGpus = {}, ssdStorage = 0, hddStorage = 0, downloadSpeed = 0, hasFiber = false, usedSlots = 0}
    local maxSlots = server.maxExpansionSlots or 4
    
    -- Sum bonuses from powered expansion cards in the rack, respecting slot limit
    for _, node in ipairs(server.parentRack.contents) do
        if node.category == "expansion" and node.powered then
            if bonuses.usedSlots < maxSlots then
                -- Add CPU entry if expansion provides one
                if node.addCpu then
                    table.insert(bonuses.addedCpus, {cores = node.addCpu.cores, speed = node.addCpu.speed})
                end
                -- Add GPU entry if expansion provides one
                if node.addGpu then
                    table.insert(bonuses.addedGpus, {cores = node.addGpu.cores, speed = node.addGpu.speed})
                end
                bonuses.ssdStorage = bonuses.ssdStorage + (node.addSsdStorage or 0)
                bonuses.hddStorage = bonuses.hddStorage + (node.addHddStorage or 0)
                -- Replace download speed (use highest if multiple network cards)
                if node.replaceDownloadSpeed and node.replaceDownloadSpeed > 0 then
                    bonuses.downloadSpeed = math.max(bonuses.downloadSpeed, node.replaceDownloadSpeed)
                end
                -- Enable fiber if any expansion provides it
                if node.enablesFiber then
                    bonuses.hasFiber = true
                end
                bonuses.usedSlots = bonuses.usedSlots + 1
            end
        end
    end
    
    return bonuses
end

return Hardware
