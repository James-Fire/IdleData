Draw = {}

function Draw.Grid()
    love.graphics.setColor(0.2, 0.2, 0.25, 0.5)
    love.graphics.setLineWidth(1 / camera.zoom)
    
    local startX = math.floor(camera.x / gridSize) * gridSize
    local startY = math.floor(camera.y / gridSize) * gridSize
    local endX = camera.x + (love.graphics.getWidth() / camera.zoom)
    local endY = camera.y + (love.graphics.getHeight() / camera.zoom)
    
    -- Vertical lines
    for x = startX, endX, gridSize do
        love.graphics.line(x, startY, x, endY)
    end
    
    -- Horizontal lines
    for y = startY, endY, gridSize do
        love.graphics.line(startX, y, endX, y)
    end
end

function Draw.Node(node)
    local selected = (selectedNode == node)
    
    -- Get display height from hardware specs
    local displayHeight = Hardware.getDisplayHeight(node)
    
    -- Draw shadow
    if selected then
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", node.x - node.width/2 + 3, node.y - displayHeight/2 + 3, node.width, displayHeight, 5)
    end
    
    -- Draw node body with color from hardware specs
    local color = Hardware.getColor(node)
    love.graphics.setColor(color[1], color[2], color[3])
    
    love.graphics.rectangle("fill", node.x - node.width/2, node.y - displayHeight/2, node.width, displayHeight, 5)
    
    -- Draw border
    if selected then
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(3 / camera.zoom)
    else
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.setLineWidth(2 / camera.zoom)
    end
    love.graphics.rectangle("line", node.x - node.width/2, node.y - displayHeight/2, node.width, displayHeight, 5)
    
    -- Draw label
    love.graphics.setColor(0, 0, 0)
    local scale = 1 / camera.zoom
    love.graphics.print(node.name, node.x - node.width/2 + 5, node.y - displayHeight/2 + 5, 0, scale, scale)
    
    -- Draw server attributes
    if node.category == "server" then
        love.graphics.setColor(0, 0, 0)
        local baseY = node.y - displayHeight/2 + 20
        
        -- Calculate bonuses from expansion cards
        local bonuses = Hardware.calculateServerBonuses(node)
        
        -- Combine base CPUs with added CPUs from expansions
        local allCpus = {}
        for _, cpu in ipairs(node.cpus or {}) do
            table.insert(allCpus, cpu)
        end
        for _, cpu in ipairs(bonuses.addedCpus or {}) do
            table.insert(allCpus, cpu)
        end
        
        -- Calculate total cores and weighted average speed
        local totalCores = 0
        local weightedSpeedSum = 0
        for _, cpu in ipairs(allCpus) do
            totalCores = totalCores + cpu.cores
            weightedSpeedSum = weightedSpeedSum + (cpu.cores * cpu.speed)
        end
        local effectiveSpeed = totalCores > 0 and (weightedSpeedSum / totalCores) or 0
        
        -- Combine base GPUs with added GPUs from expansions
        local allGpus = {}
        for _, gpu in ipairs(node.gpus or {}) do
            table.insert(allGpus, gpu)
        end
        for _, gpu in ipairs(bonuses.addedGpus or {}) do
            table.insert(allGpus, gpu)
        end
        
        -- Calculate total GPU cores and weighted average speed
        local totalGpuCores = 0
        local weightedGpuSpeedSum = 0
        for _, gpu in ipairs(allGpus) do
            totalGpuCores = totalGpuCores + gpu.cores
            weightedGpuSpeedSum = weightedGpuSpeedSum + (gpu.cores * gpu.speed)
        end
        local effectiveGpuSpeed = totalGpuCores > 0 and (weightedGpuSpeedSum / totalGpuCores) or 0
        
        local totalSsd = node.ssdStorage + bonuses.ssdStorage
        local totalHdd = node.hddStorage + bonuses.hddStorage
        
        -- Download speed (replaced by network card if present)
        local effectiveDownloadSpeed = bonuses.downloadSpeed > 0 and bonuses.downloadSpeed or node.maxDownloadSpeed
        
        local textOffsetY = 0
        
        -- CPU info (show bonus if any)
        local cpuText
        if #bonuses.addedCpus > 0 then
            cpuText = string.format("CPU: %dx @ %.1fGHz (%d/%d slots)", totalCores, effectiveSpeed, bonuses.usedSlots, node.maxExpansionSlots or 4)
            love.graphics.setColor(0.2, 0.7, 0.2)  -- Green for boosted
        else
            cpuText = string.format("CPU: %dx @ %.1fGHz", totalCores, effectiveSpeed)
            love.graphics.setColor(0, 0, 0)
        end
        love.graphics.print(cpuText, node.x - node.width/2 + 5, baseY + textOffsetY, 0, scale * 0.7, scale * 0.7)
        textOffsetY = textOffsetY + 11
        
        -- GPU info (show if any GPUs present)
        if totalGpuCores > 0 then
            local gpuText = string.format("GPU: %dx @ %.1fGHz", totalGpuCores, effectiveGpuSpeed)
            if #bonuses.addedGpus > 0 then
                love.graphics.setColor(0.2, 0.7, 0.2)  -- Green for boosted
            else
                love.graphics.setColor(0, 0, 0)
            end
            love.graphics.print(gpuText, node.x - node.width/2 + 5, baseY + textOffsetY, 0, scale * 0.7, scale * 0.7)
            textOffsetY = textOffsetY + 11
        end
        
        -- Storage info (show bonus if any)
        local storageText
        if bonuses.ssdStorage > 0 or bonuses.hddStorage > 0 then
            storageText = string.format("SSD:%.0fGB HDD:%.0fGB", totalSsd, totalHdd)
            love.graphics.setColor(0.2, 0.7, 0.2)  -- Green for boosted
        else
            storageText = string.format("SSD:%.0fGB HDD:%.0fGB", node.ssdStorage, node.hddStorage)
            love.graphics.setColor(0, 0, 0)
        end
        love.graphics.print(storageText, node.x - node.width/2 + 5, baseY + textOffsetY, 0, scale * 0.55, scale * 0.55)
        textOffsetY = textOffsetY + 11
        
        -- Download speed (show bonus if replaced)
        local netText = string.format("Net: %d Mbps", effectiveDownloadSpeed)
        if bonuses.downloadSpeed > 0 then
            love.graphics.setColor(0.2, 0.7, 0.2)  -- Green for boosted
        else
            love.graphics.setColor(0, 0, 0)
        end
        love.graphics.print(netText, node.x - node.width/2 + 5, baseY + textOffsetY, 0, scale * 0.55, scale * 0.55)
        textOffsetY = textOffsetY + 11
        
        -- Power status
        love.graphics.setColor(0, 0, 0)
        local powerText = string.format("Power: %dW", node.powerDraw)
        if node.powered then
            powerText = powerText .. " ✓"
        else
            powerText = powerText .. " ✗"
        end
        love.graphics.print(powerText, node.x - node.width/2 + 5, baseY + textOffsetY, 0, scale * 0.6, scale * 0.6)
    end
    
    -- Draw data transfer speed for network devices
    if node.category == "switch" or node.category == "router" or node.category == "modem" then
        love.graphics.setColor(0, 0, 0)
        local baseY = node.y - displayHeight/2 + 20
        local speedText = string.format("%.0f Mbps", node.dataSpeed)
        love.graphics.print(speedText, node.x - node.width/2 + 5, baseY, 0, scale * 0.7, scale * 0.7)
        
        -- Power status below speed
        local powerText = string.format("%dW", node.powerDraw)
        if node.powered then
            powerText = powerText .. " ✓"
        else
            powerText = powerText .. " ✗"
        end
        love.graphics.print(powerText, node.x - node.width/2 + 5, baseY + 11, 0, scale * 0.6, scale * 0.6)
    end
    
    -- Draw power info for PSU and Power Distributors
    if node.category == "psu" or node.category == "power_distributor" then
        local powerText = string.format("%dW / %dW", node.powerUsed or 0, node.powerCapacity or 0)
        local textY = node.y - displayHeight/2 + 20
        
        -- Add status indicator based on capacity
        local ratio = (node.powerUsed or 0) / (node.powerCapacity or 1)
        if ratio > 1 then
            powerText = powerText .. " ⚠"
        elseif ratio > 0.8 then
            powerText = powerText .. " !"
        end
        
        love.graphics.setColor(0, 0, 0)
        love.graphics.print(powerText, node.x - node.width/2 + 5, textY, 0, scale * 0.8, scale * 0.8)
    end
    
    -- Draw expansion card info
    if node.category == "expansion" then
        love.graphics.setColor(0, 0, 0)
        local baseY = node.y - displayHeight/2 + 20
        local offsetY = 0
        
        -- Show what this expansion adds
        if node.addCpu then
            love.graphics.print(string.format("+%dx @ %.1fGHz CPU", node.addCpu.cores, node.addCpu.speed), node.x - node.width/2 + 5, baseY + offsetY, 0, scale * 0.6, scale * 0.6)
            offsetY = offsetY + 10
        end
        if node.addGpu then
            love.graphics.print(string.format("+%dx @ %.1fGHz GPU", node.addGpu.cores, node.addGpu.speed), node.x - node.width/2 + 5, baseY + offsetY, 0, scale * 0.6, scale * 0.6)
            offsetY = offsetY + 10
        end
        if node.replaceDownloadSpeed and node.replaceDownloadSpeed > 0 then
            love.graphics.print(string.format("Network: %d Mbps", node.replaceDownloadSpeed), node.x - node.width/2 + 5, baseY + offsetY, 0, scale * 0.6, scale * 0.6)
            offsetY = offsetY + 10
        end
        if node.enablesFiber then
            love.graphics.print("Enables Fiber", node.x - node.width/2 + 5, baseY + offsetY, 0, scale * 0.6, scale * 0.6)
            offsetY = offsetY + 10
        end
        if node.addSsdStorage and node.addSsdStorage > 0 then
            love.graphics.print(string.format("+%.0fGB SSD", node.addSsdStorage), node.x - node.width/2 + 5, baseY + offsetY, 0, scale * 0.6, scale * 0.6)
            offsetY = offsetY + 10
        end
        if node.addHddStorage and node.addHddStorage > 0 then
            love.graphics.print(string.format("+%.0fGB HDD", node.addHddStorage), node.x - node.width/2 + 5, baseY + offsetY, 0, scale * 0.6, scale * 0.6)
            offsetY = offsetY + 10
        end
        
        -- Power status
        local powerText = string.format("%dW", node.powerDraw)
        if node.powered then
            powerText = powerText .. " ✓"
        else
            powerText = powerText .. " ✗"
        end
        love.graphics.print(powerText, node.x - node.width/2 + 5, baseY + offsetY, 0, scale * 0.6, scale * 0.6)
    end
    
    -- Draw rack info and contents
    if node.category == "rack" then
        love.graphics.setColor(0, 0, 0)
        local textY = node.y - displayHeight/2 + 20
        
        -- Show capacity
        local capacityText = string.format("%d / %dU", node.usedUnits, node.maxUnits)
        love.graphics.print(capacityText, node.x - node.width/2 + 5, textY, 0, scale * 0.7, scale * 0.7)
        
        -- Only draw compact view if NOT selected
        -- (Selected racks draw full details separately)
        if not selected then
            -- Draw rack contents as compact colored bars
            local itemY = textY + 15
            local itemHeight = 12
            local itemPadding = 2
            
            for _, item in ipairs(node.contents) do
                -- Draw small box for each item
                local itemColor = Hardware.getColor(item.category)
                love.graphics.setColor(itemColor[1], itemColor[2], itemColor[3], 0.7)
                love.graphics.rectangle("fill", node.x - node.width/2 + 5, itemY, node.width - 10, itemHeight)
                
                -- Draw item name
                love.graphics.setColor(0, 0, 0)
                love.graphics.print(item.name, node.x - node.width/2 + 7, itemY + 1, 0, scale * 0.45, scale * 0.45)
                
                itemY = itemY + itemHeight + itemPadding
            end
        end
    end
end

function Draw.UI()
    -- Toolbar background
    love.graphics.setColor(0.1, 0.1, 0.12, 0.95)
    love.graphics.rectangle("fill", 10, 10, 220, 250, 5)
    
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Datacenter Simulator", 20, 20)
    
    -- Tool buttons
    local y = 50
    
    -- Select tool
    if currentTool == "select" then
        love.graphics.setColor(0.3, 0.6, 0.9)
    else
        love.graphics.setColor(0.4, 0.4, 0.45)
    end
    love.graphics.print("[1] Select/Move", 20, y)
    y = y + 25
    
    -- Dynamically list all hotkeys
    local sortedHotkeys = {}
    for hotkey, _ in pairs(hotkeyMappings) do
        table.insert(sortedHotkeys, hotkey)
    end
    table.sort(sortedHotkeys)
    
    for _, hotkey in ipairs(sortedHotkeys) do
        local mapping = hotkeyMappings[hotkey]
        local toolName = "place_" .. hotkey
        
        if currentTool == toolName then
            love.graphics.setColor(0.3, 0.6, 0.9)
        else
            love.graphics.setColor(0.4, 0.4, 0.45)
        end
        
        local currentIndex = currentHotkeyIndices[hotkey] or 1
        local currentItem = mapping.items[currentIndex]
        
        if currentItem then
            local displayName, cost
            if currentItem.source == "hardware" then
                local variant = Hardware.getVariant(currentItem.id)
                displayName = variant and variant.displayName or "Unknown"
                cost = variant and variant.purchaseCost or 0
                love.graphics.print(string.format("[%s] %s ($%d)", hotkey, displayName, cost), 20, y)
            elseif currentItem.source == "cable" then
                local cable = Cables.getVariant(currentItem.id)
                displayName = cable and cable.displayName or "Unknown"
                love.graphics.print(string.format("[%s] %s", hotkey, displayName), 20, y)
            end
        else
            love.graphics.print(string.format("[%s] None", hotkey), 20, y)
        end
        
        y = y + 25
    end
    
    -- Instructions
    y = y + 10
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Press 2/3/5: Cycle options", 20, y)
    love.graphics.print("+ Shift: Cycle back", 20, y + 15)
    love.graphics.print("Middle Click: Pan", 20, y + 40)
    love.graphics.print("Scroll: Zoom/Cycle", 20, y + 55)
    love.graphics.print("Del: Delete Node", 20, y + 70)
    love.graphics.print("ESC: Cancel/Quit", 20, y + 85)
    
    -- Info
    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.print(string.format("Nodes: %d", #nodes), 20, love.graphics.getHeight() - 60)
    love.graphics.print(string.format("Zoom: %.1fx", camera.zoom), 20, love.graphics.getHeight() - 40)
    
    -- Money and contracts
    love.graphics.setColor(0.3, 0.9, 0.3)
    love.graphics.print(string.format("$%d", playerMoney), 20, love.graphics.getHeight() - 20)
    
    -- Time speed indicator
    local speedText
    if isPaused then
        speedText = "PAUSED"
        love.graphics.setColor(0.9, 0.5, 0.2)
    elseif timeSpeed < 0 then
        speedText = "Speed: MAX"
        love.graphics.setColor(0.9, 0.3, 0.3)
    elseif timeSpeed > 1 then
        speedText = string.format("Speed: %dx", timeSpeed)
        love.graphics.setColor(0.9, 0.9, 0.3)
    else
        speedText = "Speed: 1x"
        love.graphics.setColor(0.7, 0.7, 0.7)
    end
    love.graphics.print(speedText, love.graphics.getWidth() / 2 - 40, love.graphics.getHeight() - 20)
    
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(string.format("[C] Contracts (%d)", #contracts.available), love.graphics.getWidth() - 150, love.graphics.getHeight() - 20)
end

function Draw.ContractsScreen()
    -- Darken background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Main panel
    local panelW = 700
    local panelH = 600
    local panelX = (love.graphics.getWidth() - panelW) / 2
    local panelY = (love.graphics.getHeight() - panelH) / 2
    
    love.graphics.setColor(0.15, 0.15, 0.18)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10)
    
    love.graphics.setColor(0.3, 0.6, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10)
    
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Contracts", panelX + 20, panelY + 15, 0, 1.5, 1.5)
    
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Press C to close", panelX + panelW - 120, panelY + 20)
    
    -- Refresh timer display
    local timeUntilRefresh = contractRefreshInterval - contractRefreshTimer
    local minutes = math.floor(timeUntilRefresh / 60)
    local seconds = math.floor(timeUntilRefresh % 60)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print(string.format("Refresh: %d:%02d", minutes, seconds), panelX + 20, panelY + 40, 0, 0.8, 0.8)
    
    -- Auto-accept checkbox
    local checkboxX = panelX + panelW - 180
    local checkboxY = panelY + 40
    local checkboxSize = 14
    
    -- Checkbox background
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle("fill", checkboxX, checkboxY, checkboxSize, checkboxSize, 2)
    
    -- Checkbox checkmark
    if autoAcceptContracts then
        love.graphics.setColor(0.3, 0.9, 0.3)
        love.graphics.rectangle("fill", checkboxX + 3, checkboxY + 3, checkboxSize - 6, checkboxSize - 6, 1)
    end
    
    -- Checkbox label
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Auto-accept", checkboxX + checkboxSize + 8, checkboxY + 1, 0, 0.8, 0.8)
    
    -- Divider position between available and active contracts
    local dividerY = panelY + 320
    
    -- Available contracts section header
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("Available", panelX + 20, panelY + 50, 0, 0.9, 0.9)
    
    -- Available contracts list with clipping
    local listY = panelY + 75
    local availableHeight = dividerY - listY - 10
    
    love.graphics.setScissor(panelX + 20, listY, panelW - 40, availableHeight)
    for i, contract in ipairs(contracts.available) do
        local itemH = 80
        local itemY = listY + (i - 1) * (itemH + 10) - contractsScrollOffset
        
        -- Contract box
        love.graphics.setColor(0.2, 0.2, 0.24)
        love.graphics.rectangle("fill", panelX + 20, itemY, panelW - 40, itemH, 5)
        
        -- Contract info
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(contract.name, panelX + 30, itemY + 10)
        
        love.graphics.setColor(0.8, 0.8, 0.8)
        if contract.type == "compute" then
            -- Show separate CPU and GPU work
            local desc = ""
            if contract.cpuPackets > 0 and contract.gpuPackets > 0 then
                desc = string.format("CPU: %d pkts x %.0fs | GPU: %d pkts x %.0fs", 
                    contract.cpuPackets, contract.cpuTimePerPacket, contract.gpuPackets, contract.gpuTimePerPacket)
            elseif contract.cpuPackets > 0 then
                desc = string.format("CPU: %d packets x %.0fs/pkt", 
                    contract.cpuPackets, contract.cpuTimePerPacket)
            elseif contract.gpuPackets > 0 then
                desc = string.format("GPU: %d packets x %.0fs/pkt", 
                    contract.gpuPackets, contract.gpuTimePerPacket)
            end
            love.graphics.print(desc, panelX + 30, itemY + 30, 0, 0.8, 0.8)
            
            -- Show data sizes on next line
            local dataDesc = string.format("%.0fGB -> %.0fGB", contract.packetSizeInput, contract.packetSizeOutput)
            love.graphics.print(dataDesc, panelX + 30, itemY + 45, 0, 0.7, 0.7)
        else -- store
            local desc = string.format("%d packets, %.0fGB each, store for %.0fs", 
                contract.packetCount, contract.packetSize, contract.storageDuration)
            love.graphics.print(desc, panelX + 30, itemY + 30, 0, 0.8, 0.8)
        end
        
        -- Payment
        love.graphics.setColor(0.3, 0.9, 0.3)
        local paymentText = ""
        if contract.type == "store" then
            paymentText = string.format("$%.1f/s ($%d total)", contract.paymentPerSecond, contract.totalPayment)
        else
            paymentText = string.format("$%d", contract.payment)
        end
        local paymentY = contract.type == "compute" and (itemY + 60) or (itemY + 50)
        love.graphics.print(paymentText, panelX + 30, paymentY)
        
        -- Accept button
        local btnX = panelX + panelW - 120
        local btnY = itemY + 25
        local btnW = 80
        local btnH = 30
        
        love.graphics.setColor(0.3, 0.6, 0.9)
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 3)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Accept", btnX + 15, btnY + 8)
        
        -- Check if mouse is over accept button
        local mx, my = love.mouse.getPosition()
        if mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH then
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 3)
            
            -- Store for click detection
            contract.acceptButtonBounds = {x = btnX, y = btnY, w = btnW, h = btnH}
        else
            contract.acceptButtonBounds = nil
        end
    end
    
    love.graphics.setScissor() -- Reset clipping
    
    -- Divider line
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 20, dividerY, panelX + panelW - 20, dividerY)
    
    -- Active contracts section
    local activeY = dividerY + 10
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("Active", panelX + 20, activeY, 0, 0.9, 0.9)
    
    if #contracts.active > 0 then
        local activeListY = activeY + 25
        local activeHeight = panelY + panelH - activeListY - 20
        
        love.graphics.setScissor(panelX + 20, activeListY, panelW - 40, activeHeight)

        -- Active contracts list
        for i, contract in ipairs(contracts.active) do
            local itemY = activeListY + (i - 1) * 50 - activeContractsScrollOffset
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print(contract.name, panelX + 30, itemY, 0, 1.2, 1.2)
            
            -- Progress bar (overall)
            local barX = panelX + 250
            local barY = itemY + 5
            local barW = 200
            local barH = 10

            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", barX, barY, barW, barH)

            love.graphics.setColor(0.3, 0.9, 0.3)
            love.graphics.rectangle("fill", barX, barY, barW * (contract.progress / 100), barH)

            -- Secondary stage bar (download/compute/upload/store)
            local stage, stageFrac = computeContractStageProgress(contract.id, contract.type)
            local stageBarY = barY + barH + 6
            local stageBarH = 6

            love.graphics.setColor(0.25, 0.25, 0.28)
            love.graphics.rectangle("fill", barX, stageBarY, barW, stageBarH)

            -- color by stage
            if stage == "Download" then
                love.graphics.setColor(0.2, 0.6, 0.9)
            elseif stage == "Compute" or stage == "Store" then
                love.graphics.setColor(0.9, 0.6, 0.2)
            elseif stage == "Upload" then
                love.graphics.setColor(0.6, 0.8, 0.3)
            else
                love.graphics.setColor(0.6, 0.6, 0.6)
            end
            love.graphics.rectangle("fill", barX, stageBarY, barW * stageFrac, stageBarH)

            -- Stage label
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print(stage, barX + barW + 10, stageBarY - 2, 0, 0.7, 0.7)

            -- Tooltip when hovering over bars
            local mx, my = love.mouse.getPosition()
            if mx >= barX and mx <= barX + barW and my >= barY and my <= barY + barH then
                local text = string.format("Overall: %.1f%%", contract.progress)
                local tw = love.graphics.getFont():getWidth(text)
                local th = love.graphics.getFont():getHeight()
                local tx = math.min(mx + 12, panelX + panelW - tw - 10)
                local ty = barY - th - 8
                love.graphics.setColor(0, 0, 0, 0.8)
                love.graphics.rectangle("fill", tx - 6, ty - 4, tw + 12, th + 8, 4)
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(text, tx, ty)
            elseif mx >= barX and mx <= barX + barW and my >= stageBarY and my <= stageBarY + stageBarH then
                local stageText = string.format("Stage: %s (%.1f%%)", stage, stageFrac * 100)
                local overallText = string.format("Overall: %.1f%%", contract.progress)
                local tw1 = love.graphics.getFont():getWidth(stageText)
                local tw2 = love.graphics.getFont():getWidth(overallText)
                local tw = math.max(tw1, tw2)
                local th = love.graphics.getFont():getHeight()
                local tx = math.min(mx + 12, panelX + panelW - tw - 10)
                local ty = stageBarY - th - 12
                love.graphics.setColor(0, 0, 0, 0.8)
                love.graphics.rectangle("fill", tx - 6, ty - 4, tw + 12, th * 2 + 12, 4)
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(stageText, tx, ty)
                love.graphics.print(overallText, tx, ty + th + 6)
            end

            -- State and time info
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print("Overall", barX + barW + 10, itemY, 0, 0.7, 0.7)
            
            -- Payment and time remaining info
            local infoY = itemY + 18
            love.graphics.setColor(1, 1, 1)
            
            -- Show packet count and progress for work queue
            local status = WorkQueue.getContractProgress(workQueue, contract.id)
            if status.total > 0 then
                local timeText = string.format("%d/%d pkts", status.completed, status.total, status.total)
                if contract.type == "compute" then
                    if status.downloading > 0 then
                        timeText = timeText .. " | " .. status.downloading .. " downloading"
                    end
                    if status.processing > 0 then
                        timeText = timeText .. " | " .. status.processing .. " computing"
                    end
                    if status.uploading > 0 then
                        timeText = timeText .. " | " .. status.uploading .. " uploading"
                    end
                    love.graphics.print(timeText .. " | Pay: $" .. contract.payment, panelX + 30, infoY, 0, 1, 1)
                elseif contract.type == "store" then
                    -- Show different info for store contracts
                    local paymentText = string.format("$%.1f/s total ($%d)", contract.paymentPerSecond, contract.totalPayment)
                    love.graphics.print(timeText .. " | " .. paymentText, panelX + 30, infoY, 0, 1, 1)
                end
            end
        end
        
        love.graphics.setScissor() -- Reset clipping
    end
end

function Draw.GhostNode(variantId, x, y)
    local width = 100
    local height = Hardware.getDisplayHeight(variantId)
    
    -- Set ghost color based on variant (semi-transparent)
    local color = Hardware.getColor(variantId)
    love.graphics.setColor(color[1], color[2], color[3], 0.4)
    
    love.graphics.rectangle("fill", x - width/2, y - height/2, width, height, 5)
    
    -- Draw border
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.setLineWidth(2 / camera.zoom)
    love.graphics.rectangle("line", x - width/2, y - height/2, width, height, 5)
    
    -- Draw label
    love.graphics.setColor(0, 0, 0, 0.6)
    local scale = 1 / camera.zoom
    local variant = Hardware.getVariant(variantId)
    local displayName = variant and variant.displayName or "Unknown"
    love.graphics.print(displayName, x - width/2 + 5, y - height/2 + 5, 0, scale, scale)
end

function Draw.SaveLoadMenu()
    -- Darken background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Main panel
    local panelW = 600
    local panelH = 500
    local panelX = (love.graphics.getWidth() - panelW) / 2
    local panelY = (love.graphics.getHeight() - panelH) / 2
    
    love.graphics.setColor(0.15, 0.15, 0.18)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10)
    
    love.graphics.setColor(0.3, 0.6, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10)
    
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Save / Load", panelX + 20, panelY + 15, 0, 1.5, 1.5)
    
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Press L to close", panelX + panelW - 120, panelY + 20)
    
    -- Tab buttons
    local tabY = panelY + 50
    local tabW = 100
    local tabH = 30
    
    -- Load tab
    if saveLoadMenuTab == "load" then
        love.graphics.setColor(0.3, 0.6, 0.9)
    else
        love.graphics.setColor(0.25, 0.25, 0.3)
    end
    love.graphics.rectangle("fill", panelX + 20, tabY, tabW, tabH, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Save Games", panelX + 45, tabY + 8)
    
    -- Save tab
    if saveLoadMenuTab == "save" then
        love.graphics.setColor(0.3, 0.6, 0.9)
    else
        love.graphics.setColor(0.25, 0.25, 0.3)
    end
    love.graphics.rectangle("fill", panelX + 130, tabY, tabW, tabH, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Save", panelX + 155, tabY + 8)
    
    local contentY = tabY + tabH + 20
    
    if saveLoadMenuTab == "load" then
        -- Load tab - show list of save files
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print("Available Save Files:", panelX + 20, contentY)
        
        local saves = SaveLoad.getSaveFiles()
        local listY = contentY + 30
        local listH = panelH - (listY - panelY) - 20
        
        love.graphics.setScissor(panelX + 20, listY, panelW - 40, listH)
        
        if #saves == 0 then
            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.print("No save files found", panelX + 30, listY - saveLoadScrollOffset)
        else
            for i, save in ipairs(saves) do
                local itemY = listY + (i - 1) * 60 - saveLoadScrollOffset
                
                -- Save file box
                love.graphics.setColor(0.2, 0.2, 0.24)
                love.graphics.rectangle("fill", panelX + 20, itemY, panelW - 40, 50, 5)
                
                -- File name
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(save.name, panelX + 30, itemY + 5)
                
                -- File info
                love.graphics.setColor(0.7, 0.7, 0.7)
                local sizeKB = save.size / 1024
                local sizeText
                if sizeKB < 1 then
                    sizeText = string.format("%d bytes", save.size)
                else
                    sizeText = string.format("%.1fKB", sizeKB)
                end
                local dateText = os.date("%Y-%m-%d %H:%M:%S", save.modtime)
                love.graphics.print(string.format("%s | %s", sizeText, dateText), panelX + 30, itemY + 25, 0, 0.7, 0.7)
                
                -- Load button
                local loadbtnX = panelX + panelW - 110
                local loadbtnY = itemY + 10
                local loadbtnW = 70
                local loadbtnH = 30
                
                love.graphics.setColor(0.3, 0.9, 0.3)
                love.graphics.rectangle("fill", loadbtnX, loadbtnY, loadbtnW, loadbtnH, 3)
                
                love.graphics.setColor(1, 1, 1)
                love.graphics.print("Load", loadbtnX + 18, loadbtnY + 8)
                
                -- Store button bounds for click detection
                save.loadButtonBounds = {loadbtnX, loadbtnY, loadbtnW, loadbtnH}
                
                -- Save button to overwrite
                local btnX = panelX + panelW - 190
                local btnY = itemY + 10
                local btnW = 70
                local btnH = 30
                
                love.graphics.setColor(0.3, 0.9, 0.3)
                love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 3)
                
                love.graphics.setColor(1, 1, 1)
                love.graphics.print("Save", btnX + 18, btnY + 8)
                
                -- Store button bounds for click detection
                save.saveButtonBounds = {btnX, btnY, btnW, btnH}
            end
        end
        
        love.graphics.setScissor()
        
    else
        -- Save tab - text input for filename
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print("Save File Name:", panelX + 20, contentY)
        
        -- Text input box
        local inputY = contentY + 30
        love.graphics.setColor(0.2, 0.2, 0.24)
        love.graphics.rectangle("fill", panelX + 20, inputY, panelW - 40, 35, 5)
        
        love.graphics.setColor(1, 1, 1)
        local displayName = saveFilename
        if not displayName:match("%.sav$") and displayName ~= "" then
            displayName = displayName .. ".sav"
        end
        love.graphics.print(displayName, panelX + 30, inputY + 10)
        
        -- Cursor
        if math.floor(love.timer.getTime() * 2) % 2 == 0 then
            local textWidth = love.graphics.getFont():getWidth(saveFilename)
            love.graphics.line(panelX + 30 + textWidth + 2, inputY + 8, panelX + 30 + textWidth + 2, inputY + 27)
        end
        
        -- Save button
        local btnX = panelX + panelW / 2 - 40
        local btnY = inputY + 50
        local btnW = 80
        local btnH = 35
        
        if saveFilename ~= "" then
            love.graphics.setColor(0.3, 0.9, 0.3)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 3)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Save", btnX + 25, btnY + 10)
        
        -- Instructions
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("Type filename and press Enter or click Save", panelX + 20, inputY + 100, 0, 0.8, 0.8)
    end
end

function love.textinput(text)
    if showSaveLoadMenu and saveLoadMenuTab == "save" then
        saveFilename = saveFilename .. text
    end
end

return Draw