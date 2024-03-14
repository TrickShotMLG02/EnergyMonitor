--Loads the touchpoint and input APIs
shell.run("cp /EnergyMonitor/config/touchpoint.lua /touchpoint")
os.loadAPI("touchpoint")
shell.run("rm touchpoint")


local timeout = 5
local clientInfo = {
    id = "",
    name = "",
    type = "",
    data = {},
    lastPing = "",
}
local connectedClients = {}
local capacitors = {}
local energyMeters = {}
local connectedClientsCount = 0
local capacitorsCount = 0
local energyMetersCount = 0
local debugPrint = false


local pages = {}
local currentPageId = 1
local totalPageCount = 1
local currentPage = {}

currentPage = touchpoint.new(_G.touchpointLocation)
pages[currentPageId] = currentPage


local function totalEnergy()
    local total = 0
    for k, v in pairs(capacitors) do
        total = total + v.data.energy
    end
    return total
end

local function totalMaxEnergy()
    local total = 0
    for k, v in pairs(capacitors) do
        total = total + v.data.maxEnergy
    end
    return total
end

local function energyPercentage()
    return totalEnergy() / totalMaxEnergy() * 100
end

local function totalOutputRate()
    local total = 0
    for k, v in pairs(energyMeters) do
        if v.data.meterType == _G.MeterType.using then
            total = total + v.data.transfer
        end
    end
    return total
end

local function totalInputRate()
    local total = 0
    for k, v in pairs(energyMeters) do
        if v.data.meterType == _G.MeterType.providing then
            total = total + v.data.transfer
        end
    end
    return total
end

local function addClient(client) 
    -- add client to connectedClients
    if connectedClients[client.id] ~= nil then
        -- update client
        connectedClients[client.id] = client

        if (capacitors[client.id] ~= nil) then
            capacitors[client.id] = client
        elseif (energyMeters[client.id] ~= nil) then
            energyMeters[client.id] = client
        end
    else
        -- add client
        connectedClients[client.id] = client
        connectedClientsCount = connectedClientsCount + 1

        -- add clientid to respective list
        if client.type == _G.MessageDataPeripheral.EnergyMeter then
            energyMeters[client.id] = client
            energyMetersCount = energyMetersCount + 1
        elseif client.type == _G.MessageDataPeripheral.Capacitor then
            capacitors[client.id] = client
            capacitorsCount = capacitorsCount + 1
        end
    end
end

local function dropNotRespondingClients()
    -- remove client from connectedClients if lastPing is older than timeout
    for k, v in pairs(connectedClients) do
        if os.clock() - v.lastPing > timeout then
            connectedClients[k] = nil
            connectedClientsCount = connectedClientsCount - 1

            -- remove clientid from respective list
            if v.type == _G.MessageDataPeripheral.EnergyMeter then
                energyMeters[k] = nil
                energyMetersCount = energyMetersCount - 1
            elseif v.type == _G.MessageDataPeripheral.Capacitor then
                capacitors[k] = nil
                capacitorsCount = capacitorsCount - 1
            end
        end
    end
end

print("THIS IS THE SERVER PROGRAM!")

local function ping_clients()
    while true do
        term.clear()
        term.setCursorPos(1,1)


        -- Send ping to all connected clients
        print(os.clock())
        print("Sending a ping to all clients on channel: ".._G.modemChannel)

        local msg = _G.NewPingFromServer()
        _G.sendMessage(msg)


        -- Remove clients that are not responding
        dropNotRespondingClients()

        -- needed since otherwise no yield detected in parallel.waitForAll
        os.sleep(0.1)
    end
end

local function listen()
    -- Receive data from all connected clients
    while true do
        local clock = os.clock()
        local msg = _G.receiveMessage()
        local client = {}
        setmetatable(client, {__index = clientInfo})

        if msg.type == _G.MessageType.Update then
            -- Write to monitor

            -- extract data from message and setup clientInfo
            local data = msg.messageData.data
            client.id = data.id
            client.name = data.name
            client.data = data
            client.type = msg.messageData.peripheral
            client.lastPing = clock

            -- add client as connected
            addClient(client)

            if debugPrint then
                term.redirect(_G.controlMonitor)
                term.clear()
                term.setCursorPos(1,1)
                print(clock)
                print("Type: " .. _G.parsePeripheralType(msg.messageData.peripheral)) 
            end
            
            if msg.messageData.peripheral == _G.MessageDataPeripheral.EnergyMeter then
                if debugPrint then
                    print("Client: "..data.name)
                    print("ID: "..data.id)
                    print("Transfer: "..data.transfer)
                    print("Mode: "..data.mode)
                    print("Status: "..data.status)
                end
            elseif msg.messageData.peripheral == _G.MessageDataPeripheral.Capacitor then
                if debugPrint then
                    print("Client: "..data.name)
                    print("ID: "..data.id)
                    print("Energy: "..data.energy)
                    print("MaxEnergy: "..data.maxEnergy)
                    print("Filled: "..math.floor(data.energy / data.maxEnergy * 100) .. "%")
                    print("Status: "..data.status)
                end
            end

            if debugPrint then
                print("Connected clients: "..connectedClientsCount)
                print("Energy Meters: "..energyMetersCount)
                print("Capacitors: "..capacitorsCount)

                -- Write to terminal
                term.redirect(term.native())
            end
        end
    end
end

local function toggle(page, button)
    --toggle redstone output on front of computer
    page:toggleButton(button)
    rs.setOutput("front", not rs.getOutput("front"))
end

local function setupMonitor() 
    local monWidth,monHeight = _G.controlMonitor.getSize()
    monWidth = monWidth
    monHeight = monHeight - 1
    local btnOffsetBorder = 2


    ------------------------------------
    -- Total Capacitor Energy Display --
    ------------------------------------

    local capWidth = 30
    local capHeight = 2

    local capMinX = btnOffsetBorder
    local capMinY = btnOffsetBorder
    local capMaxX = capWidth + capMinX
    local capMaxY = capHeight + capMinY
    local lh = 3
    
    currentPage:add("Energy Stored:", function() end, capMinX, capMinY, capMaxX, capMaxY, colors.red, colors.lime)
    currentPage:add("Energy", function() end, capMinX, capMinY + lh, capMaxX, capMaxY + lh, colors.red, colors.lime)
    print(totalPageCount)



    ----------------------------------------
    -- Total EnergyMeter Transfer Display --
    ----------------------------------------

    local trnsfWidth = 30
    local trnsfHeight = 2

    local trnsfMinX = monWidth - btnOffsetBorder - trnsfWidth
    local trnsfMinY = btnOffsetBorder
    local trnsfMaxX = monWidth - btnOffsetBorder
    local trnsfMaxY = trnsfHeight + trnsfMinY
    local lh = 3

    currentPage:add("OutputRate", function() end, trnsfMinX, trnsfMinY, trnsfMaxX, trnsfMaxY, colors.red, colors.lime)
    currentPage:add("InputRate", function() end, trnsfMinX, trnsfMinY + lh, trnsfMaxX, trnsfMaxY + lh, colors.red, colors.lime)
    print(totalPageCount)




    -------------------------------
    -- EnergyMeter Display Cells --
    -------------------------------

    local meterCount = energyMetersCount
    local neededPages = math.ceil(meterCount / 4)   -- 4 meters per page  (ceiled)
    --SETUP PAGES and add them to page table. Also call setupMonitor in interval since the amount of cells might change
    --Buttons next/prev used to inc/dec pageIndex

    local vertOffset = capMaxY + lh + 4
    local horiOffset = 5

    ---------------
    -- DISPLAY 1 --
    ---------------

    local dpWidth = 15
    local dpHeight = 2

    dp1MinX1 = btnOffsetBorder
    dp1MinY1 = vertOffset
    dp1MaxX1 = dpWidth + dp1MinX1
    dp1MaxY1 = dpHeight + dp1MinY1

    dp1MinX2 = dp1MinX1
    dp1MinY2 = dp1MaxY1 + 1
    dp1MaxX2 = dpWidth + dp1MinX2
    dp1MaxY2 = dpHeight + dp1MinY2

    dp1MinX3 = dp1MinX2
    dp1MinY3 = dp1MaxY2 + 1
    dp1MaxX3 = dpWidth + dp1MinX3
    dp1MaxY3 = dpHeight + dp1MinY3

    currentPage:add("Display1Name", function() end, dp1MinX1, dp1MinY1, dp1MaxX1, dp1MaxY1, colors.red, colors.lime)
    currentPage:add("Display1Rate", function() end, dp1MinX2, dp1MinY2, dp1MaxX2, dp1MaxY2, colors.red, colors.lime)
    currentPage:add("Display1State", function() end, dp1MinX3, dp1MinY3, dp1MaxX3, dp1MaxY3, colors.red, colors.lime)


    ---------------
    -- DISPLAY 2 --
    ---------------

    dp2MinX1 = dp1MaxX1 + horiOffset
    dp2MinY1 = vertOffset
    dp2MaxX1 = dpWidth + dp2MinX1
    dp2MaxY1 = dpHeight + dp2MinY1

    dp2MinX2 = dp2MinX1
    dp2MinY2 = dp2MaxY1 + 1
    dp2MaxX2 = dpWidth + dp2MinX2
    dp2MaxY2 = dpHeight + dp2MinY2

    dp2MinX3 = dp2MinX2
    dp2MinY3 = dp2MaxY2 + 1
    dp2MaxX3 = dpWidth + dp2MinX3
    dp2MaxY3 = dpHeight + dp2MinY3

    currentPage:add("Display2Name", function() end, dp2MinX1, dp2MinY1, dp2MaxX1, dp2MaxY1, colors.red, colors.lime)
    currentPage:add("Display2Rate", function() end, dp2MinX2, dp2MinY2, dp2MaxX2, dp2MaxY2, colors.red, colors.lime)
    currentPage:add("Display2State", function() end, dp2MinX3, dp2MinY3, dp2MaxX3, dp2MaxY3, colors.red, colors.lime)


    ---------------
    -- DISPLAY 3 --
    ---------------

    dp3MinX1 = dp2MaxX1 + horiOffset
    dp3MinY1 = vertOffset
    dp3MaxX1 = dpWidth + dp3MinX1
    dp3MaxY1 = dpHeight + dp3MinY1

    dp3MinX2 = dp3MinX1
    dp3MinY2 = dp3MaxY1 + 1
    dp3MaxX2 = dpWidth + dp3MinX2
    dp3MaxY2 = dpHeight + dp3MinY2

    dp3MinX3 = dp3MinX2
    dp3MinY3 = dp3MaxY2 + 1
    dp3MaxX3 = dpWidth + dp3MinX3
    dp3MaxY3 = dpHeight + dp3MinY3

    currentPage:add("Display3Name", function() end, dp3MinX1, dp3MinY1, dp3MaxX1, dp3MaxY1, colors.red, colors.lime)
    currentPage:add("Display3Rate", function() end, dp3MinX2, dp3MinY2, dp3MaxX2, dp3MaxY2, colors.red, colors.lime)
    currentPage:add("Display3State", function() end, dp3MinX3, dp3MinY3, dp3MaxX3, dp3MaxY3, colors.red, colors.lime)


    ---------------
    -- DISPLAY 4 --
    ---------------

    dp4MinX1 = dp3MaxX1 + horiOffset
    dp4MinY1 = vertOffset
    dp4MaxX1 = dpWidth + dp4MinX1
    dp4MaxY1 = dpHeight + dp4MinY1

    dp4MinX2 = dp4MinX1
    dp4MinY2 = dp4MaxY1 + 1
    dp4MaxX2 = dpWidth + dp4MinX2
    dp4MaxY2 = dpHeight + dp4MinY2

    dp4MinX3 = dp4MinX2
    dp4MinY3 = dp4MaxY2 + 1
    dp4MaxX3 = dpWidth + dp4MinX3
    dp4MaxY3 = dpHeight + dp4MinY3

    currentPage:add("Display4Name", function() end, dp4MinX1, dp4MinY1, dp4MaxX1, dp4MaxY1, colors.red, colors.lime)
    currentPage:add("Display4Rate", function() end, dp4MinX2, dp4MinY2, dp4MaxX2, dp4MaxY2, colors.red, colors.lime)
    currentPage:add("Display4State", function() end, dp4MinX3, dp4MinY3, dp4MaxX3, dp4MaxY3, colors.red, colors.lime)




    ---------------------------------------
    -- footer buttons offsets/dimensions --
    ---------------------------------------

    local btnWidth = 5
    local btnHeight = 0

    pMinX = btnOffsetBorder
    pMinY = monHeight - btnHeight
    pMaxX = btnWidth + btnOffsetBorder
    pMaxY = monHeight

    nMinX = monWidth - btnOffsetBorder - btnWidth
    nMinY = monHeight - btnHeight
    nMaxX = monWidth - btnOffsetBorder
    nMaxY = monHeight
    

    local lblWidth = 11
    local lblHeight = 0

    lMinX = (monWidth - lblWidth) / 2
    lMinY = monHeight - lblHeight
    lMaxX = (monWidth + lblWidth) / 2
    lMaxY = monHeight
    
    --# coordinates are minX, minY, maxX, maxY. The button will be drawn from (minX, minY) to (maxX, maxY)
    currentPage:add("Prev", function() toggle(currentPage, "Prev") end, pMinX, pMinY, pMaxX, pMaxY, colors.red, colors.lime)
    currentPage:add("Next", function() toggle(currentPage, "Next") end, nMinX, nMinY, nMaxX, nMaxY, colors.red, colors.lime)
    currentPage:add("Page " .. currentPageId .. "/" .. totalPageCount, function() end, lMinX, lMinY, lMaxX, lMaxY, colors.red, colors.lime)

    
    currentPage:draw()
end


local function updateMonitorValues()
    while true do

        currentPage:setLabel("Energy", _G.numberToEnergyUnit(totalEnergy()) .. "/" .. _G.numberToEnergyUnit(totalMaxEnergy()) .. " (" .. _G.formatDecimals(energyPercentage(), 1) .. "%)")
        currentPage:setLabel("OutputRate", "Out: ".. _G.numberToEnergyUnit(totalOutputRate()) .. "/t")
        currentPage:setLabel("InputRate", "In: ".. _G.numberToEnergyUnit(totalInputRate()) .. "/t")
        os.sleep(0.1)
    end
end

local function touchListener()
    currentPage:run()
end




---------------------------------------
-- ACTUAL SERVER PROGRAM STARTS HERE --
---------------------------------------

-- setup monitor gui
setupMonitor()

-- Run the pinger and the listener and monitor updaters in parallel
parallel.waitForAll(listen, ping_clients, updateMonitorValues, touchListener)


-------------------------------------
-- ACTUAL SERVER PROGRAM ENDS HERE --
-------------------------------------