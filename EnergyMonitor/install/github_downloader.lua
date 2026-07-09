-- Extreme Reactors Control by SeekerOfHonjo --
-- Original work by Thor_s_Crafter on https://github.com/ThorsCrafter/Reactor-and-Turbine-control-program -- 
-- Init Program Downloader (GitLab) --

--===== Local variables =====

--Release or beta version?
local selectInstaller = ""

--Branch & Relative paths to the url and path
local installLang = "en"
local relPath = "/EnergyMonitor/"
--local repoUrl = "https://raw.githubusercontent.com/TrickShotMLG02/EnergyMonitor/"
local repoUrl = "https://rawcdn.githack.com/TrickShotMLG02/EnergyMonitor/"
local branch = "main"
local relUrl = repoUrl..branch.."/EnergyMonitor/"
local selectedLang = {}

function getLanguage()
	languages = downloadAndRead("supportedLanguages.txt")
	downloadAndExecuteClass("Language.lua")

	for k, v in pairs(languages) do
		print(k..") "..v)
	end

	term.write("Language? (example: en): ")

	installLang = read()

	if installLang == "" or installLang == nil then
		installLang = "en"
	end

	if languages[installLang] == nil then
		error("Language not found!")
	else
		writeFile("lang/"..installLang..".txt")
		selectedLang = _G.newLanguageById(installLang)
	end

	print(selectedLang:getText("language"))
	--selectedLang:dumpText()
end

--Removes old installations
function removeAll()
	print(selectedLang:getText("removingOldFiles"))
	if fs.exists(relPath) then
		shell.run("rm "..relPath)
	end
	if fs.exists("startup") then
		shell.run("rm startup")
	end
end

--Writes the files to the computer
function writeFile(path)
	local file = fs.open("/EnergyMonitor/"..path,"w")
	local content = getURL(path);
	file.write(content)
	file.close()
end

--Resolve the right url
function getURL(path)
	local gotUrl = http.get(relUrl..path)
	if gotUrl == nil then
		clearTerm()
		error("File not found! Please check!\nFailed at "..relUrl..path)
	else
		return gotUrl.readAll()
	end
end

function downloadAndExecuteClass(fileName)	
	writeFile("classes/"..fileName)
	shell.run("/EnergyMonitor/classes/"..fileName)
end

function downloadAndRead(fileName)
	writeFile(fileName)
	local fileData = fs.open("/EnergyMonitor/"..fileName,"r")
	local list = fileData.readAll()
	fileData.close()

	return textutils.unserialise(list)
end

--Clears the terminal
function clearTerm()
	shell.run("clear")
	term.setCursorPos(1,1)
end

function install(version)
	removeAll()

	--Downloads the installer
	writeFile("install/installer.lua")

	--execute installer
	shell.run("/EnergyMonitor/install/installer.lua install "..version.. " "..installLang)
end

if #arg == 1 then
	if arg[1] == "stable" then branch = "main"
	elseif arg[1] == "main" then branch = "main"
	elseif arg[1] == "beta" then branch = "development"
	elseif arg[1] == "development" then branch = "development"
	else
		error("Invalid branch!")
	end
end
getLanguage()
install(branch)
os.reboot()