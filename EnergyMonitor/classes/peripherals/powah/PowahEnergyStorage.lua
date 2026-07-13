-- EnergyMonitor Powah energy storage wrapper.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- This is new EnergyMonitor mod support, implemented using the EnergyMonitor
-- storage wrapper pattern adapted from ExtremeReactorControl at commit f0f223ec.

local PowahEnergyStorage = {
    name = "",
    id = {},
    side = "",
    type = "",

    -- overwrite these functions in specific mod support implementations with the corresponding api function
    energy = function(self)
        return _G.callPeripheralMethod(self.id, "getEnergy", 0)
    end,
    capacity = function(self)
        return _G.callPeripheralMethod(self.id, "getEnergyCapacity", 0)
    end,
    percentage = function(self)
        local capacity = self:capacity()
        if capacity <= 0 then
            return 0
        end
        return _G.defaultNan(math.floor(self:energy() / capacity * 100), 0)
    end,
    percentagePrecise = function(self)
        local capacity = self:capacity()
        if capacity <= 0 then
            return 0
        end
        return _G.defaultNan(self:energy() / capacity * 100, 0)
    end
}

function _G.newPowahEnergyStorage(name, id, side, type)
    print("Creating new Powah Energy Storage")
    local storage = {}
    setmetatable(storage,{__index=PowahEnergyStorage})

    if id == nil then
        print("MISSING wrapped peripheral object. This is going to break!")
    end

    storage.name = name
    storage.id = id
    storage.side = side
    storage.type = type

    return storage
end
