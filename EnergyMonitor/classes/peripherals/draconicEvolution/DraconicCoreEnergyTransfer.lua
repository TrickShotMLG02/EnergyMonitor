-- EnergyMonitor Draconic Evolution energy core transfer wrapper.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- EnergyMonitor-specific transfer support following the local transfer wrapper pattern.

local DraconicCoreEnergyTransfer = setmetatable({
    -- Basic Methods
    transferRateInput = function(self)
        if self.transferType == _G.TransferType.Input or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getInputPerTick", 0)
        else
            return 0
        end
    end,

    transferRateOutput = function(self)
        if self.transferType == _G.TransferType.Output or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getOutputPerTick", 0)
        else
            return 0
        end
    end
}, {__index = EnergyTransfer})

function _G.newDraconicCoreEnergyTransfer(name, id, side, type, transferType)
    print("Creating new Draconic Energy Transfer")
    local transfer = {}
    setmetatable(transfer, {__index=DraconicCoreEnergyTransfer})
    if id == nil then
        print("MISSING wrapped peripheral object. This is going to break!")
    end

    transfer.name = name
    transfer.id = id
    transfer.side = side
    transfer.type = type
    transfer.transferType = transferType

    return transfer
end
