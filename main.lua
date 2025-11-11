-- Datacenter Simulator
-- A node-based editor for designing datacenter layouts

-- Load hardware definitions
Hardware = require("hardware")
Contracts = require("contracts")
Racks = require("racks")
SaveLoad = require("saveload")
Cables = require("cables")
ConnectionValidation = require("connectionvalidation")
WorkQueue = require("workqueue")
Draw = require("draw")

function love.load()
    -- Camera system
    camera = {
        x = 0,
        y = 0,
        zoom = 1,
        speed = 400
    }
    
    -- Mouse state
    mouse = {
        worldX = 0,
        worldY = 0,
        dragging = false,
        dragStartX = 0,
        dragStartY = 0,
        dragStartCamX = 0,
        dragStartCamY = 0
    }
    
    -- Hardware nodes
    nodes = {}
    selectedNode = nil
    draggingNode = false
    placementTargetRack = nil  -- Rack being hovered over during placement
    
    -- Current tool/mode
    currentTool = "select" -- "select", "place_2", "place_3", etc., "connect_cable"
    
    -- Build hotkey mappings from hardware and cable definitions
    hotkeyMappings = {}
    
    -- Add all hardware variants
    for variantId, variant in pairs(Hardware.variants) do
        if variant.hotkey then
            if not hotkeyMappings[variant.hotkey] then
                hotkeyMappings[variant.hotkey] = {type = "hardware", items = {}}
            end
            table.insert(hotkeyMappings[variant.hotkey].items, {id = variantId, source = "hardware"})
        end
    end
    
    -- Add all cable variants
    for cableId, cable in pairs(Cables.variants) do
        if cable.hotkey then
            if not hotkeyMappings[cable.hotkey] then
                hotkeyMappings[cable.hotkey] = {type = "cable", items = {}}
            end
            table.insert(hotkeyMappings[cable.hotkey].items, {id = cableId, source = "cable"})
        end
    end
    
    -- Current indices for each hotkey (auto-initialize based on discovered hotkeys)
    currentHotkeyIndices = {}
    for hotkey, _ in pairs(hotkeyMappings) do
        currentHotkeyIndices[hotkey] = 1
    end
    
    -- Legacy connection cycling (now replaced by hotkey system)
    connectionTypes = Cables.cableTypes
    currentConnectionTypeIndex = 1
    
    -- Connections between nodes
    connections = {}
    connectingFrom = nil -- Node we're connecting from
    
    -- Connection type colors (now handled by Cables module)
    -- Kept for backwards compatibility, but Cables.getColor() should be used
    connectionColors = {
        ethernet = Cables.getColor("ethernet"),
        fiber = Cables.getColor("fiber"),
        power = Cables.getColor("power"),
        highVoltage = Cables.getColor("highVoltage")
    }
    
    -- Window settings
    love.window.setTitle("Datacenter Simulator")
    
    -- Grid settings
    gridSize = 50
    showGrid = true
    
    -- Contracts system
    contracts = {
        available = {},
        active = {}
    }
    
    -- Work queue system
    workQueue = WorkQueue.create()
    showContractsScreen = false
    selectedContract = nil
    contractsScrollOffset = 0
    activeContractsScrollOffset = 0
    
    -- Save/Load menu
    showSaveLoadMenu = false
    saveLoadMenuTab = "load"  -- "save" or "load"
    saveLoadScrollOffset = 0
    saveFilename = ""
    
    -- Contract refresh timer
    contractRefreshTimer = 840 -- Start at 14 minutes (so first refresh is at 2 min)
    contractRefreshInterval = 900 -- 15 minutes in seconds
    
    -- Auto-accept contracts
    autoAcceptContracts = false
    
    -- Player money
    playerMoney = 5000
    
    -- Time speed control
    timeSpeed = 1  -- 1x speed, 0 = paused
    timeSpeedOptions = {1, 2, 5, 10, 100, 1000}
    timeSpeedIndex = 1
    isPaused = false
    speedBeforePause = 1  -- Remember speed when pausing
    
    -- Clipboard system
    clipboard = {
        nodes = {},  -- Copied nodes
        connections = {},  -- Connections between copied nodes and to external nodes
        centerX = 0,  -- Center point of copied selection
        centerY = 0
    }
    boxSelecting = false
    boxSelectStart = {x = 0, y = 0}
    boxSelectEnd = {x = 0, y = 0}
    pasteMode = false
    copyMode = false
    
    -- Generate initial contracts
    local generated = Contracts.generate(5, nodes)
    for _, contract in ipairs(generated) do
        table.insert(contracts.available, contract)
    end
end

function love.update(dt)
    -- Update mouse world position
    local mx, my = love.mouse.getPosition()
    mouse.worldX = (mx / camera.zoom) + camera.x
    mouse.worldY = (my / camera.zoom) + camera.y
    
    -- Always update camera regardless of pause state
    updateCamera(dt)
    
    -- Skip game logic if paused
    if isPaused then
        return
    end
    
    -- Apply time speed multiplier
    local adjustedDt = dt
    if timeSpeed > 0 then
        adjustedDt = dt * timeSpeed
    else
        -- Unlimited speed: run update multiple times per frame for better performance
        for i = 1, 1000 do
            updateGameLogic(dt)
        end
        return
    end
    
    updateGameLogic(adjustedDt)
end

function updateGameLogic(dt)
    -- Update power consumption for all nodes
    updatePowerConsumption()
    
    -- Calculate and deduct power costs
    local totalPowerCost = 0
    for _, node in ipairs(nodes) do
        if node.category == "psu" and node.powerUsed and node.powerUsed > 0 then
            local variant = Hardware.getVariant(node.variantId)
            if variant and variant.powerCostPerWattSecond then
                totalPowerCost = totalPowerCost + (node.powerUsed * variant.powerCostPerWattSecond * dt)
            end
        end
    end
    
    -- Calculate and deduct internet costs
    local totalInternetCost = 0
    for _, node in ipairs(nodes) do
        if node.category == "modem" and node.powered then
            local variant = Hardware.getVariant(node.variantId)
            if variant and variant.internetCostPerSecond then
                totalInternetCost = totalInternetCost + (variant.internetCostPerSecond * dt)
            end
        end
    end
    
    -- Deduct total costs
    playerMoney = playerMoney - totalPowerCost - totalInternetCost
    
    -- Update work queue and server packet processing
    updateServerPacketProcessing(dt)
    
    -- Update active contracts based on work queue progress
    updateContractProgress(dt)
    
    -- Update contract refresh timer
    contractRefreshTimer = contractRefreshTimer + dt
    if contractRefreshTimer >= contractRefreshInterval then
        contractRefreshTimer = 0
        contracts.available = {}
        local generated = Contracts.generate(5, nodes)
        for _, contract in ipairs(generated) do
            table.insert(contracts.available, contract)
        end
        
        -- Auto-accept contracts if enabled
        if autoAcceptContracts then
            Contracts.autoAccept(contracts.available, contracts.active, nodes)
        end
    end
end

function updateCamera(dt)
    -- Camera movement with arrow keys
    if love.keyboard.isDown("right") then
        camera.x = camera.x + camera.speed * dt / camera.zoom
    end
    if love.keyboard.isDown("left") then
        camera.x = camera.x - camera.speed * dt / camera.zoom
    end
    if love.keyboard.isDown("down") then
        camera.y = camera.y + camera.speed * dt / camera.zoom
    end
    if love.keyboard.isDown("up") then
        camera.y = camera.y - camera.speed * dt / camera.zoom
    end
    
    -- Middle mouse drag for camera pan
    if mouse.dragging and not draggingNode and mouse.dragStartCamX and mouse.dragStartCamY then
        local mx, my = love.mouse.getPosition()
        camera.x = mouse.dragStartCamX - ((mx - mouse.dragStartX) / camera.zoom)
        camera.y = mouse.dragStartCamY - ((my - mouse.dragStartY) / camera.zoom)
    end
end
-- Update packet processing for all servers
function updateServerPacketProcessing(dt)
    -- Ensure nodes have IDs for packet assignment
    for i, n in ipairs(nodes) do
        if not n.id then n.id = i end
    end
    -- Debug: Print work queue status periodically
    if math.random() < 0.01 then  -- Very rarely (about 1% chance per frame)
        print("Work Queue Status: " .. #workQueue.packets .. " packets total")
    end
    
    -- First, each server downloads new packets if needed
    for _, node in ipairs(nodes) do
        if node.category == "server" and node.powered then
            -- Calculate server capacity
            local serverCores = 0
            if node.cpus then
                for _, cpu in ipairs(node.cpus) do
                    serverCores = serverCores + cpu.cores
                end
            end
            
            if serverCores > 0 then
                -- Calculate available storage space for downloads
                local currentStored = node.storedBytes or 0
                local totalStorage = node.ssdStorage + node.hddStorage
                local availableStorage = totalStorage - currentStored
                
                -- Get packets to download (assign to this server)
                local newPackets = WorkQueue.getPacketsForDownload(workQueue, node.id, serverCores, availableStorage, nodes)
                
                -- Debug: Report when packets are assigned
                if #newPackets > 0 then
                    print("Server " .. node.name .. " assigned " .. #newPackets .. " packets (cores=" .. serverCores .. ", storage=" .. availableStorage .. "GB)")
                end
            end
        end
    end
    
    -- Then update packet transfer progress
    for _, node in ipairs(nodes) do
        if node.category == "server" and node.powered then
            -- Get all downloads/uploads for this server
            local serverPackets = {}
            for _, packet in ipairs(workQueue.packets) do
                if packet.assignedServer == node.id then
                    table.insert(serverPackets, packet)
                end
            end
            
            -- Update transfer speeds based on network bandwidth
            local downloadSpeed = Contracts.calculateTransferSpeed(100, nodes, contracts.active, {state="downloading"})
            local uploadSpeed = Contracts.calculateTransferSpeed(50, nodes, contracts.active, {state="uploading"})
            
            for _, packet in ipairs(serverPackets) do
				if packet.state == "downloading" then
                    -- Calculate actual download speed based on available bandwidth
                    if #serverPackets > 0 then  -- Avoid division by zero
                        local actualSpeed = downloadSpeed / #serverPackets  -- Divide by concurrent downloads
                        packet.downloadProgress = packet.downloadProgress + dt * actualSpeed / 100
                        
                        if packet.downloadProgress >= 1 then
                            packet.downloadProgress = 1
                            WorkQueue.markPacketDownloaded(workQueue, packet.id)
                            -- Add to server's stored bytes
                            node.storedBytes = (node.storedBytes or 0) + packet.inputSize
                            print("Server " .. node.name .. " downloaded packet (now stored=" .. node.storedBytes .. "GB)")
                        end
                    end
                elseif packet.state == "uploading" then
                    -- Calculate actual upload speed
                    local actualSpeed = uploadSpeed / #serverPackets
                    packet.uploadProgress = packet.uploadProgress + dt * actualSpeed / 100
                    
                    if packet.uploadProgress >= 1 then
                        packet.uploadProgress = 1
                        WorkQueue.updatePacketUpload(workQueue, packet.id, dt, 1)  -- Complete upload
                        -- Release storage space
                        node.storedBytes = (node.storedBytes or 0) - packet.outputSize
                    end
                end
            end
        end
    end
    
    -- Finally, server cores process packets
    for _, node in ipairs(nodes) do
        if node.category == "server" and node.powered then
            -- Get all processing packets for this server
            local processingPackets = WorkQueue.getPacketsForProcessing(workQueue, node.id)
            
            -- Distribute cores among packets
            local serverCores = 0
            if node.cpus then
                for _, cpu in ipairs(node.cpus) do
                    serverCores = serverCores + cpu.cores
                end
            end
            
            local coresPerPacket = #processingPackets > 0 and (serverCores / #processingPackets) or 0
            
            for _, packet in ipairs(processingPackets) do
                local computeSpeed = math.max(1, coresPerPacket)
                
                -- CPU can do GPU work at half speed
                if packet.type == "gpu" and not (node.gpus and #node.gpus > 0) then
                    computeSpeed = computeSpeed * 0.5
                end
                
                local completed = WorkQueue.updatePacketProcessing(workQueue, packet.id, dt, computeSpeed)
                
                if completed then
                    -- Release storage space for processed data
                    node.storedBytes = (node.storedBytes or 0) - packet.inputSize
                end
            end
        end
    end
end

-- Update contract progress based on work queue
-- Compute smooth, weighted progress for a contract based on packet stage progress
function computeContractSmoothProgress(contractId)
    local totIn, totOut, totComp = 0, 0, 0
    local doneIn, doneOut, doneComp = 0, 0, 0
    local any = false
    for _, p in ipairs(workQueue.packets) do
        if p.contractId == contractId then
            any = true
            local inSz = p.inputSize or 0
            local outSz = p.outputSize or 0
            local compT = p.computeTime or 0
            totIn = totIn + inSz
            totOut = totOut + outSz
            totComp = totComp + compT
            doneIn = doneIn + (p.downloadProgress or 0) * inSz
            doneComp = doneComp + (p.processingProgress or 0) * compT
            doneOut = doneOut + (p.uploadProgress or 0) * outSz
        end
    end
    if not any then return nil end
    local total = totIn + totOut + totComp
    if total <= 0 then return 0 end
    local done = doneIn + doneOut + doneComp
    return (done / total) * 100
end

function computeContractStageProgress(contractId, contractType)
    local dnTot, dnDone = 0, 0
    local prTot, prDone = 0, 0
    local upTot, upDone = 0, 0
    local hasDn, hasPr, hasUp = false, false, false
    for _, p in ipairs(workQueue.packets) do
        if p.contractId == contractId then
            local inSz = p.inputSize or 0
            local outSz = p.outputSize or 0
            local compT = p.computeTime or 0
            if (p.downloadProgress or 0) < 1 and (p.processingProgress or 0) == 0 and (p.uploadProgress or 0) == 0 then
                hasDn = true
                dnTot = dnTot + inSz
                dnDone = dnDone + (p.downloadProgress or 0) * inSz
            elseif (p.processingProgress or 0) < 1 and (p.uploadProgress or 0) == 0 then
                hasPr = true
                prTot = prTot + compT
                prDone = prDone + (p.processingProgress or 0) * compT
            elseif (p.uploadProgress or 0) < 1 then
                hasUp = true
                upTot = upTot + outSz
                upDone = upDone + (p.uploadProgress or 0) * outSz
            end
        end
    end
    local stage, frac = "Idle", 0
    if hasDn then
        stage = "Download"
        frac = dnTot > 0 and (dnDone / dnTot) or 0
    elseif hasPr then
        stage = (contractType == "store") and "Store" or "Compute"
        frac = prTot > 0 and (prDone / prTot) or 0
    elseif hasUp then
        stage = "Upload"
        frac = upTot > 0 and (upDone / upTot) or 0
    end
    return stage, math.max(0, math.min(frac, 1))
end

function updateContractProgress(dt)
    local contractsToRemove = {}
    local contractCompleted = false  -- Track if any contracts complete this frame
    
    for i, contract in ipairs(contracts.active) do
		if contract.state == "idle" then
			contract.state = "downloading"
			contract.progress = 0
		end
        -- Get work queue progress for this contract
        local progress = WorkQueue.getContractProgress(workQueue, contract.id)
        local smooth = computeContractSmoothProgress(contract.id)
        contract.progress = smooth or progress.progress
        
        -- Determine contract state based on packet states
        if progress.total > 0 then
            if progress.completed == progress.total then
                contract.state = "complete"
                -- Pay when contract completes
                if contract.type == "compute" then
                    playerMoney = playerMoney + contract.payment
                end
                table.insert(contractsToRemove, i)  -- Mark for removal
                contractCompleted = true
            elseif progress.downloading > 0 and progress.processing == 0 and progress.uploading == 0 then
                contract.state = "downloading"
            elseif progress.processing > 0 and progress.completed == 0 and progress.uploading == 0 then
                contract.state = "computing"
            elseif progress.uploading > 0 and progress.completed == 0 then
                contract.state = "uploading"
            end
        end
    end
    
    -- Remove completed contracts
    for i = #contractsToRemove, 1, -1 do
        local index = contractsToRemove[i]
        local contract = contracts.active[index]
        WorkQueue.removeContractPackets(workQueue, contract.id)
        table.remove(contracts.active, index)
    end
    
    -- For store contracts, pay during storing
    for i, contract in ipairs(contracts.active) do
        if contract.type == "store" then
            local progress = WorkQueue.getContractProgress(workQueue, contract.id)
            -- Only pay if packets are still being stored (i.e., processed but not uploaded)
            if progress.processing > 0 then
                playerMoney = playerMoney + (contract.paymentPerSecond * dt)
            end
        end
    end
    
    -- Auto-accept new contracts when one completes (if enabled)
    if contractCompleted and autoAcceptContracts then
        Contracts.autoAccept(contracts.available, contracts.active, nodes)
    end
end

function love.draw()
    -- Background
    love.graphics.clear(0.15, 0.15, 0.18)
    
    -- Apply camera transform
    love.graphics.push()
    love.graphics.scale(camera.zoom, camera.zoom)
    love.graphics.translate(-camera.x, -camera.y)
    
    -- Draw grid
    if showGrid then
        Draw.Grid()
    end
    
    -- Draw connections
    for _, conn in ipairs(connections) do
        local color = Cables.getColor(conn.type)
        local lineWidth = Cables.getLineWidth(conn.type)
        love.graphics.setColor(color[1], color[2], color[3], 0.8)
        love.graphics.setLineWidth(lineWidth / camera.zoom)
        love.graphics.line(conn.from.x, conn.from.y, conn.to.x, conn.to.y)
    end
    
    -- Draw connection preview when connecting
    if connectingFrom then
        -- Get current cable type from hotkey system
        local cableId
        if hotkeyMappings["5"] then
            local currentIndex = currentHotkeyIndices["5"] or 1
            local item = hotkeyMappings["5"].items[currentIndex]
            if item and item.source == "cable" then
                cableId = item.id
            end
        end
        
        if cableId then
            local color = Cables.getColor(cableId)
            local lineWidth = Cables.getLineWidth(cableId)
            love.graphics.setColor(color[1], color[2], color[3], 0.5)
            love.graphics.setLineWidth(lineWidth / camera.zoom)
            love.graphics.line(connectingFrom.x, connectingFrom.y, mouse.worldX, mouse.worldY)
        end
    end
    
    -- Draw nodes (skip nodes that are in racks, they'll be drawn separately)
    for _, node in ipairs(nodes) do
        if not node.parentRack then
            Draw.Node(node)
        end
    end
    
    -- Draw rack contents with full details if rack is selected
    if selectedNode and selectedNode.category == "rack" then
        -- Spread items out in a grid (3 items per row)
        local itemCount = #selectedNode.contents
        if itemCount > 0 then
            local itemsPerRow = 3
            local spacingX = 25  -- Horizontal spacing
            local spacingY = 75  -- Vertical spacing between rows
            local startOffsetY = 100  -- Position below the rack
            
            for i, item in ipairs(selectedNode.contents) do
                -- Calculate row and column
                local col = (i - 1) % itemsPerRow
                local row = math.floor((i - 1) / itemsPerRow)
                
                -- Calculate position
                local itemsInRow = math.min(itemsPerRow, itemCount - row * itemsPerRow)
                local rowStartX = selectedNode.x - ((itemsInRow - 1) * (item.width + spacingX) / 2)
                
                -- Temporarily move item for display
                local origX, origY = item.x, item.y
                item.x = rowStartX + col * (item.width + spacingX)
                item.y = selectedNode.y + startOffsetY + row * spacingY
                
                Draw.Node(item)
                
                -- Draw line connecting to rack
                love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
                love.graphics.setLineWidth(1 / camera.zoom)
                love.graphics.line(selectedNode.x, selectedNode.y, item.x, item.y)
                
                -- Restore original position
                item.x, item.y = origX, origY
            end
        end
    end
    
    -- Draw ghost preview for hardware placement
    local variantId = nil
    if currentTool:match("^place_") then
        local hotkey = currentTool:sub(7)
        local mapping = hotkeyMappings[hotkey]
        if mapping then
            local currentIndex = currentHotkeyIndices[hotkey] or 1
            local item = mapping.items[currentIndex]
            if item and item.source == "hardware" then
                variantId = item.id
            end
        end
    end
    
    if variantId then
        local placement = Hardware.getRackPlacement(variantId)
        
        -- Highlight rack if hovering over one for required placement
        if placement == Hardware.RackPlacement.REQUIRED then
            local targetRack = Racks.getRackAtPosition(mouse.worldX, mouse.worldY, nodes)
            if targetRack then
                local canPlace = Racks.canPlaceInRack(variantId, targetRack)
                if canPlace then
                    love.graphics.setColor(0.3, 0.9, 0.3, 0.3)
                else
                    love.graphics.setColor(0.9, 0.3, 0.3, 0.3)
                end
                local rackHeight = Hardware.getDisplayHeight("rack")
                love.graphics.rectangle("fill", targetRack.x - targetRack.width/2, targetRack.y - rackHeight/2, 
                targetRack.width, rackHeight, 5)
            end
        end
        
        Draw.GhostNode(variantId, mouse.worldX, mouse.worldY)
    end
    
    -- Draw box selection
    if boxSelecting then
        love.graphics.setColor(0.3, 0.6, 0.9, 0.3)
        local boxX = math.min(boxSelectStart.x, boxSelectEnd.x)
        local boxY = math.min(boxSelectStart.y, boxSelectEnd.y)
        local boxW = math.abs(boxSelectEnd.x - boxSelectStart.x)
        local boxH = math.abs(boxSelectEnd.y - boxSelectStart.y)
        love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)
        
        love.graphics.setColor(0.3, 0.6, 0.9, 0.8)
        love.graphics.setLineWidth(2 / camera.zoom)
        love.graphics.rectangle("line", boxX, boxY, boxW, boxH)
    end
    
    -- Draw paste mode ghosts
    if pasteMode and #clipboard.nodes > 0 then
        for _, nodeCopy in ipairs(clipboard.nodes) do
            local ghostX = mouse.worldX + nodeCopy.relX
            local ghostY = mouse.worldY + nodeCopy.relY
            Draw.GhostNode(nodeCopy.variantId, ghostX, ghostY)
        end
    end
    
    -- Restore transform
    love.graphics.pop()
    
    -- Draw UI
    Draw.UI()
    
    -- Draw contracts screen if open
    if showContractsScreen then
        Draw.ContractsScreen()
    end
    
    -- Draw save/load menu if open
    if showSaveLoadMenu then
        Draw.SaveLoadMenu()
    end
end

function love.mousepressed(x, y, button)
    -- Handle save/load menu interactions first
    if showSaveLoadMenu and button == 1 then
        local panelW = 600
        local panelH = 500
        local panelX = (love.graphics.getWidth() - panelW) / 2
        local panelY = (love.graphics.getHeight() - panelH) / 2
        local tabY = panelY + 50
        
        -- Check tab clicks
        if x >= panelX + 20 and x <= panelX + 120 and y >= tabY and y <= tabY + 30 then
            saveLoadMenuTab = "load"
            return
        elseif x >= panelX + 130 and x <= panelX + 230 and y >= tabY and y <= tabY + 30 then
            saveLoadMenuTab = "save"
            return
        end
        
        -- Load tab - check load button clicks
        if saveLoadMenuTab == "load" then
            local saves = SaveLoad.getSaveFiles()
            local contentY = tabY + 50
            local listY = contentY + 30
            
            for i, save in ipairs(saves) do
                local itemY = listY + (i - 1) * 60 - saveLoadScrollOffset
                
                -- Calculate button bounds
                local btnX = panelX + panelW - 110
                local btnY = itemY + 10
                local btnW = 70
                local btnH = 30
                
                if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                    print("Loading " .. save.name)
                    loadGame(save.name)
                    showSaveLoadMenu = false
                    return
                end
            end
        else
            -- Save tab - check save button click
            local contentY = tabY + 50
            local inputY = contentY + 30
            local btnX = panelX + panelW / 2 - 40
            local btnY = inputY + 50
            local btnW = 80
            local btnH = 35
            
            if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                if saveFilename ~= "" then
                    local filename = saveFilename
                    if not filename:match("%.sav$") then
                        filename = filename .. ".sav"
                    end
                    saveGame(filename)
                    showSaveLoadMenu = false
                end
                return
            end
        end
    -- Handle contract screen interactions
    elseif showContractsScreen and button == 1 then
        local panelW = 700
        local panelH = 600
        local panelX = (love.graphics.getWidth() - panelW) / 2
        local panelY = (love.graphics.getHeight() - panelH) / 2
        
        -- Check auto-accept checkbox click
        local checkboxX = panelX + panelW - 180
        local checkboxY = panelY + 40
        local checkboxSize = 14
        
        if x >= checkboxX and x <= checkboxX + 90 and y >= checkboxY and y <= checkboxY + checkboxSize then
            autoAcceptContracts = not autoAcceptContracts
            return
        end
        
        -- Check accept button clicks
        for i, contract in ipairs(contracts.available) do
            if contract.acceptButtonBounds then
                local btnBounds = contract.acceptButtonBounds
                if x >= btnBounds.x and x <= btnBounds.x + btnBounds.w and
                   y >= btnBounds.y and y <= btnBounds.y + btnBounds.h then
                                        
                    -- Add contract packets to work queue
                    Contracts.addToWorkQueue(workQueue, contract, nodes)
                    print("Accepted contract " .. contract.name .. " with " .. workQueue.nextPacketId .. " packets added to queue")
                    break
                end
            end
        end
    elseif button == 3 then -- Middle mouse for camera pan
        -- Only enable camera pan if no UI overlay is active
        if not showContractsScreen and not showSaveLoadMenu then
            mouse.dragging = true
            mouse.dragStartX = x
            mouse.dragStartY = y
            mouse.dragStartCamX = camera.x
            mouse.dragStartCamY = camera.y
        end
    elseif button == 1 then -- Left click
        -- Check if in paste mode
        if pasteMode then
            -- Place clipboard contents
            pasteClipboard(mouse.worldX, mouse.worldY)
            pasteMode = false
            return
        end
        
        -- Check if in copy mode for box select
        if copyMode then
            -- Start box selection for copy
            boxSelecting = true
            boxSelectStart.x = mouse.worldX
            boxSelectStart.y = mouse.worldY
            boxSelectEnd.x = mouse.worldX
            boxSelectEnd.y = mouse.worldY
            return
        end
        
        if currentTool == "select" then
            -- Check if clicking on expanded rack items first
            local clickedExpandedItem = false
            if selectedNode and selectedNode.category == "rack" then
                local itemCount = #selectedNode.contents
                if itemCount > 0 then
                    local itemsPerRow = 3
                    local spacingX = 50
                    local spacingY = 100
                    local startOffsetY = 150
                    
                    for i, item in ipairs(selectedNode.contents) do
                        -- Calculate row and column
                        local col = (i - 1) % itemsPerRow
                        local row = math.floor((i - 1) / itemsPerRow)
                        
                        -- Calculate position
                        local itemsInRow = math.min(itemsPerRow, itemCount - row * itemsPerRow)
                        local rowStartX = selectedNode.x - ((itemsInRow - 1) * (item.width + spacingX) / 2)
                        
                        local displayX = rowStartX + col * (item.width + spacingX)
                        local displayY = selectedNode.y + startOffsetY + row * spacingY
                        local nodeHeight = Hardware.getDisplayHeight(item)
                        
                        if pointInRect(mouse.worldX, mouse.worldY, displayX - item.width/2, displayY - nodeHeight/2, item.width, nodeHeight) then
                            -- Clicked on an expanded item, keep rack selected
                            clickedExpandedItem = true
                            break
                        end
                    end
                end
            end
            
            -- Only check for new selection if not clicking on expanded items
            if not clickedExpandedItem then
                local previousSelection = selectedNode
                selectedNode = nil
                
                for i = #nodes, 1, -1 do
                    local node = nodes[i]
                    local nodeHeight = Hardware.getDisplayHeight(node)
                    if pointInRect(mouse.worldX, mouse.worldY, node.x - node.width/2, node.y - nodeHeight/2, node.width, nodeHeight) then
                        -- If clicking on a rack item, select its parent rack instead
                        if node.parentRack then
                            selectedNode = node.parentRack
                        else
                            selectedNode = node
                            draggingNode = true
                            mouse.dragStartX = mouse.worldX
                            mouse.dragStartY = mouse.worldY
                            node.dragOffsetX = node.x - mouse.worldX
                            node.dragOffsetY = node.y - mouse.worldY
                        end
                        break
                    end
                end
            end
        elseif currentTool:match("^place_") then
            -- Determine what to place based on current hotkey mapping
            local hotkey = currentTool:sub(7)
            local mapping = hotkeyMappings[hotkey]
            if not mapping then
                return
            end
            
            local currentIndex = currentHotkeyIndices[hotkey] or 1
            local item = mapping.items[currentIndex]
            if not item then
                return
            end
            
            -- Handle hardware placement
            if item.source == "hardware" then
                local variantId = item.id
                
                -- Check if player can afford it
                local variant = Hardware.getVariant(variantId)
                if variant and variant.purchaseCost then
                    if playerMoney < variant.purchaseCost then
                        print("Cannot afford " .. variant.displayName .. " ($" .. variant.purchaseCost .. ")")
                        return
                    end
                end
                
                local placement = Hardware.getRackPlacement(variantId)
                
                -- Check if node requires a rack
                if placement == Hardware.RackPlacement.REQUIRED then
                    local targetRack = Racks.getRackAtPosition(mouse.worldX, mouse.worldY, nodes)
                    if targetRack then
                        local canPlace, errorMsg = Racks.canPlaceInRack(variantId, targetRack)
                        if canPlace then
                            local node = placeNode(variantId, mouse.worldX, mouse.worldY)
                            if node then
                                Racks.placeInRack(node, targetRack)
                                Racks.updateRackConnections(targetRack, connections)
                            end
                        else
                            print(errorMsg)
                        end
                    else
                        print("This hardware must be placed in a rack")
                    end
                else
                    placeNode(variantId, mouse.worldX, mouse.worldY)
                end
            
            -- Handle cable placement (connection mode)
            elseif item.source == "cable" then
                local cableId = item.id
                local clickedNode = getNodeAtPosition(mouse.worldX, mouse.worldY)
                
                if clickedNode then
                    if not connectingFrom then
                        -- Start connection
                        connectingFrom = clickedNode
                    else
                        -- Complete connection
                        if connectingFrom ~= clickedNode then
                            if createConnection(connectingFrom, clickedNode, cableId) then
                                -- Automatically start next connection
                                connectingFrom = getNextConnectionNode(connectingFrom, clickedNode, cableId)
                            else
                                connectingFrom = nil
                            end
                        else
                            connectingFrom = nil
                        end
                    end
                end
            end
        elseif currentTool == "connect_cable" then
            -- Handle connection mode
            local clickedNode = getNodeAtPosition(mouse.worldX, mouse.worldY)
            
            if clickedNode then
                if not connectingFrom then
                    -- Start connection
                    connectingFrom = clickedNode
                else
                    -- Complete connection
                    if connectingFrom ~= clickedNode then
                        local connType = connectionTypes[currentConnectionTypeIndex]
                        if createConnection(connectingFrom, clickedNode, connType) then
                            -- Automatically start next connection based on type
                            connectingFrom = getNextConnectionNode(connectingFrom, clickedNode, connType)
                        else
                            connectingFrom = nil
                        end
                    else
                        connectingFrom = nil
                    end
                end
            end
        end
    elseif button == 2 then -- Right click
        if connectingFrom then
            -- Cancel active connection
            connectingFrom = nil
        else
            -- Delete node under cursor
            local clickedNode = getNodeAtPosition(mouse.worldX, mouse.worldY)
            if clickedNode then
                -- Remove all connections to this node
                for i = #connections, 1, -1 do
                    if connections[i].from == clickedNode or connections[i].to == clickedNode then
                        table.remove(connections, i)
                    end
                end
                
                -- If deleting a rack, also remove internal rack connections
                if clickedNode.category == "rack" then
                    for i = #connections, 1, -1 do
                        if connections[i].isRackInternal and connections[i].rack == clickedNode then
                            table.remove(connections, i)
                        end
                    end
                end
                
                -- Remove the node
                for i, node in ipairs(nodes) do
                    if node == clickedNode then
                        table.remove(nodes, i)
                        if selectedNode == clickedNode then
                            selectedNode = nil
                        end
                        break
                    end
                end
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 3 then
        mouse.dragging = false
        mouse.dragStartX = nil
        mouse.dragStartY = nil
        mouse.dragStartCamX = nil
        mouse.dragStartCamY = nil
    elseif button == 1 then
        -- Handle box selection complete
        if boxSelecting then
            copyBoxSelection()
            boxSelecting = false
            pasteMode = true  -- Enter paste mode immediately
            return
        end
        
        draggingNode = false
    end
    
    -- Update box selection end point
    if boxSelecting then
        boxSelectEnd.x = mouse.worldX
        boxSelectEnd.y = mouse.worldY
    end
    
    if draggingNode and selectedNode then
        selectedNode.x = mouse.worldX + selectedNode.dragOffsetX
        selectedNode.y = mouse.worldY + selectedNode.dragOffsetY
    end
end

function love.wheelmoved(x, y)
    -- Check if Ctrl is held (force zoom)
    local ctrlDown = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    
    -- Ctrl+scroll always zooms
    if ctrlDown then
        local oldZoom = camera.zoom
        camera.zoom = math.max(0.25, math.min(3, camera.zoom + y * 0.1))
        
        -- Zoom towards mouse position
        local mx, my = love.mouse.getPosition()
        camera.x = camera.x + (mx / oldZoom - mx / camera.zoom)
        camera.y = camera.y + (my / oldZoom - my / camera.zoom)
        return
    end
    
    -- Handle scrolling in save/load menu
    if showSaveLoadMenu then
        -- Check tab clicks
        local panelW = 600
        local panelH = 500
        local panelX = (love.graphics.getWidth() - panelW) / 2
        local panelY = (love.graphics.getHeight() - panelH) / 2
        
        local contentY = panelY + 50
        
        if saveLoadMenuTab == "load" then
            -- Scroll save list
            local saves = SaveLoad.getSaveFiles()
            local listY = contentY + 30
            
            saveLoadScrollOffset = saveLoadScrollOffset - y * 20
            local maxScroll = math.max(0, #saves * 60 - (panelY + panelH - contentY - 60))
            saveLoadScrollOffset = math.max(0, math.min(saveLoadScrollOffset, maxScroll))
        end
        return
    end
    
    -- Handle scrolling contracts screen
    if showContractsScreen then
        local panelW = 700
        local panelH = 600
        local panelX = (love.graphics.getWidth() - panelW) / 2
        local panelY = (love.graphics.getHeight() - panelH) / 2
        local dividerY = panelY + 320
        
        local mx, my = love.mouse.getPosition()
        
        if my < dividerY then
            -- Scroll available contracts
            contractsScrollOffset = contractsScrollOffset - y * 20
            local maxScroll = math.max(0, #contracts.available * 90 - (dividerY - panelY - 85))
            contractsScrollOffset = math.max(0, math.min(contractsScrollOffset, maxScroll))
        else
            -- Scroll active contracts  
            activeContractsScrollOffset = activeContractsScrollOffset - y * 20
            local maxScroll = math.max(0, #contracts.active * 50 - (panelY + panelH - dividerY - 45))
            activeContractsScrollOffset = math.max(0, math.min(activeContractsScrollOffset, maxScroll))
        end
        return
    end
    
    -- If in placement mode for any hotkey, cycle through options
    if currentTool:match("^place_") then
        local hotkey = currentTool:sub(7)  -- Extract the hotkey (after "place_")
        local mapping = hotkeyMappings[hotkey]
        if mapping and #mapping.items > 0 then
            if y > 0 then
                currentHotkeyIndices[hotkey] = currentHotkeyIndices[hotkey] - 1
                if currentHotkeyIndices[hotkey] < 1 then
                    currentHotkeyIndices[hotkey] = #mapping.items
                end
            else
                currentHotkeyIndices[hotkey] = currentHotkeyIndices[hotkey] + 1
                if currentHotkeyIndices[hotkey] > #mapping.items then
                    currentHotkeyIndices[hotkey] = 1
                end
            end
        end
    else
        -- Default zoom behavior
        local oldZoom = camera.zoom
        camera.zoom = math.max(0.25, math.min(3, camera.zoom + y * 0.1))
        
        -- Zoom towards mouse position
        local mx, my = love.mouse.getPosition()
        camera.x = camera.x + (mx / oldZoom - mx / camera.zoom)
        camera.y = camera.y + (my / oldZoom - my / camera.zoom)
    end
end

function love.keypressed(key)
    local shiftDown = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    
    if key == "escape" then
        -- Cancel paste mode if active
        if pasteMode then
            pasteMode = false
            return
        end
        
        -- If not in select mode, switch to it first
        if currentTool ~= "select" then
            currentTool = "select"
            connectingFrom = nil
        else
            -- Already in select mode, quit
            love.event.quit()
        end
    elseif key == "1" then
        currentTool = "select"
        connectingFrom = nil
    elseif key == "l" then
        -- Don't close save menu if typing in save filename
        if not (showSaveLoadMenu and saveLoadMenuTab == "save") then
            showSaveLoadMenu = not showSaveLoadMenu
            if showSaveLoadMenu then
                saveFilename = ""
            end
        end
    elseif key == "g" then
        showGrid = not showGrid
    elseif key == "space" then
        -- Toggle pause
        if isPaused then
            -- Unpause: restore previous speed
            isPaused = false
            timeSpeed = speedBeforePause
        else
            -- Pause: save current speed
            isPaused = true
            speedBeforePause = timeSpeed
        end
    elseif key == "=" or key == "+" or key == "kp+" then
        -- Increase time speed
        if isPaused then
            isPaused = false  -- Unpause if paused
        end
        timeSpeedIndex = timeSpeedIndex + 1
        if timeSpeedIndex > #timeSpeedOptions then
            timeSpeedIndex = #timeSpeedOptions
        end
        timeSpeed = timeSpeedOptions[timeSpeedIndex]
    elseif key == "-" or key == "_" or key == "kp-" then
        -- Decrease time speed
        if timeSpeedIndex == 1 and not isPaused then
            -- At 1x speed, pause instead of going lower
            isPaused = true
            speedBeforePause = timeSpeed
        else
            if isPaused then
                isPaused = false  -- Unpause if paused
            end
            timeSpeedIndex = timeSpeedIndex - 1
            if timeSpeedIndex < 1 then
                timeSpeedIndex = 1
            end
            timeSpeed = timeSpeedOptions[timeSpeedIndex]
        end
    elseif key == "0" then
        -- Reset to 1x speed
        isPaused = false
        timeSpeedIndex = 1
        timeSpeed = timeSpeedOptions[timeSpeedIndex]
    elseif key == "v" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        -- Enter paste mode with clipboard contents
        if #clipboard.nodes > 0 then
            pasteMode = true
        end
    elseif key == "f5" then
        -- Quick save
        saveGame("quicksave.sav")
    elseif key == "f9" then
        -- Quick load
        loadGame("quicksave.sav")
    elseif key == "s" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        -- Save with Ctrl+S
        saveGame("save.sav")
    elseif key == "backspace" or key == "delete" then
        if showSaveLoadMenu and saveLoadMenuTab == "save" and #saveFilename > 0 then
            saveFilename = saveFilename:sub(1, -2)
        elseif selectedNode then
            -- Remove all connections to this node
            for i = #connections, 1, -1 do
                if connections[i].from == selectedNode or connections[i].to == selectedNode then
                    table.remove(connections, i)
                end
            end
            
            -- Remove the node
            for i, node in ipairs(nodes) do
                if node == selectedNode then
                    table.remove(nodes, i)
                    selectedNode = nil
                    break
                end
            end
        end
    elseif key == "return" or key == "kpenter" then
        if showSaveLoadMenu and saveLoadMenuTab == "save" and saveFilename ~= "" then
            local filename = saveFilename
            if not filename:match("%.sav$") then
                filename = filename .. ".sav"
            end
            saveGame(filename)
            showSaveLoadMenu = false
        end
	elseif key == "c" then
		-- Check if Ctrl is held for copy mode toggle
		local ctrlDown = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
		if ctrlDown then
			-- Toggle copy mode
			copyMode = not copyMode
			if not copyMode then
				boxSelecting = false  -- Cancel any active box selection
			end
		else
			-- Open contracts screen
			showContractsScreen = not showContractsScreen
		end
    else
        -- Check if this key is in our hotkey mappings
        if hotkeyMappings[key] then
            local toolName = "place_" .. key
            if currentTool == toolName then
                -- Already in this tool mode, cycle through variants
                local mapping = hotkeyMappings[key]
                if #mapping.items > 0 then
                    if shiftDown then
                        currentHotkeyIndices[key] = currentHotkeyIndices[key] - 1
                        if currentHotkeyIndices[key] < 1 then
                            currentHotkeyIndices[key] = #mapping.items
                        end
                    else
                        currentHotkeyIndices[key] = currentHotkeyIndices[key] + 1
                        if currentHotkeyIndices[key] > #mapping.items then
                            currentHotkeyIndices[key] = 1
                        end
                    end
                end
            else
                -- Enter placement mode for this hotkey
                currentTool = toolName
                connectingFrom = nil  -- Cancel cable connecting if active
            end
		end
    end
end

function placeNode(variantId, x, y)
    local variant = Hardware.getVariant(variantId)
    if not variant then
        return nil
    end
    
    -- Deduct cost
    if variant.purchaseCost then
        if playerMoney < variant.purchaseCost then
            print("Cannot afford " .. variant.displayName)
            return nil
        end
        playerMoney = playerMoney - variant.purchaseCost
        print("Purchased " .. variant.displayName .. " for $" .. variant.purchaseCost)
    end
    
    local node = Hardware.createNode(variantId, x, y, #nodes)
    table.insert(nodes, node)
    return node
end

function getNodeAtPosition(x, y)
    for i = #nodes, 1, -1 do
        local node = nodes[i]
        local nodeHeight = Hardware.getDisplayHeight(node)
        if pointInRect(x, y, node.x - node.width/2, node.y - nodeHeight/2, node.width, nodeHeight) then
            -- If this node is in a rack, return the rack instead for connections
            if node.parentRack then
                return node.parentRack
            end
            return node
        end
    end
    return nil
end

function createConnection(from, to, connType)
    -- Check if connection already exists
    for _, conn in ipairs(connections) do
        if (conn.from == from and conn.to == to) or (conn.from == to and conn.to == from) then
            print("Connection already exists")
			table.remove(connections, _)
            return false
        end
    end
    
    -- Validate connection using comprehensive validation module
    local valid, errorMsg = ConnectionValidation.validate(from, to, connType, connections)
    if not valid then
        print("Cannot connect: " .. (errorMsg or "Unknown error"))
        return false
    end
    
    local connection = {
        from = from,
        to = to,
        type = connType
    }
    
    table.insert(connections, connection)
    print("Connected " .. from.name .. " to " .. to.name .. " with " .. connType)
    return true
end

function getNextConnectionNode(from, to, connType)
    if connType == "power" then
        -- For power cables, continue from the PSU if it's not at capacity
        local psu = nil
        if from.category == "power" then
            psu = from
        elseif to.category == "power" then
            psu = to
        end
        
        if psu and psu.powerUsed < psu.powerCapacity then
            return psu
        else
            return nil -- PSU at capacity or no PSU found
        end
    else
        -- For networking cables (ethernet/fiber)
        if from.category == "server" then
            -- Connected from server, continue from the network device
            return to
        elseif to.category == "server" then
            -- Connected to server, continue from the network device
            return from
        elseif from.category == "switch" or from.category == "router" or from.category == "modem" then
            -- Connected from network device, continue from what we connected to
            return to
        elseif to.category == "switch" or to.category == "router" or to.category == "modem" then
            -- Connected to network device, continue from what we connected to
            return to
        else
            return nil
        end
    end
end

function updatePowerConsumption()
    -- Reset all PSU power usage and powered status
    for _, node in ipairs(nodes) do
        if node.category == "psu" then
            node.powerUsed = 0
        end
        if node.powerDraw then
            node.powered = false
        end
        -- Also reset powered status for rack contents
        if node.category == "rack" then
            node.powered = false
            for _, item in ipairs(node.contents) do
                if item.powerDraw then
                    item.powered = false
                end
            end
        end
    end
    
    -- Calculate power consumption through power connections
    -- Power flows: PSU -> [highVoltage] -> Power Distributor -> [power] -> Devices
    -- OR: PSU -> [power] -> Devices (direct connection)
    
    -- Track which power distributors are connected to PSUs (map distributor -> list of PSUs)
	local poweredDistributors = {}
	for _, conn in ipairs(connections) do
		if conn.type == "highVoltage" then
			local psu, distributor = nil, nil
			if conn.from and conn.from.category == "psu" then
				psu = conn.from; distributor = conn.to
			elseif conn.to and conn.to.category == "psu" then
				psu = conn.to; distributor = conn.from
			end
			if psu and distributor and distributor.category == "power_distributor" then
				poweredDistributors[distributor] = poweredDistributors[distributor] or {}
				table.insert(poweredDistributors[distributor], psu)
			end
		end
	end

	-- Distribute power from PSUs (directly or through distributors) to devices.
	-- If multiple PSUs feed the same distributor, split demand proportionally by capacity.
	for _, conn in ipairs(connections) do
		if conn.type == "power" and not conn.isRackInternal then
			local device = nil
			local psuList = nil
			local directPsu = nil

			if conn.from and conn.from.category == "power_distributor" and conn.to then
				psuList = poweredDistributors[conn.from]
				device = conn.to
			elseif conn.to and conn.to.category == "power_distributor" and conn.from then
				psuList = poweredDistributors[conn.to]
				device = conn.from
			elseif conn.from and conn.from.category == "psu" then
				directPsu = conn.from
				device = conn.to
			elseif conn.to and conn.to.category == "psu" then
				directPsu = conn.to
				device = conn.from
			else
				device = nil
			end

			if not device then goto continue_power end

			local function assign_to_psus(psus, demand)
				if not psus or #psus == 0 then return end
				local totalCap = 0
				for _, p in ipairs(psus) do totalCap = totalCap + (p.powerCapacity or 0) end
				if totalCap <= 0 then
					psus[1].powerUsed = (psus[1].powerUsed or 0) + demand
					return
				end
				for _, p in ipairs(psus) do
					local share = ((p.powerCapacity or 0) / totalCap) * demand
					p.powerUsed = (p.powerUsed or 0) + share
				end
			end

			if device.category == "rack" then
				-- sum content draws
				local rackPowerDraw = 0
				if device.contents then
					for _, item in ipairs(device.contents) do
						if item.powerDraw then
							rackPowerDraw = rackPowerDraw + item.powerDraw
							item.powered = true
						end
					end
				end
				if directPsu then
					directPsu.powerUsed = (directPsu.powerUsed or 0) + rackPowerDraw
				else
					assign_to_psus(psuList, rackPowerDraw)
				end
				device.powered = true

			elseif device.powerDraw then
				if directPsu then
					directPsu.powerUsed = (directPsu.powerUsed or 0) + device.powerDraw
					device.powered = true
				else
					assign_to_psus(psuList, device.powerDraw)
					device.powered = true
				end
			end
		end
		::continue_power::
	end
end

function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function cycleConnectionType(direction)
    currentConnectionTypeIndex = currentConnectionTypeIndex + direction
    if currentConnectionTypeIndex > #connectionTypes then
        currentConnectionTypeIndex = 1
    elseif currentConnectionTypeIndex < 1 then
        currentConnectionTypeIndex = #connectionTypes
    end
end

function saveGame(filename)
    local gameState = {
        nodes = nodes,
        connections = connections,
        playerMoney = playerMoney,
        camera = camera,
        contracts = contracts,
        contractRefreshTimer = contractRefreshTimer,
        autoAcceptContracts = autoAcceptContracts
    }
    
    local success, err = SaveLoad.save(filename, gameState)
    if success then
        print("Game saved to " .. filename)
        local info = love.filesystem.getInfo(filename)
        if info then
            print("File size: " .. info.size .. " bytes")
        end
    else
        print("Failed to save: " .. tostring(err))
        print("Save directory: " .. love.filesystem.getSaveDirectory())
    end
end

function loadGame(filename)
    local loadedState, err = SaveLoad.load(filename)
    if not loadedState then
        print("Failed to load: " .. tostring(err))
        love.window.showMessageBox("Load Failed", "Failed to load save file:\n" .. tostring(err), "error")
        return
    end
    
    -- Restore game state
    nodes = loadedState.nodes
    connections = loadedState.connections
    playerMoney = loadedState.playerMoney
    camera.x = loadedState.camera.x
    camera.y = loadedState.camera.y
    camera.zoom = loadedState.camera.zoom
    contracts = loadedState.contracts
    contractRefreshTimer = loadedState.contractRefreshTimer
    autoAcceptContracts = loadedState.autoAcceptContracts
    
    -- Clear selection and reset tool
    selectedNode = nil
    connectingFrom = nil
    currentTool = "select"
    
    print("Game loaded from " .. filename)
end

function love.textinput(text)
    if showSaveLoadMenu and saveLoadMenuTab == "save" then
        saveFilename = saveFilename .. text
    end
end

function copyBoxSelection()
    -- Calculate box bounds
    local minX = math.min(boxSelectStart.x, boxSelectEnd.x)
    local maxX = math.max(boxSelectStart.x, boxSelectEnd.x)
    local minY = math.min(boxSelectStart.y, boxSelectEnd.y)
    local maxY = math.max(boxSelectStart.y, boxSelectEnd.y)
    
    -- Find nodes within selection
    local selectedNodes = {}
    local nodeMap = {}  -- Map from original node to clipboard index
    
    for i, node in ipairs(nodes) do
        if not node.parentRack then  -- Only copy top-level nodes
            local nodeHeight = Hardware.getDisplayHeight(node)
            local nodeLeft = node.x - node.width/2
            local nodeRight = node.x + node.width/2
            local nodeTop = node.y - nodeHeight/2
            local nodeBottom = node.y + nodeHeight/2
            
            -- Check if node overlaps selection box
            if nodeRight >= minX and nodeLeft <= maxX and nodeBottom >= minY and nodeTop <= maxY then
                table.insert(selectedNodes, node)
                nodeMap[node] = #selectedNodes
            end
        end
    end
    
    if #selectedNodes == 0 then
        return
    end
    
    -- Calculate center of selection
    local centerX = 0
    local centerY = 0
    for _, node in ipairs(selectedNodes) do
        centerX = centerX + node.x
        centerY = centerY + node.y
    end
    centerX = centerX / #selectedNodes
    centerY = centerY / #selectedNodes
    
    -- Deep copy nodes and their rack contents
    clipboard.nodes = {}
    clipboard.rackContents = {}  -- Store rack contents separately
    
    for idx, node in ipairs(selectedNodes) do
        local nodeCopy = {}
        for k, v in pairs(node) do
            if type(v) == "table" and k ~= "parentRack" and k ~= "contents" then
                -- Deep copy nested tables
                nodeCopy[k] = {}
                for k2, v2 in pairs(v) do
                    if type(v2) == "table" then
                        nodeCopy[k][k2] = {}
                        for k3, v3 in pairs(v2) do
                            nodeCopy[k][k2][k3] = v3
                        end
                    else
                        nodeCopy[k][k2] = v2
                    end
                end
            elseif k == "contents" then
                -- Copy rack contents
                nodeCopy.contents = {}
                clipboard.rackContents[idx] = {}
                for _, item in ipairs(v) do
                    local itemCopy = {}
                    for ik, iv in pairs(item) do
                        if type(iv) == "table" and ik ~= "parentRack" then
                            itemCopy[ik] = {}
                            for ik2, iv2 in pairs(iv) do
                                if type(iv2) == "table" then
                                    itemCopy[ik][ik2] = {}
                                    for ik3, iv3 in pairs(iv2) do
                                        itemCopy[ik][ik2][ik3] = iv3
                                    end
                                else
                                    itemCopy[ik][ik2] = iv2
                                end
                            end
                        elseif type(iv) ~= "function" and ik ~= "parentRack" then
                            itemCopy[ik] = iv
                        end
                    end
                    table.insert(clipboard.rackContents[idx], itemCopy)
                    -- Add rack contents to nodeMap for connection tracking
                    nodeMap[item] = idx .. "_" .. #clipboard.rackContents[idx]
                end
            elseif type(v) ~= "function" and k ~= "parentRack" then
                nodeCopy[k] = v
            end
        end
        -- Store relative position
        nodeCopy.relX = node.x - centerX
        nodeCopy.relY = node.y - centerY
        table.insert(clipboard.nodes, nodeCopy)
    end
    
    -- Copy connections
    clipboard.connections = {}
    for _, conn in ipairs(connections) do
        local fromIdx = nodeMap[conn.from]
        local toIdx = nodeMap[conn.to]
        
        -- Skip rack internal connections - they'll be recreated automatically
        if not conn.isRackInternal then
            -- Include connections between copied nodes AND connections to external nodes
            if fromIdx or toIdx then
                table.insert(clipboard.connections, {
                    fromIdx = fromIdx,  -- nil if external
                    toIdx = toIdx,      -- nil if external
                    type = conn.type,
                    fromExternal = not fromIdx and conn.from,  -- Store external node reference
                    toExternal = not toIdx and conn.to
                })
            end
        end
    end
    
    clipboard.centerX = centerX
    clipboard.centerY = centerY
    
    print(string.format("Copied %d nodes and %d connections", #clipboard.nodes, #clipboard.connections))
end

function pasteClipboard(x, y)
    if #clipboard.nodes == 0 then
        return
    end
    
    local pastedNodes = {}
    
    -- Create new nodes
    for i, nodeCopy in ipairs(clipboard.nodes) do
        local newNode = Hardware.createNode(nodeCopy.variantId, x + nodeCopy.relX, y + nodeCopy.relY, #nodes)
        
        -- Restore all properties except contents (handled separately)
        for k, v in pairs(nodeCopy) do
            if k ~= "relX" and k ~= "relY" and k ~= "x" and k ~= "y" and k ~= "name" and k ~= "contents" and type(v) ~= "function" then
                newNode[k] = v
            end
        end
        
        table.insert(nodes, newNode)
        pastedNodes[i] = newNode
        
        -- Restore rack contents
        if clipboard.rackContents and clipboard.rackContents[i] then
            for _, itemCopy in ipairs(clipboard.rackContents[i]) do
                local newItem = Hardware.createNode(itemCopy.variantId, 0, 0, #nodes)
                
                -- Restore item properties
                for k, v in pairs(itemCopy) do
                    if k ~= "x" and k ~= "y" and k ~= "name" and type(v) ~= "function" then
                        newItem[k] = v
                    end
                end
                
                table.insert(nodes, newItem)
                Racks = require("racks")
                Racks.placeInRack(newItem, newNode)
            end
            
            -- Update rack connections
            local Racks = require("racks")
            Racks.updateRackConnections(newNode, connections)
        end
    end
    
    -- Recreate connections
    for _, connCopy in ipairs(clipboard.connections) do
        local fromNode = connCopy.fromIdx and pastedNodes[connCopy.fromIdx] or connCopy.fromExternal
        local toNode = connCopy.toIdx and pastedNodes[connCopy.toIdx] or connCopy.toExternal
        
        if fromNode and toNode then
            -- Check if nodes still exist
            local fromExists = false
            local toExists = false
            for _, node in ipairs(nodes) do
                if node == fromNode then fromExists = true end
                if node == toNode then toExists = true end
            end
            
            if fromExists and toExists then
                createConnection(fromNode, toNode, connCopy.type)
            end
        end
    end
    
    print(string.format("Pasted %d nodes", #pastedNodes))
end
