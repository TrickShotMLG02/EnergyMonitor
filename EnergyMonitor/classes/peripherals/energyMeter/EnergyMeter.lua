-- EnergyMonitor Energy Meter wrapper.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- EnergyMonitor-specific transfer support following the local transfer wrapper pattern.

local EnergyMeter = setmetatable({
    -- Methods specific to EnergyMeter
    --[[
    sideConfig = function(self)
        return self.id.getSideConfig()
    end,
    
    interval = function(self)
        return self.id.getInterval()
    end,
    
    accuracy = function(self)
        return self.id.getAccuracy()
    end,
    
    hasOutput = function(self)
        return self.id.hasOutput()
    end,
    
    threshold = function(self)
        return self.id.getThreshold()
    end,
    
    mode = function(self)
        return self.id.getMode()
    end,
    
    fullSideConfig = function(self)
        return self.id.getFullSideConfig()
    end,
    
    hasMaxOutputs = function(self)
        return self.id.hasMaxOutputs()
    end,
    
    hasInput = function(self)
        return self.id.hasInput()
    end,
    
    numberMode = function(self)
        return self.id.getNumberMode()
    end,

    -- This method may overlap with base class, but keeping for EnergyMeter specifics
    transferRate = function(self)
        return self.id.getTransferRate()
    end
    --]]

    transferRateInput = function(self)
        if self.transferType == _G.TransferType.Input or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getTransferRate", 0)
        else
            return 0
        end
    end,

    transferRateOutput = function(self)
        if self.transferType == _G.TransferType.Output or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getTransferRate", 0)
        else
            return 0
        end
    end
}, {__index = EnergyTransfer})

function _G.newEnergyMeter(name, id, side, type, transferType)
    print("Creating new EnergyMeter")
    local meter = {}
    setmetatable(meter, {__index = EnergyMeter})
    
    if id == nil then
        print("MISSING wrapped peripheral object. This is going to break!")
    end

    meter.name = name
    meter.id = id
    meter.side = side
    meter.type = type
    meter.transferType = transferType

    return meter
end

function EnergyMeter:printEnergyTransferData()
    print("Name: "..meter.name)
    print("ID: "..tostring(meter.id))
    --print("Status: "..tostring(meter:status()))
    print("Transfer Rate Input: "..tostring(meter:transferRateInput()))
    print("Transfer Rate Output: "..tostring(meter:transferRateOutput()))
    --print("Has Output: "..tostring(meter:hasOutput()))
    --print("Has Input: "..tostring(meter:hasInput()))
    --print("Mode: "..tostring(meter:mode()))
end
