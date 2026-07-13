-- EnergyMonitor Advanced Peripherals Energy Detector wrapper.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- EnergyMonitor-specific transfer support following the local transfer wrapper pattern.

local EnergyDetector = setmetatable({
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
    end,

    transferRateLimit = function(self)
        return _G.callPeripheralMethod(self.id, "getTransferRateLimit", 0)
    end
}, {__index = EnergyTransfer})

function _G.newEnergyDetector(name, id, side, type, transferType)
    print("Creating new EnergyDetector")
    local detector = {}
    setmetatable(detector, {__index = EnergyDetector})
    
    if id == nil then
        print("MISSING wrapped peripheral object. This is going to break!")
    end

    detector.name = name
    detector.id = id
    detector.side = side
    detector.type = type
    detector.transferType = transferType

    return detector
end

function _G.printEnergyDetectorData(detector)
    print("Name: "..detector.name)
    print("ID: "..tostring(detector.id))
    print("Transfer Rate Input: "..tostring(detector:transferRateInput()))
    print("Transfer Rate Output: "..tostring(detector:transferRateOutput()))
    print("Transfer Rate Limit: "..tostring(detector:transferRateLimit()))
end

function EnergyDetector:printEnergyTransferData()
    _G.printEnergyDetectorData(self)
end
