-- Reactor / Turbine Control
-- (c) 2021 SeekerOfHonjo
-- Version 2.0
-- https://gitlab.com/seekerscomputercraft/extremereactorcontrol/-/blob/main/classes/mekanism/MekanismEnergyStorage.lua?ref_type=heads

local DraconicEnergyStorage = setmetatable({
    useGetEnergy = false,
    useGetEnergyCapacity = false,

    energy = function(self)
        if self.useGetEnergy then
            return defaultNil(self.id.getEnergyStored(), 0)
        end
    end,
    capacity = function(self)
        if self.useGetEnergyCapacity then
            return defaultNil(self.id.getMaxEnergyStored(), 0)
        end
    end,
    percentage = function(self)
        return defaultNan(math.floor(self:energy()/self:capacity()*100), 0)
    end,
    percentagePrecise = function(self)
        return defaultNan(self:energy()/self:capacity()*100, 0)
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


