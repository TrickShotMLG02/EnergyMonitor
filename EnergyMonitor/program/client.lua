-- EnergyMonitor client program.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.

print("THIS IS THE CLIENT PROGRAM!")
print("Waiting for server ping...")
print("Listening on modem channel: " .. tostring(_G.modemChannel))

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

local function printPeripheralData(wrapper, wrapperPrintMethod, fallbackPrintFunction)
    if wrapper ~= nil and type(wrapper[wrapperPrintMethod]) == "function" then
        local success = pcall(function()
            wrapper[wrapperPrintMethod](wrapper)
        end)

        if success then
            return
        end
    end

    fallbackPrintFunction(wrapper)
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

    local peripheralData = {}
    setmetatable(peripheralData,{__index = _G.TransferData})
    peripheralData.name = getPeripheralDisplayName(wrapper)
    peripheralData.id = tostring(wrapper.id)
    peripheralData.transferIn = wrapper:transferRateInput()
    peripheralData.transferOut = wrapper:transferRateOutput()
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
            printPeripheralData(_G.transferrer, "printEnergyTransferData", _G.printEnergyTransferData)
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
