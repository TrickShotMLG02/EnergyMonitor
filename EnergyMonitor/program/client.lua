print("THIS IS THE CLIENT PROGRAM!")
print("Waiting for server ping...")

while true do
    -- Receive ping from server
    local msg = _G.receiveMessage({
        type = _G.MessageType.Ping,
        sender = _G.Sender.Server,
        recipient = _G.Sender.Client
    })
    if msg.type == _G.MessageType.Ping and msg.sender == _G.Sender.Server then
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
        if _G.transferrer ~= nil then
            -- Client is a transferrer
            peripheral = _G.MessageDataPeripheral.Transfer
            -- use peripheral data as transfer data structure
            setmetatable(peripheralData,{__index = _G.TransferData})
            peripheralData.name = os.getComputerLabel()
            peripheralData.id = tostring(_G.transferrer.id)
            peripheralData.transferIn = _G.transferrer:transferRateInput()
            peripheralData.transferOut = _G.transferrer:transferRateOutput()
            peripheralData.transferType = _G.transferType
            -- TODO: set appropriate status (DISCONNECTED when no energy is transferred)
            peripheralData.status = "N/A"
            
            -- print data structure to computer screen
            _G.printEnergyTransferData(_G.transferrer)
        elseif _G.capacitor ~= nil then
            -- Client is a capacitor
            peripheral = _G.MessageDataPeripheral.Capacitor
            -- use peripheral data as capacitor data structure
            setmetatable(peripheralData,{__index = _G.CapacitorData})
            peripheralData.name = os.getComputerLabel()
            peripheralData.id = tostring(_G.capacitor.id)
            peripheralData.energy = _G.capacitor:energy()
            peripheralData.maxEnergy = _G.capacitor:capacity()
            peripheralData.status = "N/A"

            -- print data structure to computer screen
            _G.printEnergyStorageData(_G.capacitor)
        end

        if peripheral ~= nil then
            data = {
                peripheral = peripheral,
                peripheralData = peripheralData
            }

            -- send data as update to server
            local msg = _G.NewUpdateToServer(data)
            _G.sendMessage(msg)
        end
    end
end
