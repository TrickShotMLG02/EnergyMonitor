-- Extreme Reactors Control by SeekerOfHonjo --
-- Original work by Thor_s_Crafter on https://github.com/ThorsCrafter/Reactor-and-Turbine-control-program -- 
-- Version 2.6 --
-- Installer (English) --


--===== Local Variables =====

local arg = {... }
local update
local versionRef = ""
--local repoUrl = "https://raw.githubusercontent.com/TrickShotMLG02/EnergyMonitor/"
local repoUrl = "https://cdn.jsdelivr.net/gh/TrickShotMLG02/EnergyMonitor@"
local selectedLang = {}
local installLang = nil

--Program arguments for updates
if #arg == 0 then
  error("This installer requires a version tag argument")

elseif #arg == 2 or #arg == 3 then

  if arg[1] == "update" then
    --Update!
    update = true
  elseif arg[1] == "install" then
    update = false
  else
    error("Invalid 1st argument!")
  end
  versionRef = arg[2]
  if #arg == 3 then
    installLang = arg[3]
  end
else
  error("0, 2, or 3 arguments required!")
end

--Url for file downloads
local relUrl = repoUrl..(versionRef:gsub("^v", "")).."/EnergyMonitor/"

--===== Functions =====

function getLanguage()
  local pickLang = true

  if _G.lang == nil then
  else
    --global lang 
    if installLang == nil then
      installLang = _G.lang
    end
  end

  pickLang = installLang == nil    

  if pickLang then    
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
  else
    downloadAndExecuteClass("Language.lua")
    writeFile("lang/"..installLang..".txt")
    selectedLang = _G.newLanguageById(installLang)
  end

	print(selectedLang:getText("language"))
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
    term.clear()
		error("File not found! Please check!\nFailed at "..relUrl..path)
	else
		return gotUrl.readAll()
	end
end


function readConfigFile()
  local fileRead = fs.open("/EnergyMonitor/config/options.txt","r")
  local optionList = textutils.unserialise(fileRead.readAll())
  fileRead.close()
  return optionList
end


function updateConfigFile(oldConfig)
  local fileRead = fs.open("/EnergyMonitor/config/options.txt","r")
  local newConfig = textutils.unserialise(fileRead.readAll())
  fileRead.close()

  -- check if key from oldConfig exists in newConfig, if so copy
  for k, v in pairs(oldConfig) do
    if newConfig[k] ~= nil then
      newConfig[k] = oldConfig[k]
    end
  end

  --Serialise the table
  local optList = textutils.serialise(newConfig)

  --Save optionList to the config file
  local fileSave = fs.open("/EnergyMonitor/config/options.txt","w")
  fileSave.writeLine(optList)
  fileSave.close()
end

--Saves all data basck to the options.txt file
function updateOptionFileWithLanguage()

    local fileRead = fs.open("/EnergyMonitor/config/options.txt","r")
    local optionList = textutils.unserialise(fileRead.readAll())
    fileRead.close()
    
    optionList["language"] = installLang

    --Serialise the table
    local optList = textutils.serialise(optionList)

	  --Save optionList to the config file
	  local fileSave = fs.open("/EnergyMonitor/config/options.txt","w")
    fileSave.writeLine(optList)
	  fileSave.close()
end

function updateOptionFile(option, value)
    local fileRead = fs.open("/EnergyMonitor/config/options.txt","r")
    local optionList = textutils.unserialise(fileRead.readAll())
    fileRead.close()
    
    optionList[option] = value

    --Serialise the table
    local optList = textutils.serialise(optionList)

    --Save optionList to the config file
    local fileSave = fs.open("/EnergyMonitor/config/options.txt","w")
    fileSave.writeLine(optList)
    fileSave.close()
end

local function backupDataDirectory()
  local dataDir = "/EnergyMonitor/data"
  local backupDir = "/EnergyMonitor_data_backup"

  if not fs.exists(dataDir) then
    return nil
  end

  if fs.exists(backupDir) then
    fs.delete(backupDir)
  end

  local ok = pcall(fs.move, dataDir, backupDir)
  if ok and fs.exists(backupDir) then
    return backupDir
  end

  return nil
end

local function ensureDirectory(path)
  if path == nil or path == "" then
    return
  end

  if fs.exists(path) then
    return
  end

  fs.makeDir(path)
end

local function restoreDirectoryContents(sourceDir, targetDir)
  if sourceDir == nil or targetDir == nil or not fs.exists(sourceDir) then
    return
  end

  ensureDirectory(targetDir)

  local entries = fs.list(sourceDir)
  for _, entry in ipairs(entries) do
    local sourcePath = sourceDir .. "/" .. entry
    local targetPath = targetDir .. "/" .. entry

    if fs.isDir(sourcePath) then
      restoreDirectoryContents(sourcePath, targetPath)
      pcall(fs.delete, sourcePath)
    else
      if fs.exists(targetPath) then
        pcall(fs.delete, targetPath)
      end

      pcall(fs.move, sourcePath, targetPath)
    end
  end
end

local function restoreDataDirectory(backupDir)
  if backupDir == nil or not fs.exists(backupDir) then
    return
  end

  restoreDirectoryContents(backupDir, "/EnergyMonitor/data")
  pcall(fs.delete, backupDir)
end

function downloadAndRead(fileName)
	writeFile(fileName)
	local fileData = fs.open("/EnergyMonitor/"..fileName,"r")
	local list = fileData.readAll()
	fileData.close()

	return textutils.unserialise(list)
end

function downloadAndExecuteClass(fileName)	
	writeFile("classes/"..fileName)
  shell.run("/EnergyMonitor/classes/"..fileName)
end

function getAllFiles()
	local fileEntries = downloadAndRead("files.txt")

	for k, v in pairs(fileEntries) do
	  print(v.name.." files...")

	  for fileCount = 1, #v.files do
      local fileName = v.files[fileCount]
      writeFile(fileName)
	  end

	  print(selectedLang:getText("done"))
	end
end

function getVersion()
  return versionRef
end

function waitForEnter()
  write(selectedLang:getText("pressEnter"))
  read()
end

function promptChoice(title, choices)
  while true do
    term.clear()
    term.setCursorPos(1,1)
    print(title)
    print()

    for i = 1, #choices do
      print(choices[i].key..") "..choices[i].label)
    end

    print()
    term.write("Input: ")
    local input = string.lower(read() or "")

    for i = 1, #choices do
      if input == string.lower(choices[i].key) then
        return choices[i].value
      end
    end

    print()
    print(selectedLang:getText("invalidInput"))
    sleep(1)
  end
end

function promptNumber(title, defaultValue, minValue, maxValue)
  while true do
    term.clear()
    term.setCursorPos(1,1)
    print(title)
    print()
    term.write("Input ["..defaultValue.."]: ")

    local input = read()
    if input == nil or input == "" then
      return defaultValue
    end

    local number = tonumber(input)
    if number ~= nil and number >= minValue and number <= maxValue and math.floor(number) == number then
      return number
    end

    print()
    print(selectedLang:getText("invalidInput").." ("..minValue.."-"..maxValue..")")
    sleep(1)
  end
end

function promptYesNo(title, details)
  while true do
    term.clear()
    term.setCursorPos(1,1)
    print(title)
    if details ~= nil and details ~= "" then
      print(details)
    end
    print()
    term.write("(y/n): ")

    local input = read()
    if selectedLang:yesCheck(input) then
      return true
    elseif selectedLang:noCheck(input) then
      return false
    end

    print()
    print(selectedLang:getText("invalidInput"))
    sleep(1)
  end
end

function promptYesNoInline(prompt)
  while true do
    term.write(prompt.." (y/n): ")
    local input = read()
    if selectedLang:yesCheck(input) then
      return true
    elseif selectedLang:noCheck(input) then
      return false
    end

    print(selectedLang:getText("invalidInput"))
  end
end

function configureInstall()
  while true do
    local config = {
      program = "",
      peripheralType = "n/a",
      transferType = "n/a",
      modemChannel = 5,
      historyMinutes = 5,
      historySaveInterval = 15,
      monitorOpenGraphOnStart = false
    }

    config.program = promptChoice("Select this computer's role", {
      { key = "s", label = "Server - collects client data and sends monitor updates", value = "server" },
      { key = "m", label = "Monitor - displays data from the server", value = "monitor" },
      { key = "c", label = "Client - reads one local energy peripheral", value = "client" }
    })

    if config.program == "client" then
      config.peripheralType = promptChoice("What is this client connected to?", {
        { key = "s", label = "Energy storage / capacitor", value = "capacitor" },
        { key = "t", label = "Energy transfer / meter", value = "transfer" }
      })

      if config.peripheralType == "transfer" then
        config.transferType = promptChoice("What transfer direction should this client report?", {
          { key = "0", label = "Input", value = "input" },
          { key = "1", label = "Output", value = "output" },
          { key = "2", label = "Both", value = "both" }
        })
      end
    end

    config.modemChannel = promptNumber("Set the modem channel/port used by this EnergyMonitor network", 5, 0, 65535)

    if config.program == "monitor" then
      config.historyMinutes = promptNumber("Set the stored energy history window in minutes", 5, 1, 120)
      config.historySaveInterval = promptNumber("Set the history save interval in seconds", 15, 5, 3600)
      config.monitorOpenGraphOnStart = promptYesNoInline("Open the graph view when this monitor starts?")
    end

    term.clear()
    term.setCursorPos(1,1)
    print("Configuration summary")
    print()
    print("Role: "..config.program)
    print("Modem channel/port: "..config.modemChannel)

    if config.peripheralType == "transfer" then
     print("Peripheral type: "..config.peripheralType)
     print("Transfer type: "..config.transferType)
    end

    if config.program == "monitor" then
      print("History window (minutes): "..config.historyMinutes)
      print("History save interval (seconds): "..config.historySaveInterval)
      print("Open graph on start: "..tostring(config.monitorOpenGraphOnStart))
    end

    print()

    if promptYesNoInline("Use these settings?") then
      return config
    end
  end
end

function configureLabel()
  if promptYesNo(selectedLang:getText("installerLabelLineOne"), selectedLang:getText("installerLabelInfo")) then
    term.clear()
    term.setCursorPos(1,1)
    term.write("Label: ")
    local lbl = read()

    if lbl ~= nil and lbl ~= "" then
      if os.setComputerLabel ~= nil then
        os.setComputerLabel(lbl)
      else
        shell.run("label", "set", lbl)
      end
      print()
      print(selectedLang:getText("installerLabelSet"))
    else
      print()
      print(selectedLang:getText("installerLabelNotSet"))
    end
  else
    print()
    print(selectedLang:getText("installerLabelNotSet"))
  end

  sleep(1)
end

function configureStartup()
  if promptYesNo(selectedLang:getText("installerStartupLineOne"), selectedLang:getText("installerStartupLineTwo")) then
    local file = fs.open("startup","w")
    file.writeLine("shell.run(\"/EnergyMonitor/start/start.lua\")")
    file.close()
    print()
    print(selectedLang:getText("installerStartupInstalled"))
  else
    print()
    print(selectedLang:getText("installerStartupUninstalled"))
  end

  sleep(1)
end

--===== Run installation =====

local installConfig = {}

--load language data
getLanguage()

--First time installation
if not update then
  --Description
  term.clear()
  term.setCursorPos(1,1)
  print(selectedLang:getText("installerIntroLineOne"))
  print(selectedLang:getText("wordVersion").." "..getVersion())
  print()
  print(selectedLang:getText("installerIntroLineThree"))
  print(selectedLang:getText("installerIntroLineFour"))
  print(selectedLang:getText("installerIntroLineFive"))
  print(selectedLang:getText("installerIntroLineSix"))
  print(selectedLang:getText("installerIntroLineSeven"))
  print(selectedLang:getText("installerIntroLineEight"))
  print(selectedLang:getText("installerIntroLineNine"))
  print()
  waitForEnter()

  installConfig = configureInstall()
  configureLabel()
  configureStartup()
  sleep(1)
end --update

term.clear()
term.setCursorPos(1,1)

print(selectedLang:getText("installerFileCheck"))

local oldConfig = {}
local dataBackupDir = nil
if update then
  -- BACKUP CONFIG FILE IN LOCAL TABLE
  oldConfig = readConfigFile()
  dataBackupDir = backupDataDirectory()
end


--Removes old files
if fs.exists("/EnergyMonitor/program/") then
  shell.run("rm /EnergyMonitor/")
end

print(selectedLang:getText("installerGettingNewFiles"))
getAllFiles()
term.clear()
term.setCursorPos(1,1)


if update then
  -- write back updated config file
  updateConfigFile(oldConfig)
  restoreDataDirectory(dataBackupDir)
end


print(selectedLang:getText("updatingStartup"))
--Refresh startup (if installed)
if fs.exists("startup") then
  shell.run("rm startup")
  local file = fs.open("startup","w")
  file.writeLine("shell.run(\"/EnergyMonitor/start/start.lua\")")
  file.close()
end

--settings language
term.clear()
term.setCursorPos(1,1)
updateOptionFileWithLanguage()

--settings
if not update then
  updateOptionFile("program", installConfig.program)
  updateOptionFile("transferType", installConfig.transferType)
  updateOptionFile("peripheralType", installConfig.peripheralType)
  updateOptionFile("modemChannel", installConfig.modemChannel)
  updateOptionFile("historyMinutes", installConfig.historyMinutes)
  updateOptionFile("historySaveInterval", installConfig.historySaveInterval)
  updateOptionFile("monitorOpenGraphOnStart", installConfig.monitorOpenGraphOnStart)
end

updateOptionFile("version", getVersion())

-- update options file with program to run and meter/storage



--Install complete
term.clear()
term.setCursorPos(1,1)

if not update then
  print(selectedLang:getText("installerOutroLineOne"))
  print(selectedLang:getText("installerOutroLineTwo"))
  print()
  term.setTextColor(colors.green)
  print()
  print(selectedLang:getText("installerOutroLineThree").." ;)")
  print(selectedLang:getText("installerOutroLineFour"))
  print()
  print("TrickShotMLG")
  print("(c) 2026")

  local x,y = term.getSize()
  term.setTextColor(colors.yellow)
  term.setCursorPos(1,y)
  term.write("Reboot in ")
  for i=5,0,-1 do
    term.setCursorPos(11,y)
    term.write(i)
    sleep(1)
  end
end

shell.completeProgram("/EnergyMonitor/install/installer.lua")


