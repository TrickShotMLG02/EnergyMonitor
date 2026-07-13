-- EnergyMonitor server program.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.

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
local transferrers = {}
local connectedClientsCount = 0
local capacitorsCount = 0
local transferrersCount = 0
local debugPrint = false

-- compute total energy stored from all capacitors
local function totalEnergy()
    local total = 0
    for k, v in pairs(capacitors) do
        total = total + _G.defaultNan(v.data.energy, 0)
    end
    return total
end

-- compute maximal energy storable from all capacitors
local function totalMaxEnergy()
    local total = 0
    for k, v in pairs(capacitors) do
        total = total + _G.defaultNan(v.data.maxEnergy, 0)
    end
    return total
end

-- compute fill level of all capacitors
local function energyPercentage()
    return _G.defaultNil(_G.defaultNan(totalEnergy() / totalMaxEnergy(), 0), 0) * 100
end

-- compute total output transfer rate of all transferrers
local function totalOutputRate()
    local total = 0
    for k, v in pairs(transferrers) do
        if v.data.transferType == _G.TransferType.Output or v.data.transferType == _G.TransferType.Both then
            total = total + v.data.transferOut
        end
    end
    return total
end

-- compute total input transfer rate of all transferrers
local function totalInputRate()
    local total = 0
    for k, v in pairs(transferrers) do
        if v.data.transferType == _G.TransferType.Input or v.data.transferType == _G.TransferType.Both then
            total = total + v.data.transferIn
        end
    end
    return total
end

-- add new client to the connected ones (either transferrer or capacitor)
local function addClient(client) 
    -- add client to connectedClients
    if connectedClients[client.id] ~= nil then
        -- update client
        connectedClients[client.id] = client

        if (capacitors[client.id] ~= nil) then
            capacitors[client.id] = client
        elseif (transferrers[client.id] ~= nil) then
            transferrers[client.id] = client
        end
    else
        -- add client
        connectedClients[client.id] = client
        connectedClientsCount = connectedClientsCount + 1

        -- add clientid to respective list
        if client.type == _G.MessageDataPeripheral.Transfer then
            transferrers[client.id] = client
            transferrersCount = transferrersCount + 1
        elseif client.type == _G.MessageDataPeripheral.Capacitor then
            capacitors[client.id] = client
            capacitorsCount = capacitorsCount + 1
        end
    end
end

local function updateClientFromPeripheralData(peripheralType, data, clock)
    if type(data) ~= "table" or data.id == nil then
        return
    end

    if peripheralType == _G.MessageDataPeripheral.Transfer then
        data.transferIn = tonumber(data.transferIn) or 0
        data.transferOut = tonumber(data.transferOut) or 0
        data.transferType = data.transferType or _G.TransferType.Both
    end

    local client = {}
    setmetatable(client, {__index = clientInfo})

    client.id = data.id
    client.name = data.name
    client.data = data
    client.type = peripheralType
    client.lastPing = clock

    addClient(client)

    if debugPrint then
        term.redirect(_G.controlMonitor)
        term.clear()
        term.setCursorPos(1,1)
        print(clock)
        print("Type: " .. _G.parsePeripheralType(peripheralType))
    end

    if peripheralType == _G.MessageDataPeripheral.Transfer then
        debugOutput("Client: "..data.name)
        debugOutput("ID: "..data.id)
        debugOutput("Transfer In: "..data.transferIn)
        debugOutput("Transfer Out: "..data.transferOut)
        debugOutput("Status: "..data.status)
    elseif peripheralType == _G.MessageDataPeripheral.Capacitor then
        debugOutput("Client: "..data.name)
        debugOutput("ID: "..data.id)
        debugOutput("Energy: "..data.energy)
        debugOutput("MaxEnergy: "..data.maxEnergy)
        debugOutput("Filled: "..math.floor(data.energy / data.maxEnergy * 100) .. "%")
        debugOutput("Status: "..data.status)
    end
end

-- remove all clients that did not respond in last x seconds
local function dropNotRespondingClients()
    -- remove client from connectedClients if lastPing is older than timeout
    for k, v in pairs(connectedClients) do
        if os.clock() - v.lastPing > timeout then
            connectedClients[k] = nil
            connectedClientsCount = connectedClientsCount - 1

            -- remove clientid from respective list
            if v.type == _G.MessageDataPeripheral.Transfer then
                transferrers[k] = nil
                transferrersCount = transferrersCount - 1
            elseif v.type == _G.MessageDataPeripheral.Capacitor then
                capacitors[k] = nil
                capacitorsCount = capacitorsCount - 1
            end
        end
    end
end

-- send ping to all clients asking for updated values
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
        os.sleep(_G.pingInterval)
    end
end

-- listen for incoming updated datastructures from clients
local function listen()
    -- Receive data from all connected clients
    while true do
        local clock = os.clock()
        local msg = _G.receiveMessage({
            type = _G.MessageType.Update,
            sender = _G.Sender.Client,
            recipient = _G.Sender.Server
        })
        if msg.data ~= nil then
            if type(msg.data.peripheralDataList) == "table" then
                for _, data in ipairs(msg.data.peripheralDataList) do
                    if type(data) == "table" then
                        updateClientFromPeripheralData(msg.data.peripheral, data, clock)
                    end
                end
            elseif msg.data.peripheralData ~= nil then
                updateClientFromPeripheralData(msg.data.peripheral, msg.data.peripheralData, clock)
            end

            -- debug print internal state of data structures
            debugOutput("Connected clients: "..connectedClientsCount)
            debugOutput("Energy Transferrers: "..transferrersCount)
            debugOutput("Capacitors: "..capacitorsCount)

            debugOutput("Total In: " ..totalInputRate())
            debugOutput("Total Out: " ..totalOutputRate())

            -- Write to terminal
            term.redirect(term.native())
        end
    end
end

-- send merged data structure to all monitors
local function sendMonitorData()
    while true do
        -- create new monitor data datastructure to save all neccessary information
        local monitorData = {}
        setmetatable(monitorData, {__index = _G.MonitorData})

        -- retrieve/calculate all values and store them in our data object 
        monitorData.capacitors = capacitors
        monitorData.capacitorsCount = capacitorsCount
        monitorData.transferrers = transferrers
        monitorData.transferrersCount = transferrersCount
        monitorData.storedEnergy = totalEnergy()
        monitorData.maxEnergy = totalMaxEnergy()
        monitorData.energyPercentage = energyPercentage()
        monitorData.inputRate = totalInputRate()
        monitorData.outputRate = totalOutputRate()

        -- send data to all monitors
        local msg = _G.NewUpdateToMonitor(monitorData)
        _G.sendMessage(msg)

        -- needed since otherwise no yield detected in parallel.waitForAll
        os.sleep(0.1)
    end
end

---------------------------------------
-- ACTUAL SERVER PROGRAM STARTS HERE --
---------------------------------------
print("THIS IS THE SERVER PROGRAM!")

-- Run the pinger and the listener and monitor updaters in parallel
parallel.waitForAll(listen, ping_clients, sendMonitorData)

-------------------------------------
-- ACTUAL SERVER PROGRAM ENDS HERE --
-------------------------------------
