-- EnergyMonitor Mekanism energy transfer wrapper.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- EnergyMonitor-specific transfer support following the local transfer wrapper pattern.

local MekanismEnergyTransfer = setmetatable({
    successGetLastInput = false,
    successGetLastOutput = false,

    energy = function(self)
        if self.useGetEnergy then
            local energy = _G.callPeripheralMethod(self.id, "getEnergy", nil)
            return energy ~= nil and energy * 0.4 or nil
        end
        if self.useGetTotalEnergy then
            local energy = _G.callPeripheralMethod(self.id, "getTotalEnergy", nil)
            return energy ~= nil and energy * 0.4 or nil
        end
        return nil
    end,

    -- Basic Methods
    transferRateInput = function(self)
        if self.transferType == _G.TransferType.Input or self.transferType == _G.TransferType.Both then
            local transfer = _G.callPeripheralMethod(self.id, "getLastInput", nil)
            return transfer ~= nil and transfer * 0.4 or nil
        else
            return 0
        end
    end,

    transferRateOutput = function(self)
        if self.transferType == _G.TransferType.Output or self.transferType == _G.TransferType.Both then
            local transfer = _G.callPeripheralMethod(self.id, "getLastOutput", nil)
            return transfer ~= nil and transfer * 0.4 or nil
        else
            return 0
        end
    end
}, {__index = EnergyTransfer})

function _G.newMekanismEnergyTransfer(name, id, side, type, transferType)
    print("Creating new Mekanism Energy Transfer")
    local transfer = {}
    setmetatable(transfer, {__index=MekanismEnergyTransfer})
    if id == nil then
        print("MISSING wrapped peripheral object. This is going to break!")
    end

    local successGetLastInput, errGetMaxEnergy= pcall(function() id.getLastInput() end)
    local successGetLastOutput, errGetTotalMaxEnergy= pcall(function() id.getLastOutput() end)

    transfer.successGetLastInput = successGetLastInput    
    transfer.successGetLastOutput = successGetLastOutput

    transfer.useGetEnergy = pcall(function() id.getEnergy() end)
    transfer.useGetTotalEnergy = pcall(function() id.getTotalEnergy() end)

    transfer.name = name
    transfer.id = id
    transfer.side = side
    transfer.type = type
    transfer.transferType = transferType

    return transfer
end
