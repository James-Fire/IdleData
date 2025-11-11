-- Work Queue System
-- Manages packets from all contracts at a central level
-- Servers pull packets from the queue and process them

WorkQueue = {}

-- Create a new work queue
function WorkQueue.create()
    return {
        packets = {},        -- All pending packets
        nextPacketId = 1
    }
end

-- Add a packet to the work queue
function WorkQueue.addPacket(workQueue, contractId, packetType, computeTime, inputSize, outputSize)
    local packet = {
        id = workQueue.nextPacketId,
        contractId = contractId,
        type = packetType,  -- "cpu", "gpu", or "store"
        computeTime = computeTime,  -- Time to process (seconds)
        inputSize = inputSize,      -- GB to download
        outputSize = outputSize,    -- GB to upload
        state = "pending",          -- "pending", "downloading", "processing", "uploading", "complete"
        downloadProgress = 0,       -- 0-1
        processingProgress = 0,     -- 0-1
        uploadProgress = 0,         -- 0-1
        assignedServer = nil,       -- Which server is working on this packet
    }
    table.insert(workQueue.packets, packet)
    workQueue.nextPacketId = workQueue.nextPacketId + 1
    return packet
end

-- Get pending packets for a server to download
-- Returns up to (serverCores * 2) packets that the server has storage for
function WorkQueue.getPacketsForDownload(workQueue, serverId, serverCores, availableStorage, nodes)
    local pendingPackets = {}
    local maxPackets = serverCores * 2  -- Can hold 2x cores in memory
    local totalDownloadSize = 0
    
    -- Find all packets already assigned to this server
    local alreadyAssigned = 0
    for _, packet in ipairs(workQueue.packets) do
        if packet.assignedServer == serverId and (packet.state == "downloading" or packet.state == "processing" or packet.state == "uploading") then
            alreadyAssigned = alreadyAssigned + 1
            totalDownloadSize = totalDownloadSize + packet.inputSize
        end
    end
    
    -- Add more packets if under capacity
    if alreadyAssigned < maxPackets then
        for _, packet in ipairs(workQueue.packets) do
            if packet.state == "pending" and #pendingPackets < (maxPackets - alreadyAssigned) then
                -- Check if server has storage space
                if totalDownloadSize + packet.inputSize <= availableStorage then
                    table.insert(pendingPackets, packet)
                    totalDownloadSize = totalDownloadSize + packet.inputSize
                    packet.assignedServer = serverId
                    packet.state = "downloading"
                end
            end
        end
    end
    
    return pendingPackets
end

-- Get packets ready for processing on a server
function WorkQueue.getPacketsForProcessing(workQueue, serverId)
    local processingPackets = {}
    for _, packet in ipairs(workQueue.packets) do
        if packet.assignedServer == serverId and packet.state == "processing" then
            table.insert(processingPackets, packet)
        end
    end
    return processingPackets
end

-- Move a packet from downloading to processing state
function WorkQueue.markPacketDownloaded(workQueue, packetId)
    for _, packet in ipairs(workQueue.packets) do
        if packet.id == packetId then
            packet.state = "processing"
            packet.downloadProgress = 1
            packet.processingProgress = 0
            return true
        end
    end
    return false
end

-- Update packet processing progress
function WorkQueue.updatePacketProcessing(workQueue, packetId, deltaTime, computeSpeed)
    for _, packet in ipairs(workQueue.packets) do
        if packet.id == packetId and packet.state == "processing" then
            packet.processingProgress = packet.processingProgress + (deltaTime / packet.computeTime) * computeSpeed
            if packet.processingProgress >= 1 then
                packet.processingProgress = 1
                if packet.type == "store" then
                    -- Store packets don't upload; mark complete after processing
                    packet.state = "complete"
                    return true  -- Packet finished processing and is complete
                else
                    packet.state = "uploading"
                    packet.uploadProgress = 0
                    return true  -- Packet finished processing
                end
            end
            return false
        end
    end
    return false
end

-- Update packet upload progress
function WorkQueue.updatePacketUpload(workQueue, packetId, deltaTime, uploadSpeed)
    for _, packet in ipairs(workQueue.packets) do
        if packet.id == packetId and packet.state == "uploading" then
            packet.uploadProgress = packet.uploadProgress + deltaTime * uploadSpeed
            if packet.uploadProgress >= 1 then
                packet.uploadProgress = 1
                packet.state = "complete"
                return true  -- Packet finished uploading
            end
            return false
        end
    end
    return false
end

-- Get completion status of a contract's packets
function WorkQueue.getContractProgress(workQueue, contractId)
    local total = 0
    local completed = 0
    local downloading = 0
    local processing = 0
    local uploading = 0
    
    for _, packet in ipairs(workQueue.packets) do
        if packet.contractId == contractId then
            total = total + 1
            if packet.state == "complete" then
                completed = completed + 1
            elseif packet.state == "downloading" then
                downloading = downloading + 1
            elseif packet.state == "processing" then
                processing = processing + 1
            elseif packet.state == "uploading" then
                uploading = uploading + 1
            end
        end
    end
    
    return {
        total = total,
        completed = completed,
        downloading = downloading,
        processing = processing,
        uploading = uploading,
        progress = total > 0 and (completed / total * 100) or 0
    }
end

-- Check if all packets for a contract are complete
function WorkQueue.isContractComplete(workQueue, contractId)
    local status = WorkQueue.getContractProgress(workQueue, contractId)
    return status.total > 0 and status.completed == status.total
end

-- Remove completed packets for a contract from the queue
function WorkQueue.removeContractPackets(workQueue, contractId)
    for i = #workQueue.packets, 1, -1 do
        if workQueue.packets[i].contractId == contractId then
            table.remove(workQueue.packets, i)
        end
    end
end

return WorkQueue
