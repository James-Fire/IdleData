-- Contract System
-- This file contains all contract-related logic

Contracts = {}

-- Contract type definitions
Contracts.types = {
    compute = {
        name = "Compute Data",
        -- CPU Scaling parameters
        cpuPackets = {5, 20},  -- Scale packets with total cores
        
        CpuTimePerPacket = {10, 60},  -- seconds per packet
        
        gpuPackets= {5000, 15000},  -- GPU packets = CPU packets * this
		gpuTimePerPacket = {0.5, 3},
        
        minInputSize = 5,   -- GB
        maxInputSize = 50,  -- GB
        inputSizeStorageDivisor = 5,  -- avgStorage / this
        
        minOutputSize = 1,  -- GB
        maxOutputSize = 10, -- GB
        
        -- Context switching penalty
        contextSwitchDelay = 0.5,  -- seconds delay when switching between packets
        
        -- Payment calculation
        paymentInputMultiplier = 0.25,
        paymentTimeMultiplier = 0.5,
        
        -- Data transfer speeds
        DownloadSpeed = {50, 500},   -- Mbps
        UploadSpeed = {25, 250}     -- Mbps
    },
    
    store = {
        name = "Store Data",
        -- Scaling parameters
        StorePackets = {5, 10},
        PacketSize = {100, 1000},  -- GB
        
        StoreDuration = {1200, 6000},   -- seconds
        
        -- Payment calculation
        paymentStorageMultiplier = 0.3,
        paymentTimeMultiplier = 0.5,
        
        -- Data transfer speeds
        DownloadSpeed = {5, 10000},   -- Mbps
    }
}

-- Generate contracts based on available hardware
function Contracts.generate(count, nodes)
    local contracts = {}
    
    -- Calculate datacenter capacity
    local capacity = Contracts.calculateCapacity(nodes)
    
    -- Don't generate contracts if no infrastructure
    if not capacity.hasModem or capacity.serverCount == 0 then
        return contracts
    end
    
    for i = 1, count do
        local contractType = math.random() > 0.5 and "compute" or "store"
        local contract = Contracts.createContract(contractType, capacity)
        table.insert(contracts, contract)
    end
    
    return contracts
end

-- Calculate datacenter capacity
function Contracts.calculateCapacity(nodes)
    local capacity = {
        totalCpuCores = 0,
        totalCpuSpeed = 0,
        totalGpuCores = 0,
        totalGpuSpeed = 0,
        totalStorage = 0,
        hasModem = false,
        serverCount = 0,
        avgCpuCores = 0,
        avgCpuSpeed = 0,
        avgGpuCores = 0,
        avgGpuSpeed = 0,
        avgStorage = 0
    }
    
    for _, node in ipairs(nodes) do
        if node.category == "server" and node.powered then
            -- Calculate total CPU power from all CPU entries
            local nodeCpuCores = 0
            local nodeCpuSpeed = 0
            if node.cpus then
                for _, cpu in ipairs(node.cpus) do
                    nodeCpuCores = nodeCpuCores + cpu.cores
                    nodeCpuSpeed = nodeCpuSpeed + (cpu.cores * cpu.speed)  -- Weighted by cores
                end
            end
            
            -- Calculate total GPU power from all GPU entries
            local nodeGpuCores = 0
            local nodeGpuSpeed = 0
            if node.gpus then
                for _, gpu in ipairs(node.gpus) do
                    nodeGpuCores = nodeGpuCores + gpu.cores
                    nodeGpuSpeed = nodeGpuSpeed + (gpu.cores * gpu.speed)  -- Weighted by cores
                end
            end
            
            capacity.totalCpuCores = capacity.totalCpuCores + nodeCpuCores
            capacity.totalCpuSpeed = capacity.totalCpuSpeed + (nodeCpuCores > 0 and (nodeCpuSpeed / nodeCpuCores) or 0)
            capacity.totalGpuCores = capacity.totalGpuCores + nodeGpuCores
            capacity.totalGpuSpeed = capacity.totalGpuSpeed + (nodeGpuCores > 0 and (nodeGpuSpeed / nodeGpuCores) or 0)
            capacity.totalStorage = capacity.totalStorage + (node.ssdStorage + node.hddStorage)
            capacity.serverCount = capacity.serverCount + 1
        elseif node.category == "modem" and node.powered then
            capacity.hasModem = true
        end
    end
    
    if capacity.serverCount > 0 then
        capacity.avgCpuCores = capacity.totalCpuCores / capacity.serverCount
        capacity.avgCpuSpeed = capacity.totalCpuSpeed / capacity.serverCount
        capacity.avgGpuCores = capacity.totalGpuCores / capacity.serverCount
        capacity.avgGpuSpeed = capacity.totalGpuSpeed / capacity.serverCount
        capacity.avgStorage = capacity.totalStorage / capacity.serverCount
    end
    
    return capacity
end

-- Create a specific contract type
function Contracts.createContract(contractType, capacity)
    local spec = Contracts.types[contractType]
    
    if contractType == "compute" then
        -- Determine compute type based on available hardware
		local rand = math.random()
		local computeType = "cpu"
		if rand < 0.4 then
			computeType = "cpu"
		elseif rand < 0.8 then
			computeType = "gpu"
		else
			computeType = "both"
		end
		local cpuPackets = math.random(spec.cpuPackets[1],spec.cpuPackets[2])
		local cpuTimePerPacket = math.random(spec.CpuTimePerPacket[1],spec.CpuTimePerPacket[2])
		local gpuPackets = math.random(spec.gpuPackets[1],spec.gpuPackets[2])
		local gpuTimePerPacket = math.random(spec.gpuTimePerPacket[1],spec.gpuTimePerPacket[2])
        
        local contract = {
            id = math.random(10000, 99999),
            type = "compute",
            computeType = computeType,  -- "cpu", "gpu", or "both"
            name = "Compute Data",
            
            -- Separate CPU and GPU work
            cpuPackets = cpuPackets,
            cpuTimePerPacket = cpuTimePerPacket,
            cpuPacketsCompleted = 0,
            
            gpuPackets = gpuPackets,
            gpuPacketsCompleted = 0,
            gpuTimePerPacket = gpuTimePerPacket,
            
            -- Context switching state
            currentPacketProgress = 0,  -- Progress on current packet (0-1)
            contextSwitchTimer = 0,     -- Time spent in context switch
            isContextSwitching = false,
            
            packetSizeInput = math.random(spec.minInputSize, spec.maxInputSize),
            packetSizeOutput = math.random(spec.minOutputSize, spec.maxOutputSize),
            downloadSpeed = math.random(spec.DownloadSpeed[1],spec.DownloadSpeed[2]),
            uploadSpeed = math.random(spec.UploadSpeed[1],spec.UploadSpeed[2]),
            payment = 0,
            progress = 0,
            state = "available"
        }
        
        -- Calculate payment based on total work
        local totalWorkTime = (cpuPackets * cpuTimePerPacket) + (gpuPackets * gpuTimePerPacket)
        contract.payment = math.floor(
            (contract.packetSizeInput * spec.paymentInputMultiplier) + 
            (totalWorkTime * spec.paymentTimeMultiplier)
        )
        
        return contract
        
    elseif contractType == "store" then
        
        local contract = {
            id = math.random(10000, 99999),
            type = "store",
            name = "Store Data",
            packetCount = math.random(spec.StorePackets[1],spec.StorePackets[2]),
            packetSize = math.random(spec.PacketSize[1],spec.PacketSize[2]),
            storageDuration = math.random(spec.StoreDuration[1],spec.StoreDuration[2]),
            downloadSpeed = math.random(spec.DownloadSpeed[1],spec.DownloadSpeed[2]),
            totalPayment = 0,
            paymentPerSecond = 0,
            progress = 0,
            timeStored = 0,
            state = "available"
        }
        
        -- Calculate payment
		contract.storageDuration = contract.storageDuration*contract.packetCount
        contract.totalPayment = math.floor(
            (contract.packetCount * contract.packetSize * spec.paymentStorageMultiplier) + 
            (contract.storageDuration * spec.paymentTimeMultiplier)
        )
        contract.paymentPerSecond = contract.totalPayment / contract.storageDuration
        
        return contract
    end
end

-- Calculate actual transfer speed based on contract, modem, server limits, and bandwidth sharing
function Contracts.calculateTransferSpeed(contractSpeedMbps, nodes, activeContracts, currentContract)
    -- Find total modem speed
    local modemSpeedMbps = 0
    for _, node in ipairs(nodes) do
        if node.category == "modem" and node.powered then
            modemSpeedMbps = modemSpeedMbps + node.dataSpeed
        end
    end
    
    -- Find fastest server download speed (considering network card replacements)
    local serverDownloadMbps = 0
    for _, node in ipairs(nodes) do
        if node.category == "server" and node.powered then
            local bonuses = Hardware.calculateServerBonuses(node)
            local effectiveSpeed = bonuses.downloadSpeed > 0 and bonuses.downloadSpeed or (node.maxDownloadSpeed or 100)
            serverDownloadMbps = math.max(serverDownloadMbps, effectiveSpeed)
        end
    end
    
    -- Find switches and routers, and calculate bandwidth sharing
    local minSwitchSpeed = math.huge
    local minRouterSpeed = math.huge
    local hasSwitches = false
    local hasRouters = false
    
    for _, node in ipairs(nodes) do
        if node.powered then
            if node.category == "switch" then
                hasSwitches = true
                -- Count how many contracts are actively transferring
                local activeTransfers = 0
                for _, contract in ipairs(activeContracts) do
                    if contract.state == "downloading" or contract.state == "uploading" then
                        activeTransfers = activeTransfers + 1
                    end
                end
                
                -- Divide switch bandwidth by number of active transfers
                local sharedBandwidth = activeTransfers > 0 and (node.dataSpeed / activeTransfers) or node.dataSpeed
                minSwitchSpeed = math.min(minSwitchSpeed, sharedBandwidth)
            elseif node.category == "router" then
                hasRouters = true
                -- Count how many contracts are actively transferring
                local activeTransfers = 0
                for _, contract in ipairs(activeContracts) do
                    if contract.state == "downloading" or contract.state == "uploading" then
                        activeTransfers = activeTransfers + 1
                    end
                end
                
                -- Divide router bandwidth by number of active transfers
                local sharedBandwidth = activeTransfers > 0 and (node.dataSpeed / activeTransfers) or node.dataSpeed
                minRouterSpeed = math.min(minRouterSpeed, sharedBandwidth)
            end
        end
    end
    
    -- Use the slowest of: contract speed, modem, server, switches, routers
    if not hasSwitches then
		minSwitchSpeed = math.huge
    end
    local effectiveSpeedMbps = math.min(contractSpeedMbps,modemSpeedMbps,serverDownloadMbps,minRouterSpeed,minSwitchSpeed)
    
    -- Convert to progress % per second
    -- Assume 100% = total data transfer at contract's advertised speed
    -- So actual speed = (effectiveSpeed / contractSpeed) * baseProgressRate
    local speedRatio = (modemSpeedMbps > 0 and serverDownloadMbps > 0) and (effectiveSpeedMbps / contractSpeedMbps) or 0
    return speedRatio * 2  -- Base 2% per second at full speed
end

-- Auto-accept contracts that fit capacity
-- Break a contract into packets and add them to the work queue
function Contracts.addToWorkQueue(queue, contract, nodes, ContractTable)
    -- Accept the contract
	contract.state = "downloading"
	contract.progress = 0
	table.insert(contracts.active, contract)
	table.remove(contracts.available, ContractTable)
    if contract.type == "compute" then
        local spec = Contracts.types.compute
        
        -- Add CPU packets
        for i = 1, contract.cpuPackets do
            WorkQueue.addPacket(queue, contract.id, "cpu", contract.cpuTimePerPacket, 
                              contract.packetSizeInput / contract.cpuPackets,
                              contract.packetSizeOutput / contract.cpuPackets)
        end
        
        -- Add GPU packets (if any)
        for i = 1, contract.gpuPackets do
            WorkQueue.addPacket(queue, contract.id, "gpu", contract.gpuTimePerPacket,
                              contract.packetSizeInput / contract.gpuPackets,
                              contract.packetSizeOutput / contract.gpuPackets)
        end
        
    elseif contract.type == "store" then
        -- Add store packets
        local sizePerPacket = contract.packetSize
        for i = 1, contract.packetCount do
            WorkQueue.addPacket(queue, contract.id, "store", contract.storageDuration / contract.packetCount, sizePerPacket, sizePerPacket)
        end
    end
end

-- Auto-accept contracts that fit capacity
function Contracts.autoAccept(availableContracts, activeContracts, nodes)
    -- Calculate current usage
    local activeCpuCores = 0
    local activeGpuCores = 0
    local activeStorage = 0
    
    for _, contract in ipairs(activeContracts) do
        if contract.type == "compute" then
            activeCpuCores = activeCpuCores + (contract.cpuPackets or 0)
            activeGpuCores = activeGpuCores + (contract.gpuPackets or 0)
            activeStorage = activeStorage + contract.packetSizeInput
        elseif contract.type == "store" then
            activeStorage = activeStorage + (contract.packetSize * contract.packetCount)
        end
    end
    
    -- Get total capacity
    local capacity = Contracts.calculateCapacity(nodes)
    
    -- Try to accept contracts that fit (with 5% buffer)
    for i = #availableContracts, 1, -1 do
        local contract = availableContracts[i]
        local needsCpuCores = 0
        local needsGpuCores = 0
        local needsStorage = 0
        local needsBandwidth = 0
        
		if contract then
			needsBandwidth = contract.downloadSpeed
			if contract.type == "compute" then
				needsCpuCores = contract.cpuPackets or 0
				needsGpuCores = contract.gpuPackets or 0
				needsStorage = contract.packetSizeInput
			elseif contract.type == "store" then
				needsStorage = contract.packetSize * contract.packetCount
			end
	   
			if 
			   (activeCpuCores + needsCpuCores <= capacity.totalCpuCores * 0.95) and
			   (activeGpuCores + needsGpuCores <= capacity.totalGpuCores * 0.95) and
			   (activeStorage + needsStorage <= capacity.totalStorage * 0.95) then
				
				-- Add to work queue (queue manages tracking now)
				Contracts.addToWorkQueue(workQueue, contract, nodes)
				print("Auto-accepted contract " .. contract.name .. " with " .. workQueue.nextPacketId .. " packets added to queue")
				
				activeCpuCores = activeCpuCores + needsCpuCores
				activeGpuCores = activeGpuCores + needsGpuCores
				activeStorage = activeStorage + needsStorage
			end
		end
    end
end

return Contracts
