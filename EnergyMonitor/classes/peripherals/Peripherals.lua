-- EnergyMonitor peripheral registry and setup.
-- EnergyMonitor implementation Copyright (c) 2026 TrickShotMLG02. Licensed under the MIT License.
-- The peripheral discovery/setup structure began from ExtremeReactorControl
-- by SeekerOfHonjo at commit f0f223ec, which itself descends from
-- Reactor-and-Turbine-control-program by Thor_s_Crafter. The registry-based
-- storage/transfer support system is EnergyMonitor-specific.


--Peripherals
_G.monitors = {} --Monitor
_G.controlMonitor = "" --Monitor
_G.wirelessModem = "" --wirelessModem
_G.enableWireless = false

_G.transferrer = nil --Energy Transfer
_G.capacitor = nil --Energy Storage

--Total count of all attachments
_G.amountMonitors = 0
_G.smallMonitor = 1
_G.amountClients = 0

local storageSupport = {}
local transferSupport = {}

local function hasMethod(peri, methodName)
    if peri == nil then
        return false
    end

    local success, method = pcall(function()
        return peri[methodName]
    end)

    return success and type(method) == "function"
end

local function peripheralTypeContains(periType, pattern)
    return periType ~= nil and string.find(periType, pattern) ~= nil
end

local function isMekanismEnergyType(periType)
    return periType == "inductionMatrix"
        or periType == "mekanismMachine"
        or periType == "Induction Matrix"
        or periType == "mekanism:induction_port"
        or periType == "inductionPort"
        or peripheralTypeContains(periType, "rftoolspower:cell")
        or peripheralTypeContains(periType, "Energy Cube")
        or peripheralTypeContains(periType, "EnergyCube")
end

local function isFluxNetworkPlug(periType)
    return periType == "flux_plug"
        or periType == "fluxnetworks:flux_plug"
end

local function isFluxNetworkController(periType)
    return periType == "flux_controller"
        or periType == "fluxnetworks:flux_controller"
end

local function isFluxNetworkPoint(periType)
    return periType == "flux_point"
        or periType == "fluxnetworks:flux_point"
end

local function newPeripheralContext(name, periType, peri)
    return {
        name = name,
        type = periType,
        peripheral = peri,
        transferType = _G.transferType
    }
end

local function registerSupport(definitions, definition)
    if definition.fallback then
        table.insert(definitions, definition)
        return
    end

    for i = 1, #definitions do
        if definitions[i].fallback then
            table.insert(definitions, i, definition)
            return
        end
    end

    table.insert(definitions, definition)
end

function _G.registerEnergyStorageSupport(definition)
    registerSupport(storageSupport, definition)
end

function _G.registerEnergyTransferSupport(definition)
    registerSupport(transferSupport, definition)
end

local function tryCreateSupportedPeripheral(definitions, ctx)
    for i = 1, #definitions do
        local definition = definitions[i]
        if definition.matches(ctx) then
            print(definition.label .. " - " .. ctx.name)
            return definition.create(ctx)
        end
    end

    return nil
end

_G.registerEnergyStorageSupport({
    label = "Mekanism Energy Storage device",
    matches = function(ctx)
        return isMekanismEnergyType(ctx.type)
    end,
    create = function(ctx)
        return newMekanismEnergyStorage("ec0", ctx.peripheral, ctx.name, ctx.type)
    end
})

_G.registerEnergyStorageSupport({
    label = "DraconicEvolution Energy Storage device",
    matches = function(ctx)
        return ctx.type == "draconic_rf_storage"
    end,
    create = function(ctx)
        return newDraconicEnergyStorage("ec0", ctx.peripheral, ctx.name, ctx.type)
    end
})

_G.registerEnergyStorageSupport({
    label = "Powah Energy Storage device",
    matches = function(ctx)
        return ctx.type == "powah:energy_cell"
            or ctx.type == "powah:ender_cell"
    end,
    create = function(ctx)
        return newPowahEnergyStorage("ec0", ctx.peripheral, ctx.name, ctx.type)
    end
})

_G.registerEnergyStorageSupport({
    label = "getEnergyStored() device",
    fallback = true,
    matches = function(ctx)
        return hasMethod(ctx.peripheral, "getEnergyStored")
    end,
    create = function(ctx)
        return newEnergyStorage("ec0", ctx.peripheral, ctx.name, ctx.type)
    end
})

_G.registerEnergyTransferSupport({
    label = "Energy Detector",
    matches = function(ctx)
        return ctx.type == "energyDetector"
    end,
    create = function(ctx)
        return newEnergyDetector("ed0", ctx.peripheral, ctx.name, ctx.type, ctx.transferType)
    end
})

_G.registerEnergyTransferSupport({
    label = "Energy Meter",
    matches = function(ctx)
        return ctx.type == "energymeter"
    end,
    create = function(ctx)
        return newEnergyMeter("em0", ctx.peripheral, ctx.name, ctx.type, ctx.transferType)
    end
})

_G.registerEnergyTransferSupport({
    label = "Flux Networks Controller",
    matches = function(ctx)
        return isFluxNetworkController(ctx.type)
    end,
    create = function(ctx)
        return newFluxNetworkTransfer("fn0", ctx.peripheral, ctx.name, ctx.type, ctx.transferType, "controller")
    end
})

_G.registerEnergyTransferSupport({
    label = "Flux Networks Flux Plug",
    matches = function(ctx)
        return isFluxNetworkPlug(ctx.type)
    end,
    create = function(ctx)
        return newFluxNetworkTransfer("fn0", ctx.peripheral, ctx.name, ctx.type, ctx.transferType, "plug")
    end
})

_G.registerEnergyTransferSupport({
    label = "Flux Networks Flux Point",
    matches = function(ctx)
        return isFluxNetworkPoint(ctx.type)
    end,
    create = function(ctx)
        return newFluxNetworkTransfer("fn0", ctx.peripheral, ctx.name, ctx.type, ctx.transferType, "point")
    end
})

_G.registerEnergyTransferSupport({
    label = "Mekanism Energy Transfer device",
    matches = function(ctx)
        return isMekanismEnergyType(ctx.type)
    end,
    create = function(ctx)
        return newMekanismEnergyTransfer("ec0", ctx.peripheral, ctx.name, ctx.type, ctx.transferType)
    end
})

_G.registerEnergyTransferSupport({
    label = "DraconicEvolution EnergyCore Transfer device",
    matches = function(ctx)
        return ctx.type == "draconic_rf_storage"
    end,
    create = function(ctx)
        return newDraconicCoreEnergyTransfer("ec0", ctx.peripheral, ctx.name, ctx.type, ctx.transferType)
    end
})

_G.registerEnergyTransferSupport({
    label = "DraconicEvolution Flux Gate Transfer device",
    matches = function(ctx)
        return ctx.type == "flow_gate"
    end,
    create = function(ctx)
        return newDraconicFluxGateEnergyTransfer("ec0", ctx.peripheral, ctx.name, ctx.type, ctx.transferType)
    end
})

_G.registerEnergyTransferSupport({
    label = "getEnergyTransferInput() device",
    fallback = true,
    matches = function(ctx)
        return hasMethod(ctx.peripheral, "getEnergyTransferInput")
            or hasMethod(ctx.peripheral, "getTransferRateInput")
            or hasMethod(ctx.peripheral, "getTransferRateOutput")
    end,
    create = function(ctx)
        return newEnergyTransfer("ec0", ctx.peripheral, ctx.name, ctx.type, ctx.transferType)
    end
})

local function setupSystemPeripheral(periItem, periType, peri)
    if periType == "monitor" then
        print("Monitor - " .. periItem)
        if _G.controlMonitor == "" then
            _G.controlMonitor = peri
        else
            _G.monitors[_G.amountMonitors] = peri
            _G.amountMonitors = _G.amountMonitors + 1
        end
    elseif periType == "modem" and _G.callPeripheralMethod(peri, "isWireless", false) then
        print("Wireless Modem - " .. periItem)
        _G.wirelessModem = peri
        _G.enableWireless = true
    end
end

local function setupClientPeripheral(ctx)
    if _G.peripheralType == "capacitor" and _G.capacitor == nil then
        _G.capacitor = tryCreateSupportedPeripheral(storageSupport, ctx)
    elseif _G.peripheralType == "transfer" and _G.transferrer == nil then
        _G.transferrer = tryCreateSupportedPeripheral(transferSupport, ctx)
    end
end

-- function that grabs all peripherals and initializes the correct one as client
local function searchPeripherals()
    local peripheralList = peripheral.getNames()
    for i = 1, #peripheralList do
        local periItem = peripheralList[i]
        local periType = peripheral.getType(periItem)
        local peri = peripheral.wrap(periItem)
        local ctx = newPeripheralContext(periItem, periType, peri)

        setupSystemPeripheral(periItem, periType, peri)
        setupClientPeripheral(ctx)
    end
end

-- function that grabs all peripherals and checks if the required ones are attached
function _G.checkPeripherals()
    --Check for errors
    term.clear()
    term.setCursorPos(1,1)

    if _G.program == "monitor" then

        if controlMonitor == "" then
            error("Control Monitor not found!\nPlease check and reboot the computer (Press and hold Ctrl+R)")
        end

        --Monitor clear
        controlMonitor.setBackgroundColor(colors.black)
        controlMonitor.setTextColor(colors.red)
        controlMonitor.clear()
        controlMonitor.setCursorPos(1,1)
        controlMonitor.setTextScale(0.5)

        --Monitor too small
        local monX,monY = controlMonitor.getSize()
    end
    
    if _G.program == "client" or _G.program == "server" then
       -- No monitor required for clients and servers
    elseif _G.program == "monitor" then
        local monX,monY = controlMonitor.getSize()
        _G.smallMonitor = 0
        if monX < 79 or monY < 24 then
            local messageOut = _G.language:getText("monitorSize");
            controlMonitor.write(messageOut)
            error(messageOut)
        end
    end
end

-- function that creates the connection from the modem on the channel from the config
function setupModemConnection()
    debugOutput("Setup Modem Connection on channel " .. _G.modemChannel)
    if not _G.enableWireless then
        local message = _G.language:getText("noModemFound")
        if _G.showMonitorNotice ~= nil then
            _G.showMonitorNotice("Network error", {
                message,
                "Attach a wireless modem",
                "and restart this computer."
            })
        end
        error(message)
    end

    _G.wirelessModem.open(_G.modemChannel)
end

-- function that will grab all attached peripherals, set up the correct one and connect the modem to the server
function _G.initPeripherals()
    searchPeripherals()
    _G.checkPeripherals()
    setupModemConnection()
end
