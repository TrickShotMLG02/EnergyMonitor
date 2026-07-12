-- Extreme Reactors Control by SeekerOfHonjo --
-- Original work by Thor_s_Crafter on https://github.com/ThorsCrafter/Reactor-and-Turbine-control-program --
-- Init Program Downloader (GitHub tags) --

--===== Local variables =====

local installLang = "en"
local relPath = "/EnergyMonitor/"

local repoOwner = "TrickShotMLG02"
local repoName = "EnergyMonitor"
local repoUrl = "https://cdn.jsdelivr.net/gh/" .. repoOwner .. "/" .. repoName .. "@"
local tagsApiUrl = "https://api.github.com/repos/" .. repoOwner .. "/" .. repoName .. "/tags"
local selectedLang = {}

local function apiHeaders()
	return {
		["Accept"] = "application/vnd.github+json",
		["X-GitHub-Api-Version"] = "2026-03-10",
		["User-Agent"] = "EnergyMonitor"
	}
end

local function requestJson(url)
	local response = http.get(url, apiHeaders())
	if response == nil then
		return nil
	end

	local body = response.readAll()
	response.close()

	local ok, data = pcall(textutils.unserializeJSON, body)
	if not ok then
		return nil
	end

	return data
end

local function stripVersionPrefix(tag)
	if tag == nil then
		return nil
	end

	tag = tostring(tag)
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

	local core, prerelease = normalized:match("^([^%-]+)(%-.+)?$")
	if core == nil then
		return nil
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
	local page = 1

	while true do
		local data = requestJson(tagsApiUrl .. "?per_page=100&page=" .. page)
		if type(data) ~= "table" or #data == 0 then
			break
		end

		for _, entry in ipairs(data) do
			if type(entry) == "table" and type(entry.name) == "string" then
				local parsed = parseSemverTag(entry.name)
				if parsed ~= nil then
					table.insert(tags, parsed)
				end
			end
		end

		if #data < 100 then
			break
		end

		page = page + 1
	end

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
		error("Could not read repository tags from GitHub.")
	end

	if requested == nil or requested == "" or requested == "latest" or requested == "stable" or requested == "main" then
		local latestStable = selectLatestTag(tags, "stable")
		if latestStable == nil then
			error("No stable semver tag found.")
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
	writeFile("install/installer.lua")

	--execute installer
	shell.run("/EnergyMonitor/install/installer.lua install " .. versionRef .. " " .. installLang)
end

local requestedRef = resolveRefFromArgs()
relUrl = setRelUrl(requestedRef)

getLanguage()
install(requestedRef)
os.reboot()
