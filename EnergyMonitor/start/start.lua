-- Extreme Reactors Control by SeekerOfHonjo --
-- Original work by Thor_s_Crafter on https://github.com/ThorsCrafter/Reactor-and-Turbine-control-program -- 
-- Version 1.0 --
-- Start program --

--========== Global variables for all program parts ==========

--All options
_G.optionList = {}
_G.version = 0
_G.program = ""
_G.lang = ""
_G.meterType = 0
_G.modemChannel = 0
_G.pingInterval = 0.5
_G.historyMinutes = 5
_G.historySaveInterval = 15
_G.monitorOpenGraphOnStart = false
_G.autoUpdate = 1
_G.debugEnabled = 1
_G.language = {}

--========== Global functions for all program parts ==========

--===== Functions for loading and saving the options =====

--_G.repoUrl = "https://raw.githubusercontent.com/TrickShotMLG02/EnergyMonitor/"
_G.repoOwner = "TrickShotMLG02"
_G.repoName = "EnergyMonitor"
_G.repoUrl = "https://cdn.jsdelivr.net/gh/" .. _G.repoOwner .. "/" .. _G.repoName .. "@"
_G.tagsApiUrl = "https://data.jsdelivr.com/v1/package/gh/" .. _G.repoOwner .. "/" .. _G.repoName
_G.installerCompatRef = "v2.0.0"

local function apiHeaders()
	return {
		["Accept"] = "application/json",
		["User-Agent"] = "EnergyMonitor"
	}
end

local function stripVersionPrefix(tag)
	if tag == nil then
		return nil
	end

	tag = tostring(tag):gsub("^%s+", ""):gsub("%s+$", "")
	if (tag:sub(1, 1) == '"' and tag:sub(-1) == '"') or (tag:sub(1, 1) == "'" and tag:sub(-1) == "'") then
		tag = tag:sub(2, -2)
	end
	if tag:sub(1, 1) == "v" or tag:sub(1, 1) == "V" then
		return tag:sub(2)
	end

	return tag
end

local function parseSemverTag(tag)
	local normalized = stripVersionPrefix(tag)
	if normalized == nil then
		return nil
	end

	local dashPos = normalized:find("-", 1, true)
	local core = normalized
	local prerelease = nil
	if dashPos ~= nil then
		core = normalized:sub(1, dashPos - 1)
		prerelease = normalized:sub(dashPos + 1)
		if prerelease == "" then
			return nil
		end
	end

	local parts = {}
	for part in tostring(core):gmatch("[^%.]+") do
		if part:match("^%d+$") == nil then
			return nil
		end
		table.insert(parts, tonumber(part))
	end

	if #parts < 1 or #parts > 4 then
		return nil
	end

	while #parts < 4 do
		table.insert(parts, 0)
	end

	return {
		raw = tag,
		core = parts,
		prerelease = prerelease ~= nil and prerelease:sub(2) or nil
	}
end

local function splitIdentifiers(value)
	local parts = {}
	if value == nil or value == "" then
		return parts
	end

	for part in tostring(value):gmatch("[^.]+") do
		table.insert(parts, part)
	end

	return parts
end

local function compareParsedTags(left, right)
	local maxCount = math.max(#left.core, #right.core)
	for i = 1, maxCount do
		local leftPart = left.core[i] or 0
		local rightPart = right.core[i] or 0

		if leftPart < rightPart then
			return -1
		elseif leftPart > rightPart then
			return 1
		end
	end

	if left.prerelease == nil and right.prerelease == nil then
		return 0
	end

	if left.prerelease == nil then
		return 1
	elseif right.prerelease == nil then
		return -1
	end

	local leftParts = splitIdentifiers(left.prerelease)
	local rightParts = splitIdentifiers(right.prerelease)
	maxCount = math.max(#leftParts, #rightParts)

	for i = 1, maxCount do
		local leftPart = leftParts[i]
		local rightPart = rightParts[i]

		if leftPart == nil then
			return -1
		elseif rightPart == nil then
			return 1
		end

		local leftNumber = tonumber(leftPart)
		local rightNumber = tonumber(rightPart)
		local cmp

		if leftNumber ~= nil and rightNumber ~= nil then
			if leftNumber < rightNumber then
				cmp = -1
			elseif leftNumber > rightNumber then
				cmp = 1
			else
				cmp = 0
			end
		elseif leftNumber ~= nil then
			cmp = -1
		elseif rightNumber ~= nil then
			cmp = 1
		else
			if leftPart < rightPart then
				cmp = -1
			elseif leftPart > rightPart then
				cmp = 1
			else
				cmp = 0
			end
		end

		if cmp ~= 0 then
			return cmp
		end
	end

	return 0
end

local function requestJson(url)
	local response = http.get(url, apiHeaders())
	if response == nil then
		return nil
	end

	local code = nil
	if type(response.getResponseCode) == "function" then
		code = response.getResponseCode()
	end
	local body = response.readAll()
	response.close()

	if code ~= nil and code ~= 200 then
		return nil
	end

	local ok, data = pcall(textutils.unserializeJSON, body)
	if not ok then
		return nil
	end

	return data
end

local function isArrayTable(value)
	if type(value) ~= "table" then
		return false
	end

	return value[1] ~= nil or next(value) == nil
end

local function fetchAllRepositoryTags()
	local tags = {}
	local data = requestJson(_G.tagsApiUrl)
	if type(data) ~= "table" then
		return tags
	end

	if type(data.versions) ~= "table" then
		return tags
	end

	for _, version in ipairs(data.versions) do
		if type(version) == "string" then
			local parsed = parseSemverTag(version)
			if parsed ~= nil then
				table.insert(tags, parsed)
			end
		elseif type(version) == "table" and type(version.version) == "string" then
			local parsed = parseSemverTag(version.version)
			if parsed ~= nil then
				table.insert(tags, parsed)
			end
		end
	end

	return tags
end

local function selectLatestRepositoryTag(tags, channel)
	local candidates = {}

	for _, tag in ipairs(tags) do
		local beta = tag.prerelease ~= nil
		if channel == "beta" then
			if beta then
				table.insert(candidates, tag)
			end
		else
			if not beta then
				table.insert(candidates, tag)
			end
		end
	end

	table.sort(candidates, function(left, right)
		return compareParsedTags(left, right) > 0
	end)

	if #candidates == 0 then
		return nil
	end

	return candidates[1].raw
end

function _G.getVersionChannel(versionTag)
	local parsed = parseSemverTag(versionTag)
	if parsed == nil then
		return nil
	end

	if parsed.prerelease == nil then
		return "stable"
	end

	local prerelease = string.lower(parsed.prerelease)
	if prerelease:find("beta") ~= nil or prerelease:find("development") ~= nil then
		return "beta"
	end

	return "stable"
end

function _G.fetchLatestRepositoryTag(channel)
	local tags = fetchAllRepositoryTags()
	if type(tags) ~= "table" then
		return nil
	end

	return selectLatestRepositoryTag(tags, channel)
end

function _G.compareRepositoryTags(leftTag, rightTag)
	local left = parseSemverTag(leftTag)
	local right = parseSemverTag(rightTag)

	if left == nil or right == nil then
		return nil
	end

	return compareParsedTags(left, right)
end

local function downloadInstallerCompat()
	local compatUrl = _G.repoUrl .. _G.installerCompatRef .. "/EnergyMonitor/"
	local gotUrl = http.get(compatUrl .. "install/installer.lua")
	if gotUrl == nil then
		error("Could not download compatibility installer from " .. _G.installerCompatRef)
	end

	local file = fs.open("/EnergyMonitor/install/installer.lua", "w")
	file.write(gotUrl.readAll())
	file.close()
	gotUrl.close()
end

function  _G.debugOutput(message) 
	if  _G.debugEnabled == 1 then
		print(message)
	end
end

--Loads the options.txt file and adds values to the global variables
function _G.loadOptionFile()
	debugOutput("Loading Option File")
	--Loads the file
	local file = fs.open("/EnergyMonitor/config/options.txt","r")
	local list = file.readAll()
	file.close()
    
    --Insert Elements and assign values
    _G.optionList = textutils.unserialise(list)

	--Assign values to variables
	_G.version = optionList["version"]
	_G.program = optionList["program"]
	_G.lang = optionList["language"]
	_G.peripheralType = optionList["peripheralType"]
	_G.transferType = optionList["transferType"]
	_G.modemChannel = optionList["modemChannel"]
	_G.pingInterval = optionList["pingInterval"]
	_G.historyMinutes = optionList["historyMinutes"]
	_G.historySaveInterval = optionList["historySaveInterval"]
	_G.monitorOpenGraphOnStart = optionList["monitorOpenGraphOnStart"]
	_G.autoUpdate = optionList["autoUpdate"]
	_G.debugEnabled = optionList["debug"]

	if _G.historyMinutes == nil then
		_G.historyMinutes = 5
	end
	_G.historyMinutes = math.max(1, math.min(120, tonumber(_G.historyMinutes) or 5))
	if _G.historySaveInterval == nil then
		_G.historySaveInterval = 15
	end
	_G.historySaveInterval = math.max(5, math.min(3600, tonumber(_G.historySaveInterval) or 15))
	if _G.monitorOpenGraphOnStart == nil then
		_G.monitorOpenGraphOnStart = false
	end
end

--Refreshes the options list
function _G.refreshOptionList()
	debugOutput("Refreshing Option List")
	debugOutput("Variable: version")
	optionList["version"] = version
	debugOutput("Variable: program")
	optionList["program"] = program
	debugOutput("Variable: meterType")
	optionList["meterType"] = meterType
	debugOutput("Variable: lang")
	optionList["language"] = lang
	debugOutput("Variable: modemChannel")
	optionList["modemChannel"] = modemChannel
	debugOutput("Variable: pingInterval")
	optionList["pingInterval"] = pingInterval
	debugOutput("Variable: historyMinutes")
	optionList["historyMinutes"] = historyMinutes
	debugOutput("Variable: historySaveInterval")
	optionList["historySaveInterval"] = historySaveInterval
	debugOutput("Variable: monitorOpenGraphOnStart")
	optionList["monitorOpenGraphOnStart"] = monitorOpenGraphOnStart
	optionList["debug"] = debug
	debugOutput("Variable: autoUpdate")
	optionList["autoUpdate"] = autoUpdate
end

--Saves all data back to the options.txt file
function _G.saveOptionFile()
	debugOutput("Saving Option File")
	--Refresh option list
	refreshOptionList()
    --Serialise the table
    local list = textutils.serialise(optionList)
	--Save optionList to the config file
	local file = fs.open("/EnergyMonitor/config/options.txt","w")
    file.writeLine(list)
	file.close()
	print("Saved.")
end


--===== Automatic update detection =====

--Check for updates
function _G.checkUpdates()

	if version == nil or version == "n/a" then
		print("No installed version set. Skipping update check.")
		return
	end

	local currChannel = _G.getVersionChannel(version)
	if currChannel == nil then
		print("Couldn't determine installed version channel. Skipping update check.")
		return
	end

	local remoteVer = _G.fetchLatestRepositoryTag(currChannel)
	if remoteVer == nil then
		print("Couldn't get remote tags from github. Continuing...")
		return
	end

	print("localVer: "..version)
	print("remoteVer: "..remoteVer)

	local cmp = _G.compareRepositoryTags(remoteVer, version)
	if cmp == nil then
		print("Couldn't compare versions. Continuing...")
		return
	end

	print("Update? -> "..tostring(cmp > 0))

	if cmp > 0 then
		print("Update...")
		sleep(2)
		doUpdate(remoteVer)
	end
end

function _G.showMonitorNotice(title, lines)
	if _G.program == "client" or _G.program == "server" then
		return
	end

	if _G.controlMonitor == nil or _G.controlMonitor == "" then
		return
	end

	local ok = pcall(function()
		local x,y = _G.controlMonitor.getSize()
		local boxWidth = math.min(36, x)
		local boxHeight = math.min(8, y)
		local x1 = math.max(1, math.floor((x - boxWidth) / 2) + 1)
		local y1 = math.max(1, math.floor((y - boxHeight) / 2) + 1)

		_G.controlMonitor.setBackgroundColor(colors.black)
		_G.controlMonitor.clear()
		_G.controlMonitor.setBackgroundColor(colors.gray)
		_G.controlMonitor.setTextColor(colors.gray)

		for i=0,boxHeight-1 do
			_G.controlMonitor.setCursorPos(x1,y1+i)
			_G.controlMonitor.write(string.rep(" ", boxWidth))
		end

		_G.controlMonitor.setTextColor(colors.white)
		_G.controlMonitor.setCursorPos(x1 + math.max(0, math.floor((boxWidth - string.len(title)) / 2)), y1 + 1)
		_G.controlMonitor.write(string.sub(title, 1, boxWidth))

		for i=1,math.min(#lines, boxHeight - 3) do
			local line = tostring(lines[i])
			_G.controlMonitor.setCursorPos(x1 + math.max(0, math.floor((boxWidth - string.len(line)) / 2)), y1 + 1 + i)
			_G.controlMonitor.write(string.sub(line, 1, boxWidth))
		end
	end)

	if not ok then
		debugOutput("Could not draw monitor notice.")
	end
end

function _G.doUpdate(toVer)
	if autoUpdate == 1 then
		downloadInstallerCompat()
		_G.showMonitorNotice(_G.language:getText("autoUpdateLineOne"), {
			toVer,
			_G.language:getText("autoUpdateLineTwo"),
            _G.language:getText("autoUpdateLineThree")
        })
    else
        _G.showMonitorNotice(_G.language:getText("updateAvailableLineOne"), {
            toVer,
            _G.language:getText("updateAvailableLineTwo"),
            _G.language:getText("updateAvailableLineThree")
        })
    end

	--Print install instructions to the terminal
	term.clear()
	term.setCursorPos(1,1)
	local tx,ty = term.getSize()

    if autoUpdate == 1 then
        print(_G.language:getText("autoUpdateProgram"))
    else
        print(_G.language:getText("updateProgram"))
        term.write("Input: ")
    end

--
    --Run Counter for installation skipping
    local count = 10
    local out = false

    term.setCursorPos(tx/2-5,ty)
    term.write(" -- 10 -- ")

	if autoUpdate == 1 then
		shell.run("/EnergyMonitor/install/installer.lua update "..toVer)
		os.reboot()
		return
	end

    while true do

        local timer1 = os.startTimer(1)

        while true do

            local event, p1 = os.pullEvent()

            if event == "key" then

                if p1 == 90 or p1 == 98 then
                    downloadInstallerCompat()
                    shell.run("/EnergyMonitor/install/installer.lua update "..toVer)
                    out = true
					os.reboot()
                    break
				elseif p1 == 78 then
					out = true
					break
                end

            elseif event == "timer" and p1 == timer1 then

                count = count - 1
                term.setCursorPos(tx/2-5,ty)
                term.write(" -- 0"..count.." -- ")
                break
            end
        end

        if out then break end

        if count == 0 then
            term.clear()
            term.setCursorPos(1,1)
            break
        end
    end
--
end

--Download Files
function _G.downloadFile(relUrl,path)
	local gotUrl = http.get(relUrl..path)
	if gotUrl == nil then
		term.clear()
		error("File not found! Please check!\nFailed at "..relUrl..path)
	else
		_G.url = gotUrl.readAll()
	end

	local file = fs.open(path,"w")
	file.write(url)
	file.close()
end


--===== Shutdown and restart the computer =====

function _G.reactorestart()
	saveOptionFile()
	controlMonitor.clear()
	controlMonitor.setCursorPos(38,8)
	controlMonitor.write("Rebooting...")
	os.reboot()
end


function initClasses()
    -- Create base paths
    local binPath = "/EnergyMonitor/classes/"
	local periPath = binPath.."peripherals/"
	local transportPath = binPath.. "transport/"

	-- Load Peripherals support
    shell.run(periPath.."base/EnergyStorage.lua")
	shell.run(periPath.."base/EnergyTransfer.lua")
	shell.run(periPath.."Peripherals.lua")

	-- Load Language localization
	shell.run(binPath.."Language.lua")

	-- Load utils
	shell.run(binPath.."Utils.lua")

	-- Load NetworkMessenger with Packets
    shell.run(transportPath.."Networking.lua")
	


	---------------------------
	-- Add Mod Support below --
	---------------------------

    -- Advanced Peripherals Mod Support
    shell.run(periPath.."advancedPeripherals/EnergyDetector.lua")

	-- Energy Meters Mod Support
	shell.run(periPath.."energyMeter/EnergyMeter.lua")

	-- Mekanism Mod Support
    shell.run(periPath.."mekanism/MekanismEnergyStorage.lua")
	shell.run(periPath.."mekanism/MekanismEnergyTransfer.lua")

	-- Draconic Evolution Mod Support
	shell.run(periPath.."draconicEvolution/DraconicCoreEnergyStorage.lua")
	shell.run(periPath.."draconicEvolution/DraconicCoreEnergyTransfer.lua")
	shell.run(periPath.."draconicEvolution/DraconicFluxGateEnergyTransfer.lua")
end


--=========== Run the program ==========

--Load the option file and initialize the peripherals

debugOutput("Loading Options File")
loadOptionFile()

debugOutput("Initializing Classes")
initClasses()

debugOutput("Initializing Language")
_G.language = _G.newLanguageById(_G.lang)

debugOutput("Initializing Network Devices")
_G.initPeripherals()

-- check for updates using repository tags
debugOutput("Checking for Updates")
checkUpdates()

--Run program based on the settings
if program == "server" then
	shell.run("/EnergyMonitor/program/server.lua")
elseif program == "client" then
	shell.run("/EnergyMonitor/program/client.lua")
elseif program == "monitor" then
	shell.run("/EnergyMonitor/program/monitor.lua")
end
shell.completeProgram("/EnergyMonitor/start/start.lua")

--========== END OF THE START.LUA FILE ==========
