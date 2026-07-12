-- Extreme Reactors Control by SeekerOfHonjo --
-- Original work by Thor_s_Crafter on https://github.com/ThorsCrafter/Reactor-and-Turbine-control-program --
-- Init Program Downloader (GitHub tags) --

--===== Local variables =====

local installLang = "en"
local relPath = "/EnergyMonitor/"

local repoOwner = "TrickShotMLG02"
local repoName = "EnergyMonitor"
local repoUrl = "https://cdn.jsdelivr.net/gh/" .. repoOwner .. "/" .. repoName .. "@"
local tagsApiUrl = "https://data.jsdelivr.com/v1/package/gh/" .. repoOwner .. "/" .. repoName
local installerCompatRef = "v2.0.0"
local selectedLang = {}
local debugGithubApi = false

local function debugPrint(message)
	if debugGithubApi then
		print(message)
	end
end

local function apiHeaders()
	return {
		["Accept"] = "application/json",
		["User-Agent"] = "EnergyMonitor"
	}
end

local function requestJson(url)
	local response = http.get(url, apiHeaders())
	if response == nil then
		error("Remote request failed: " .. url)
	end

	local code = nil
	if type(response.getResponseCode) == "function" then
		code = response.getResponseCode()
	end
	local body = response.readAll()
	response.close()

	if code ~= nil and code ~= 200 then
		error("Remote request returned HTTP " .. tostring(code) .. " for " .. url .. ": " .. string.sub(body, 1, 120))
	end

	debugPrint("Remote request URL: " .. url)
	debugPrint("Remote request raw: " .. string.sub(body, 1, 400))

	local ok, data = pcall(textutils.unserializeJSON, body)
	if not ok then
		error("Remote response was not valid JSON for " .. url .. ": " .. string.sub(body, 1, 120))
	end

	debugPrint("Remote response parsed type: " .. type(data))
	if type(data) == "table" then
		debugPrint("Remote response parsed count: " .. tostring(#data))
	end

	return data
end

local function isArrayTable(value)
	if type(value) ~= "table" then
		return false
	end

	return value[1] ~= nil or next(value) == nil
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

local function compareIdentifiers(left, right)
	local leftNumber = tonumber(left)
	local rightNumber = tonumber(right)

	if leftNumber ~= nil and rightNumber ~= nil then
		if leftNumber < rightNumber then
			return -1
		elseif leftNumber > rightNumber then
			return 1
		end
		return 0
	end

	if leftNumber ~= nil then
		return -1
	elseif rightNumber ~= nil then
		return 1
	end

	if left < right then
		return -1
	elseif left > right then
		return 1
	end

	return 0
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

		local cmp = compareIdentifiers(leftPart, rightPart)
		if cmp ~= 0 then
			return cmp
		end
	end

	return 0
end

local function fetchAllTags()
	local tags = {}
	local data = requestJson(tagsApiUrl)
	if type(data) ~= "table" then
		error("Could not read repository versions from jsDelivr.")
	end

	if type(data.versions) ~= "table" then
		error("jsDelivr returned an unexpected package object from " .. tagsApiUrl)
	end

	for _, version in ipairs(data.versions) do
		if type(version) == "string" then
			debugPrint("jsDelivr version entry: " .. version)
			local parsed = parseSemverTag(version)
			if parsed ~= nil then
				debugPrint("jsDelivr version parsed OK: " .. parsed.raw)
				table.insert(tags, parsed)
			else
				debugPrint("jsDelivr version rejected by parser: " .. version)
			end
		elseif type(version) == "table" and type(version.version) == "string" then
			debugPrint("jsDelivr version entry: " .. version.version)
			local parsed = parseSemverTag(version.version)
			if parsed ~= nil then
				debugPrint("jsDelivr version parsed OK: " .. parsed.raw)
				table.insert(tags, parsed)
			else
				debugPrint("jsDelivr version rejected by parser: " .. version.version)
			end
		end
	end

	debugPrint("jsDelivr parsed semver tags total: " .. tostring(#tags))

	return tags
end

local function selectLatestTag(tags, channel)
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

local function resolveRequestedRef(requested)
	local tags = fetchAllTags()
	if type(tags) ~= "table" then
		error("Could not read repository versions from jsDelivr.")
	end

	if requested == nil or requested == "" or requested == "latest" or requested == "stable" or requested == "main" then
		local latestStable = selectLatestTag(tags, "stable")
		if latestStable == nil then
			error("No stable semver tag found. Parsed " .. tostring(#tags) .. " semver tag(s) from jsDelivr.")
		end
		return latestStable
	end

	if requested == "beta" or requested == "development" then
		local latestBeta = selectLatestTag(tags, "beta")
		if latestBeta == nil then
			error("No beta semver tag found.")
		end
		return latestBeta
	end

	for _, tag in ipairs(tags) do
		if tag.raw == requested then
			return tag.raw
		end
	end

	if requested:sub(1, 1) ~= "v" and requested:sub(1, 1) ~= "V" then
		local prefixed = "v" .. requested
		for _, tag in ipairs(tags) do
			if tag.raw == prefixed then
				return tag.raw
			end
		end
	end

	error("Tag not found: " .. tostring(requested))
end

local function resolveRefFromArgs()
	if #arg == 1 then
		return resolveRequestedRef(arg[1])
	end

	return resolveRequestedRef("latest")
end

local function setRelUrl(ref)
	return repoUrl .. ref .. "/EnergyMonitor/"
end

local function downloadInstallerCompat()
	local compatUrl = setRelUrl(installerCompatRef)
	local installerPath = "/EnergyMonitor/install/installer.lua"
	local gotUrl = http.get(compatUrl .. "install/installer.lua")
	if gotUrl == nil then
		error("Could not download compatibility installer from " .. installerCompatRef)
	end

	local file = fs.open(installerPath, "w")
	file.write(gotUrl.readAll())
	file.close()
	gotUrl.close()
end

local function getLanguage()
	languages = downloadAndRead("supportedLanguages.txt")
	downloadAndExecuteClass("Language.lua")

	for k, v in pairs(languages) do
		print(k .. ") " .. v)
	end

	term.write("Language? (example: en): ")

	installLang = read()

	if installLang == "" or installLang == nil then
		installLang = "en"
	end

	if languages[installLang] == nil then
		error("Language not found!")
	else
		writeFile("lang/" .. installLang .. ".txt")
		selectedLang = _G.newLanguageById(installLang)
	end

	print(selectedLang:getText("language"))
end

--Removes old installations
local function removeAll()
	print(selectedLang:getText("removingOldFiles"))
	if fs.exists(relPath) then
		shell.run("rm " .. relPath)
	end
	if fs.exists("startup") then
		shell.run("rm startup")
	end
end

--Writes the files to the computer
function writeFile(path)
	local file = fs.open("/EnergyMonitor/" .. path, "w")
	local content = getURL(path)
	file.write(content)
	file.close()
end

--Resolve the right url
function getURL(path)
	local gotUrl = http.get(relUrl .. path)
	if gotUrl == nil then
		clearTerm()
		error("File not found! Please check!\nFailed at " .. relUrl .. path)
	else
		return gotUrl.readAll()
	end
end

function downloadAndExecuteClass(fileName)
	writeFile("classes/" .. fileName)
	shell.run("/EnergyMonitor/classes/" .. fileName)
end

function downloadAndRead(fileName)
	writeFile(fileName)
	local fileData = fs.open("/EnergyMonitor/" .. fileName, "r")
	local list = fileData.readAll()
	fileData.close()

	return textutils.unserialise(list)
end

--Clears the terminal
function clearTerm()
	shell.run("clear")
	term.setCursorPos(1, 1)
end

function install(versionRef)
	removeAll()

	relUrl = setRelUrl(versionRef)

	--Downloads the installer
	downloadInstallerCompat()

	--execute installer
	shell.run("/EnergyMonitor/install/installer.lua install " .. versionRef .. " " .. installLang)
end

local requestedRef = resolveRefFromArgs()
relUrl = setRelUrl(requestedRef)

getLanguage()
install(requestedRef)
os.reboot()
