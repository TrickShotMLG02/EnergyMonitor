-- EnergyMonitor energy transfer base wrapper.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- Implemented for EnergyMonitor using the same wrapper style as the storage base.

local EnergyTransfer = {
    name = "",
    id = {},
    type = "",
    transferType = "", -- "input", "output", or "both"
    status = "",

    -- overwrite these functions in specific mod support implementations with the corresponding api function
    displayName = function(self, computerLabel)
        return computerLabel
    end,

    -- Used by the client as a fallback when a transfer peripheral does not
    -- expose a usable transfer-rate method.
    energy = function(self)
        local energy = _G.callPeripheralMethod(self.id, "getEnergyStored", nil)
        if energy ~= nil then
            return energy
        end
        energy = _G.callPeripheralMethod(self.id, "getEnergy", nil)
        if energy ~= nil then
            return energy
        end
        return _G.callPeripheralMethod(self.id, "getTotalEnergy", nil)
    end,

    transferRateInput = function(self)
        if self.transferType == _G.TransferType.Input or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getTransferRateInput", nil)
        else
            return 0
        end
    end,

    transferRateOutput = function(self)
        if self.transferType == _G.TransferType.Output or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getTransferRateOutput", nil)
        else
            return 0
        end
    end
}

function _G.newEnergyTransfer(name, id, side, type, transferType)
    local transfer = {}
    setmetatable(transfer, {__index = EnergyTransfer})
    
    transfer.name = name
    transfer.id = id
    transfer.side = side
    transfer.type = type
    transfer.transferType = transferType

    return transfer
end

function _G.printEnergyTransferData(transfer)
    print("Name: "..transfer.name)
    print("ID: "..tostring(transfer.id))
    -- print("Status: "..transfer:status())
    print("TransferType: " ..transfer.transferType)
    print("Input: "..tostring(transfer:transferRateInput()))
    print("Output: "..tostring(transfer:transferRateOutput()))
end
