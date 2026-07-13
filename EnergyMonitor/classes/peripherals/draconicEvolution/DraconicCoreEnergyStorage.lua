-- EnergyMonitor Draconic Evolution energy storage wrapper.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- This EnergyMonitor wrapper follows the storage wrapper pattern adapted from
-- ExtremeReactorControl at commit f0f223ec, with Draconic-specific behavior.

local DraconicEnergyStorage = setmetatable({
    useGetEnergy = false,
    useGetEnergyCapacity = false,

    energy = function(self)
        if self.useGetEnergy then
            return _G.callPeripheralMethod(self.id, "getEnergyStored", 0)
        end
        return 0
    end,
    capacity = function(self)
        if self.useGetEnergyCapacity then
            return _G.callPeripheralMethod(self.id, "getMaxEnergyStored", 0)
        end
        return 0
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
}, {__index = EnergyStorage})

function _G.newDraconicEnergyStorage(name,id, side, type)
    print("Creating new DraconicEvolution Energy Storage")
    local storage = {}
    setmetatable(storage,{__index=DraconicEnergyStorage})
    
    if id == nil then
        print("MISSING wrapped peripheral object. This is going to break!")
    end

    local successGetEnergy, errGetEnergy= pcall(function() id.getEnergyStored() end)
    local successGetEnergyCapacity, errGetEnergyCapacity= pcall(function() id.getMaxEnergyStored() end)

    storage.useGetEnergy = successGetEnergy
    storage.useGetEnergyCapacity = successGetEnergyCapacity

    storage.name = name
    storage.id = id
    storage.side = side
    storage.type = type

    return storage
end


