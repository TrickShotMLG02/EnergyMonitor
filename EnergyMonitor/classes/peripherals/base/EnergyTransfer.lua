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
    transferRateInput = function(self)
        if self.transferType == _G.TransferType.Input or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getTransferRateInput", 0)
        else
            return 0
        end
    end,

    transferRateOutput = function(self)
        if self.transferType == _G.TransferType.Output or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getTransferRateOutput", 0)
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
    print("Input: "..transfer:transferRateInput())
    print("Output: "..transfer:transferRateOutput())
end
