-- EnergyMonitor Flux Networks transfer wrapper.
-- Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- Supports FNCCT flux_controller, flux_plug, and flux_point peripherals.

local FluxNetworkTransfer = setmetatable({
    displayName = function(self, computerLabel)
        if self.deviceType == "controller" then
            local networkName = _G.callPeripheralMethod(self.id, "getNetworkName", nil)
            if type(networkName) == "string" and networkName ~= "" then
                return networkName
            end
        end

        local displayName = _G.callPeripheralMethod(self.id, "getDisplayName", nil)
        if type(displayName) == "string" and displayName ~= "" then
            return displayName
        end

        return computerLabel
    end,

    peripheralDataList = function(self, computerLabel)
        if self.deviceType ~= "controller" then
            return nil
        end

        local dataList = {}

        local function addDevices(devices, deviceKind, transferType)
            if type(devices) ~= "table" then
                return
            end

            for index, device in ipairs(devices) do
                if type(device) == "table" then
                    local transfer = tonumber(device.transfer) or 0
                    local displayName = device.displayName
                    if type(displayName) ~= "string" or displayName == "" then
                        displayName = computerLabel .. " " .. deviceKind .. " " .. tostring(index)
                    end

                    local dimension = tostring(device.dimension or "unknown")
                    local x = tostring(device.x or index)
                    local y = tostring(device.y or 0)
                    local z = tostring(device.z or 0)

                    local peripheralData = {}
                    setmetatable(peripheralData, {__index = _G.TransferData})
                    peripheralData.name = displayName
                    peripheralData.id = tostring(self.side) .. ":" .. string.lower(deviceKind) .. ":" .. dimension .. ":" .. x .. ":" .. y .. ":" .. z
                    peripheralData.transferIn = transferType == _G.TransferType.Input and transfer or 0
                    peripheralData.transferOut = transferType == _G.TransferType.Output and transfer or 0
                    peripheralData.transferType = transferType
                    peripheralData.status = "N/A"

                    table.insert(dataList, peripheralData)
                end
            end
        end

        if self.transferType == _G.TransferType.Input or self.transferType == _G.TransferType.Both then
            addDevices(_G.callPeripheralMethod(self.id, "getFluxPlugs", {}), "Plug", _G.TransferType.Input)
        end

        if self.transferType == _G.TransferType.Output or self.transferType == _G.TransferType.Both then
            addDevices(_G.callPeripheralMethod(self.id, "getFluxPoints", {}), "Point", _G.TransferType.Output)
        end

        return dataList
    end,

    transferRateInput = function(self)
        if self.deviceType ~= "plug" then
            return 0
        end

        if self.transferType == _G.TransferType.Input or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getTransfer", 0)
        end

        return 0
    end,

    transferRateOutput = function(self)
        if self.deviceType ~= "point" then
            return 0
        end

        if self.transferType == _G.TransferType.Output or self.transferType == _G.TransferType.Both then
            return _G.callPeripheralMethod(self.id, "getTransfer", 0)
        end

        return 0
    end,

    transferRateLimit = function(self)
        return _G.callPeripheralMethod(self.id, "getTransferLimit", 0)
    end,

    effectiveTransferRateLimit = function(self)
        return _G.callPeripheralMethod(self.id, "getEffectiveTransferLimit", 0)
    end
}, {__index = EnergyTransfer})

function _G.newFluxNetworkTransfer(name, id, side, type, transferType, deviceType)
    print("Creating new FluxNetworkTransfer")
    local transfer = {}
    setmetatable(transfer, {__index = FluxNetworkTransfer})

    if id == nil then
        print("MISSING wrapped peripheral object. This is going to break!")
    end

    transfer.name = name
    transfer.id = id
    transfer.side = side
    transfer.type = type
    transfer.transferType = transferType
    transfer.deviceType = deviceType

    return transfer
end

function FluxNetworkTransfer:printEnergyTransferData()
    print("Name: "..self.name)
    print("ID: "..tostring(self.id))
    print("Device Type: "..tostring(self.deviceType))
    print("Display Name: "..tostring(self:displayName(os.getComputerLabel())))
    if self.deviceType == "controller" then
        if self.transferType == _G.TransferType.Input or self.transferType == _G.TransferType.Both then
            local plugs = _G.callPeripheralMethod(self.id, "getFluxPlugs", {})
            print("Flux Plugs: "..tostring(type(plugs) == "table" and #plugs or 0))
        end

        if self.transferType == _G.TransferType.Output or self.transferType == _G.TransferType.Both then
            local points = _G.callPeripheralMethod(self.id, "getFluxPoints", {})
            print("Flux Points: "..tostring(type(points) == "table" and #points or 0))
        end
    else
        print("Transfer Rate Input: "..tostring(self:transferRateInput()))
        print("Transfer Rate Output: "..tostring(self:transferRateOutput()))
        print("Transfer Rate Limit: "..tostring(self:transferRateLimit()))
        print("Effective Transfer Rate Limit: "..tostring(self:effectiveTransferRateLimit()))
    end
end
