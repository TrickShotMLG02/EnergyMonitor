-- EnergyMonitor Mekanism energy storage wrapper.
-- EnergyMonitor modifications Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- This wrapper is adapted from ExtremeReactorControl by SeekerOfHonjo at commit f0f223ec.

local MekanismEnergyStorage = setmetatable({
    useGetEnergy = false,    
    useGetTotalEnergy = false,    
    useGetEnergyCapacity = false,    
    useGetMaxEnergy = false,    
    useGetTotalMaxEnergy = false,

    -- mekanism uses Joule which is 0.4 times RF
    energy = function(self)
        if self.useGetEnergy then
            return _G.callPeripheralMethod(self.id, "getEnergy", 0) * 0.4
        end
        if self.useGetTotalEnergy then
            return _G.callPeripheralMethod(self.id, "getTotalEnergy", 0) * 0.4
        end
        return 0
    end,
    capacity = function(self)
        if self.useGetEnergyCapacity then
            return _G.callPeripheralMethod(self.id, "getEnergyCapacity", 0) * 0.4
        end
        if self.useGetMaxEnergy then
            return _G.callPeripheralMethod(self.id, "getMaxEnergy", 0) * 0.4
        end
        if self.useGetTotalMaxEnergy then
            return _G.callPeripheralMethod(self.id, "getTotalMaxEnergy", 0) * 0.4
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

function _G.newMekanismEnergyStorage(name,id, side, type)
    print("Creating new Mekanism Energy Storage")
    local storage = {}
    setmetatable(storage,{__index=MekanismEnergyStorage})
    
    if id == nil then
        print("MISSING wrapped peripheral object. This is going to break!")
    end

    local successGetEnergy, errGetEnergy= pcall(function() id.getEnergy() end)
    local successGetTotalEnergy, errGetTotalEnergy= pcall(function() id.getTotalEnergy() end)
    local successGetEnergyCapacity, errGetEnergyCapacity= pcall(function() id.getEnergyCapacity() end)
    local successGetMaxEnergy, errGetMaxEnergy= pcall(function() id.getMaxEnergy() end)
    local successGetTotalMaxEnergy, errGetTotalMaxEnergy= pcall(function() id.getTotalMaxEnergy() end)

    storage.useGetEnergy = successGetEnergy
    storage.useGetTotalEnergy = successGetTotalEnergy   
    storage.useGetEnergyCapacity = successGetEnergyCapacity    
    storage.useGetMaxEnergy = successGetMaxEnergy    
    storage.useGetTotalMaxEnergy = successGetTotalMaxEnergy

    storage.name = name
    storage.id = id
    storage.side = side
    storage.type = type

    return storage
end




