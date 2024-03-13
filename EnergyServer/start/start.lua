-- Extreme Reactors Control by SeekerOfHonjo --
-- Original work by Thor_s_Crafter on https://github.com/ThorsCrafter/Reactor-and-Turbine-control-program -- 
-- Version 1.0 --
-- Start program --

--========== Global variables for all program parts ==========

--All options
_G.optionList = {}
_G.version = 0
_G.backgroundColor = 0
_G.textColor = 0
_G.mainMenu = ""
_G.lang = ""
_G.program = ""
 _G.debugEnabled = 0
_G.location = ""
_G.modemChannel = 0
_G.wirelessModemLocation = "top"
_G.language = {}

--TouchpointLocation (same as the monitor)
_G.touchpointLocation = {}

--========== Global functions for all program parts ==========

--===== Functions for loading and saving the options =====

local repoUrl = "https://gitlab.com/seekerscomputercraft/extremereactorcontrol/-/raw/"

function  _G.debugOutput(message) 
	if  _G.debugEnabled == 1 then
		print(message)
	end
end

--Loads the options.txt file and adds values to the global variables
function _G.loadOptionFile()
	debugOutput("Loading Option File")
	--Loads the file
	local file = fs.open("/EnergyServer/config/options.txt","r")
	local list = file.readAll()
	file.close()

    --Insert Elements and assign values
    _G.optionList = textutils.unserialise(list)

	--Assign values to variables
	_G.version = optionList["version"]
	_G.backgroundColor = tonumber(optionList["backgroundColor"])
	_G.textColor = tonumber(optionList["textColor"])
	_G.mainMenu = optionList["mainMenu"]
	_G.program = optionList["program"]
	_G.debugEnabled = optionList["debug"]
	_G.lang = optionList["language"]
	_G.location = optionList["location"]
	_G.modemChannel = optionList["modemChannel"]
end

--Refreshes the options list
function _G.refreshOptionList()
	debugOutput("Refreshing Option List")
	debugOutput("Variable: version")
	optionList["version"] = version
	debugOutput("Variable: backgroundColor"..backgroundColor)
	optionList["backgroundColor"] = backgroundColor
	debugOutput("Variable: textColor = "..textColor)
	optionList["textColor"] = textColor
	debugOutput("Variable: mainMenu")
	optionList["mainMenu"] = mainMenu
	debugOutput("Variable: program")
	optionList["program"] = program
	debugOutput("Variable: lang")
	optionList["language"] = lang
	debugOutput("Variable: location")
	optionList["location"] = location
	debugOutput("Variable: modemChannel")
	optionList["modemChannel"] = modemChannel
	optionList["debug"] = debug
end

--Saves all data back to the options.txt file
function _G.saveOptionFile()
	debugOutput("Saving Option File")
	--Refresh option list
	refreshOptionList()
    --Serialise the table
    local list = textutils.serialise(optionList)
	--Save optionList to the config file
	local file = fs.open("/EnergyServer/config/options.txt","w")
    file.writeLine(list)
	file.close()
	print("Saved.")
end


--===== Automatic update detection =====

--Check for updates
function _G.checkUpdates()

	--Check current branch (release or beta)
	local currBranch = ""
	local tmpString = string.sub(version,5,5)
	if tmpString == "" or tmpString == nil or tmpString == "r" then
		currBranch = "main"
	elseif tmpString == "b" then
		currBranch = "develop"
	end

	--Get Remote version file
	downloadFile(repoUrl..currBranch.."/",currBranch..".ver")

	--Compare local and remote version
	local file = fs.open(currBranch..".ver","r")
	local remoteVer = file.readLine()
	file.close()
	
	print("Energy Storage Devices: "..(#capacitors + 1))
	print("localVer: "..version)
	
    if remoteVer == nil then
		print("Couldn't get remote version from gitlab.")
	else
		print("remoteVer: "..remoteVer)
		print("Update? -> "..tostring(remoteVer > version))
	
	    --Update if available
	    if remoteVer > version then
		    print("Update...")
		    sleep(2)
		    doUpdate(remoteVer,currBranch)
	    end
	end

	--Remove remote version file
	shell.run("rm "..currBranch..".ver")
end


function _G.doUpdate(toVer,branch)

	--Set the monitor up
	local x,y = controlMonitor.getSize()
	controlMonitor.setBackgroundColor(colors.black)
	controlMonitor.clear()

	local x1 = x/2-15
	local y1 = y/2-4
	local x2 = x/2
	local y2 = y/2

	--Draw Box
	controlMonitor.setBackgroundColor(colors.gray)
	controlMonitor.setTextColor(colors.gray)
	controlMonitor.setCursorPos(x1,y1)
	for i=1,8 do
		controlMonitor.setCursorPos(x1,y1+i-1)
		controlMonitor.write("                              ") --30 chars
	end

	--Print update message
	controlMonitor.setTextColor(colors.white)

	controlMonitor.setCursorPos(x2-9,y1+1)
	controlMonitor.write(_G.language:getText("updateAvailableLineOne")) --17 chars

	controlMonitor.setCursorPos(x2-(math.ceil(string.len(toVer)/2)),y1+3)
	controlMonitor.write(toVer)

	controlMonitor.setCursorPos(x2-8,y1+5)
	controlMonitor.write(_G.language:getText("updateAvailableLineTwo")) --15 chars

	controlMonitor.setCursorPos(x2-12,y1+6)
	controlMonitor.write(_G.language:getText("updateAvailableLineThree")) --24 chars

	--Print install instructions to the terminal
	term.clear()
	term.setCursorPos(1,1)
	local tx,ty = term.getSize()

	print(_G.language:getText("updateProgram"))
	term.write("Input: ")

	--Run Counter for installation skipping
	local count = 10
	local out = false

	term.setCursorPos(tx/2-5,ty)
	term.write(" -- 10 -- ")

	while true do

		local timer1 = os.startTimer(1)

		while true do

			local event, p1 = os.pullEvent()

			if event == "key" then

				if p1 == 36 or p1 == 21 then
					shell.run("/EnergyServer/install/installer.lua update "..branch)
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
end

--Download Files (For Remote version file)
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
    --Execute necessary class files
    local binPath = "/EnergyServer/classes/"
    shell.run(binPath.."base/EnergyStorage.lua")
    shell.run(binPath.."mekanism/MekanismEnergyStorage.lua")
    shell.run(binPath.."Peripherals.lua")
    shell.run(binPath.."Language.lua")
	shell.run(binPath.."transport/startup.lua")
    shell.run(binPath.."transport/wrapper.lua")
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

debugOutput("Checking for Updates")

-- check for updates in gitlab/github branch (NOT NEEDED)
--checkUpdates()

--Run program or main menu, based on the settings
if mainMenu then
	shell.run("/EnergyServer/start/menu.lua")
	shell.completeProgram("/EnergyServer/start/start.lua")
else
	if program == "server" then
		shell.run("/EnergyServer/program/server.lua")
	elseif program == "client" then
		shell.run("/EnergyServer/program/client.lua")
	elseif program == "monitor" then
		shell.run("/EnergyServer/program/monitor.lua")
	end
	shell.completeProgram("/EnergyServer/start/start.lua")
end


--========== END OF THE START.LUA FILE ==========
