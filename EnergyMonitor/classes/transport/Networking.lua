local PROTOCOL = "EnergyMonitor"
local PROTOCOL_VERSION = 1

_G.MessageType = {
    Ping = 0,          -- Sent to check if the client is still alive
    Handshake = 1,     -- Sent as a handshake to establish a connection from client to server
    Update = 2,        -- Sent to update values to the server from the client
    Monitor = 3,       -- Sent to the monitor to update the monitor
    Control = 4,       -- Sent to the client to control its behaviour
}

-- type that is specified in a packet as sender
_G.Sender = {
    Server = 0,
    Client = 1,
    Monitor = 2
}

-- type of a transferrer specifying if it is measuring input/output or both
_G.TransferType = {
    Input = "input",
    Output = "output",
    Both = "both",
}

-- Payload for a transferrer update packet
_G.TransferData = {
    name = "",
    id = "",
    transferIn = 0,
    transferOut = 0,
    status = "",
    transferType = ""
}

-- Payload for a capacitor update packet
_G.CapacitorData = {
    name = "",
    id = "",
    energy = -1,
    maxEnergy = -1,
    status = "",
}

-- Payload for a monitor update packet
_G.MonitorData = {
    capacitors = {},
    capacitorsCount = -1,
    transferrers = {},
    transferrersCount = -1,
    storedEnergy = -1,
    maxEnergy = -1,
    energyPercentage = -1,
    inputRate = -1,
    outputRate = -1,
}

-- Payload that will be used in the future to perform certain actions on a specific peripheral
--TODO: NOT IN USE RIGHT NOW
_G.ControlData = {
    peripheral = {},
}

-- Peripheral type used in client update packets
_G.MessageDataPeripheral = {
    Capacitor = 0,
    Transfer = 1,
}

local function newMessage(messageType, sender, recipient, data)
    return {
        protocol = PROTOCOL,
        version = PROTOCOL_VERSION,
        type = messageType,
        sender = sender,
        recipient = recipient,
        computerId = os.getComputerID(),
        data = data or {}
    }
end

-- function that creates a handshake message from a client
function _G.NewHandshakeToServer(data)
    return newMessage(_G.MessageType.Handshake, _G.Sender.Client, _G.Sender.Server, data)
end

-- function that creates a handshake message from the server
function _G.NewHandshakeFromServer(data)
    return newMessage(_G.MessageType.Handshake, _G.Sender.Server, _G.Sender.Client, data)
end



-- function that will create a new message with an update from a client
function _G.NewUpdateToServer(data)
    return newMessage(_G.MessageType.Update, _G.Sender.Client, _G.Sender.Server, data)
end

-- function that will create a new message with an update from the server
function _G.NewUpdateFromServer(data)
    return newMessage(_G.MessageType.Update, _G.Sender.Server, nil, data)
end


-- function that will wrap some data into a packet for monitor display
function _G.NewUpdateToMonitor(data)
    return newMessage(_G.MessageType.Monitor, _G.Sender.Server, _G.Sender.Monitor, data)
end


-- function that will create a new ping message from client that is ready to be sent
function _G.NewPingToServer()
    return newMessage(_G.MessageType.Ping, _G.Sender.Client, _G.Sender.Server, {})
end

-- function that will create a new ping message from server that is ready to be sent
function _G.NewPingFromServer()
    return newMessage(_G.MessageType.Ping, _G.Sender.Server, _G.Sender.Client, {})
end



-- function that will return the string for a sender
function _G.parseSender(sender)
    if sender == _G.Sender.Server then
        return "Server"
    elseif sender == _G.Sender.Client then
        return "Client"
    elseif sender == _G.Sender.Monitor then
        return "Monitor"
    else
        return "Unknown"
    end
end

-- function that will return the string for a message type
function _G.parseType(type)
    if type == _G.MessageType.Handshake then
        return "Handshake"
    elseif type == _G.MessageType.Update then
        return "Update"
    elseif type == _G.MessageType.Ping then
        return "Ping"
    elseif type == _G.MessageType.Control then
        return "Control"
    elseif type == _G.MessageType.Monitor then
        return "Monitor"
    else
        return "Unknown"
    end
end

-- function that will return the string for a peripheral type
function _G.parsePeripheralType(type)
    if type == _G.MessageDataPeripheral.Capacitor then
        return "Capacitor"
    elseif type == _G.MessageDataPeripheral.Transfer then
        return "Transferrer"
    else
        return "Unknown"
    end
end

-- function that will return the string for a TransferType
function _G.parseTransferType(type)
    if type == _G.TransferType.Input then
        return "Input"
    elseif type == _G.TransferType.Output then
        return "Output"
    elseif type == _G.TransferType.Both then
        return "Input/Output"
    else
        return "Unknown"
    end
end

-- function that is used to serialize a message
local function serializeMessage(message)
    return textutils.serialise(message)
end

-- function that is used to deserialize a message back to its original data structure
local function deserializeMessage(serializedMessage)
    if type(serializedMessage) ~= "string" then
        return nil
    end

    local success, message = pcall(textutils.unserialise, serializedMessage)
    if not success then
        return nil
    end

    if type(message) ~= "table" then
        return nil
    end

    return message
end

local function normalizeMessage(message)
    if type(message) ~= "table" then
        return message
    end

    if message.data == nil and message.messageData ~= nil then
        message.data = message.messageData
        message.messageData = nil
    end

    -- Legacy client update payload: { peripheral = ..., data = peripheralData }
    if message.type == _G.MessageType.Update
        and type(message.data) == "table"
        and message.data.peripheralData == nil
        and message.data.data ~= nil then
        message.data.peripheralData = message.data.data
        message.data.data = nil
    end

    -- Legacy monitor payload: { peripheral = -1, data = monitorData }
    if message.type == _G.MessageType.Monitor
        and type(message.data) == "table"
        and message.data.data ~= nil
        and message.data.storedEnergy == nil then
        message.data = message.data.data
    end

    return message
end

local function valueMatches(value, expected)
    if expected == nil then
        return true
    end

    if type(expected) == "table" then
        for _, expectedValue in pairs(expected) do
            if value == expectedValue then
                return true
            end
        end
        return false
    end

    return value == expected
end

function _G.isValidMessage(message)
    return type(message) == "table"
        and message.protocol == PROTOCOL
        and message.version == PROTOCOL_VERSION
        and valueMatches(message.type, {
            _G.MessageType.Ping,
            _G.MessageType.Handshake,
            _G.MessageType.Update,
            _G.MessageType.Monitor,
            _G.MessageType.Control
        })
        and valueMatches(message.sender, {
            _G.Sender.Server,
            _G.Sender.Client,
            _G.Sender.Monitor
        })
        and message.data ~= nil
end

local function matchesFilter(message, filter)
    if filter == nil then
        return true
    end

    return valueMatches(message.type, filter.type or filter.types)
        and valueMatches(message.sender, filter.sender or filter.senders)
        and valueMatches(message.recipient, filter.recipient or filter.recipients)
end


-- function that is used to serialize and transmit a message object over the modem
function _G.sendMessage(message, channel)
    if type(_G.wirelessModem) ~= "table" or type(_G.wirelessModem.transmit) ~= "function" then
        error("Wireless modem is not available")
    end

    if type(message) ~= "table" then
        error("Cannot send invalid message")
    end

    message.protocol = message.protocol or PROTOCOL
    message.version = message.version or PROTOCOL_VERSION
    message.computerId = message.computerId or os.getComputerID()
    normalizeMessage(message)

    if not _G.isValidMessage(message) then
        error("Cannot send malformed EnergyMonitor message")
    end

    local targetChannel = channel or _G.modemChannel
    local msg = serializeMessage(message)
    _G.wirelessModem.transmit(targetChannel, _G.modemChannel, msg)
end

-- function that is used to receive a transmitted message over the modem and deserialize it.
-- Optional filter fields: type/types, sender/senders, recipient/recipients.
function _G.receiveMessage(filter)
    while true do
        local event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")

        if senderChannel == _G.modemChannel then
            local deserializedMessage = normalizeMessage(deserializeMessage(message))

            if _G.isValidMessage(deserializedMessage) and matchesFilter(deserializedMessage, filter) then
                return deserializedMessage, {
                    modemSide = modemSide,
                    senderChannel = senderChannel,
                    replyChannel = replyChannel,
                    senderDistance = senderDistance
                }
            end
        end
    end
end
