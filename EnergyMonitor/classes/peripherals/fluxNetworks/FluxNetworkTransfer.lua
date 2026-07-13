-- EnergyMonitor Flux Networks transfer wrapper.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- Supports FNCCT flux_plug and flux_point peripherals.

local FluxNetworkTransfer = setmetatable({
    displayName = function(self, computerLabel)
        local displayName = _G.callPeripheralMethod(self.id, "getDisplayName", nil)
        if type(displayName) == "string" and displayName ~= "" then
            return displayName
        end

        return computerLabel
    end,

    transferRateInput = function(self)
        if self.deviceType ~= "plug" then
            return 0
        end

        if self.transferType == _G.TransferType.Input or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getTransfer", 0)
        end

        return 0
    end,

    transferRateOutput = function(self)
        if self.deviceType ~= "point" then
            return 0
        end

        if self.transferType == _G.TransferType.Output or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getTransfer", 0)
        end

        return 0
    end,

    transferRateLimit = function(self)
        return _G.callPeripheralMethod(self.id, "getTransferLimit", 0)
    end,

    effectiveTransferRateLimit = function(self)
        return _G.callPeripheralMethod(self.id, "getEffectiveTransferLimit", 0)
    end
}, {__index = EnergyTransfer})

function _G.newFluxNetworkTransfer(name, id, side, type, transferType, deviceType)
    print("Creating new FluxNetworkTransfer")
    local transfer = {}
    setmetatable(transfer, {__index = FluxNetworkTransfer})

    if id == nil then
        print("MISSING wrapped peripheral object. This is going to break!")
    end

    transfer.name = name
    transfer.id = id
    transfer.side = side
    transfer.type = type
    transfer.transferType = transferType
    transfer.deviceType = deviceType

    return transfer
end

function FluxNetworkTransfer:printEnergyTransferData()
    print("Name: "..self.name)
    print("ID: "..tostring(self.id))
    print("Device Type: "..tostring(self.deviceType))
    print("Display Name: "..tostring(self:displayName(os.getComputerLabel())))
    print("Transfer Rate Input: "..tostring(self:transferRateInput()))
    print("Transfer Rate Output: "..tostring(self:transferRateOutput()))
    print("Transfer Rate Limit: "..tostring(self:transferRateLimit()))
    print("Effective Transfer Rate Limit: "..tostring(self:effectiveTransferRateLimit()))
end
