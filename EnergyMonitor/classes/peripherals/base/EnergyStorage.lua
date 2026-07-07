-- Reactor / Turbine Control
-- (c) 2021 SeekerOfHonjo
-- Version 2.0
-- https://gitlab.com/seekerscomputercraft/extremereactorcontrol/-/blob/main/classes/base/EnergyStorage.lua?ref_type=heads

local EnergyStorage = {
    name = "",
    id = {},
    side = "",
    type = "",
    
    -- overwrite these functions in specific mod support implementations with the corresponding api function
    energy = function(self)
        return _G.callPeripheralMethod(self.id, "getEnergyStored", 0)
    end,
    capacity = function(self)
        return _G.callPeripheralMethod(self.id, "getMaxEnergyStored", 0)
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

function _G.newEnergyStorage(name, id, side, type)
    print("Creating new Base Energy Storage")
    local storage = {}
    setmetatable(storage,{__index=EnergyStorage})
    
    if id == nil then
        print("MISSING wrapped peripheral object. This is going to break!")
    end

    storage.name = name
    storage.id = id
    storage.side = side
    storage.type = type

    return storage
end

function _G.printEnergyStorageData(storage)
    print("Name: "..storage.name)
    print("ID: "..tostring(storage.id))
    print("Energy: "..storage:energy())
    print("Capacity: "..storage:capacity())
    print("Fill: "..storage:percentage().."%")
end

