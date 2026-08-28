-- EnergyMonitor client program.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.

print("THIS IS THE CLIENT PROGRAM!")
print("Waiting for server ping...")
print("Listening on modem channel: " .. tostring(_G.modemChannel))

local previousTransferEnergy = nil
local previousTransferSampleTime = nil

local function printNoPeripheralWarning()
    print("WARNING: No supported energy peripheral is attached.")
    print("Attach a configured capacitor or transfer device.")
end

local function getPeripheralDisplayName(wrapper)
    local computerLabel = os.getComputerLabel()

    if wrapper ~= nil and type(wrapper.displayName) == "function" then
        local success, name = pcall(function()
            return wrapper:displayName(computerLabel)
        end)

        if success and type(name) == "string" and name ~= "" then
            return name
        end
    end

    return computerLabel
end

local function printPeripheralData(wrapper, wrapperPrintMethod, fallbackPrintFunction, data)
    if wrapper ~= nil and type(wrapper[wrapperPrintMethod]) == "function" then
        local success = pcall(function()
            wrapper[wrapperPrintMethod](wrapper)
        end)

        if success then
            return
        end
    end

    if data ~= nil and fallbackPrintFunction == _G.printEnergyTransferData then
        print("Name: "..tostring(data.name))
        print("ID: "..tostring(data.id))
        print("Transfer Type: "..tostring(data.transferType))
        print("Transfer Rate Input: "..tostring(data.transferIn))
        print("Transfer Rate Output: "..tostring(data.transferOut))
        return
    end

    fallbackPrintFunction(wrapper)
end

local function readFallbackTransferRates(wrapper, currentTime)
    if wrapper == nil or type(wrapper.energy) ~= "function" then
        return 0, 0
    end

    local success, currentEnergy = pcall(function()
        return wrapper:energy()
    end)
    currentEnergy = success and tonumber(currentEnergy) or nil

    if currentEnergy == nil then
        return 0, 0
    end

    local inputRate = 0
    local outputRate = 0
    if previousTransferEnergy ~= nil and previousTransferSampleTime ~= nil then
        local elapsedTicks = (currentTime - previousTransferSampleTime) * 20
        if elapsedTicks > 0 then
            local ratePerTick = (currentEnergy - previousTransferEnergy) / elapsedTicks
            if ratePerTick > 0 then
                inputRate = ratePerTick
            elseif ratePerTick < 0 then
                outputRate = math.abs(ratePerTick)
            end
        end
    end

    previousTransferEnergy = currentEnergy
    previousTransferSampleTime = currentTime
    return inputRate, outputRate
end

local function readTransferRate(wrapper, methodName, fallbackRate)
    if wrapper ~= nil and type(wrapper[methodName]) == "function" then
        local success, rate = pcall(function()
            return wrapper[methodName](wrapper)
        end)

        rate = success and tonumber(rate) or nil
        if rate ~= nil then
            return rate
        end
    end

    return fallbackRate
end

local function createTransferData(wrapper)
    local computerLabel = os.getComputerLabel()

    if wrapper ~= nil and type(wrapper.peripheralDataList) == "function" then
        local success, dataList = pcall(function()
            return wrapper:peripheralDataList(computerLabel)
        end)

        if success and type(dataList) == "table" then
            return nil, dataList
        end
    end

    local currentTime = os.clock()
    local fallbackInputRate, fallbackOutputRate = readFallbackTransferRates(wrapper, currentTime)

    local peripheralData = {}
    setmetatable(peripheralData,{__index = _G.TransferData})
    peripheralData.name = getPeripheralDisplayName(wrapper)
    peripheralData.id = tostring(wrapper.id)
    peripheralData.transferIn = readTransferRate(wrapper, "transferRateInput", fallbackInputRate)
    peripheralData.transferOut = readTransferRate(wrapper, "transferRateOutput", fallbackOutputRate)
    peripheralData.transferType = _G.transferType
    -- TODO: set appropriate status (DISCONNECTED when no energy is transferred)
    peripheralData.status = "N/A"

    return peripheralData, nil
end

while true do
    -- Receive ping from server
    local msg = _G.receiveMessage({
        type = _G.MessageType.Ping,
        sender = _G.Sender.Server,
        recipient = _G.Sender.Client
    }, 5)

    if msg == nil then
        term.clear()
        term.setCursorPos(1,1)
        print("THIS IS THE CLIENT PROGRAM!")
        print("Waiting for server ping...")
        print("Listening on modem channel: " .. tostring(_G.modemChannel))
        print("No matching ping received in the last 5 seconds.")
        print("Enable debug = 1 in options.txt to see ignored packets.")
    elseif msg.type == _G.MessageType.Ping and msg.sender == _G.Sender.Server then
        term.clear()
        term.setCursorPos(1,1)

        print(os.clock())
        debugOutput("I just received a message of type: ".. _G.parseType(msg.type))
        debugOutput("The message was sent from: ".. _G.parseSender(msg.sender))
        debugOutput("The message was: "..textutils.serialise(msg.data))
        debugOutput()

        -- send updated Data to server
        local data = {}

        local peripheral = nil
        local peripheralData = {}
        local peripheralDataList = nil
        if _G.transferrer ~= nil then
            -- Client is a transferrer
            peripheral = _G.MessageDataPeripheral.Transfer
            peripheralData, peripheralDataList = createTransferData(_G.transferrer)
            
            -- print data structure to computer screen
            printPeripheralData(_G.transferrer, "printEnergyTransferData", _G.printEnergyTransferData, peripheralData)
        elseif _G.capacitor ~= nil then
            -- Client is a capacitor
            peripheral = _G.MessageDataPeripheral.Capacitor
            -- use peripheral data as capacitor data structure
            setmetatable(peripheralData,{__index = _G.CapacitorData})
            peripheralData.name = getPeripheralDisplayName(_G.capacitor)
            peripheralData.id = tostring(_G.capacitor.id)
            peripheralData.energy = _G.capacitor:energy()
            peripheralData.maxEnergy = _G.capacitor:capacity()
            peripheralData.status = "N/A"

            -- print data structure to computer screen
            printPeripheralData(_G.capacitor, "printEnergyStorageData", _G.printEnergyStorageData)
        end

        if peripheral ~= nil then
            data = {
                peripheral = peripheral,
                peripheralData = peripheralData,
                peripheralDataList = peripheralDataList
            }

            -- send data as update to server
            local msg = _G.NewUpdateToServer(data)
            _G.sendMessage(msg)
        else
            printNoPeripheralWarning()
        end
    end
end
