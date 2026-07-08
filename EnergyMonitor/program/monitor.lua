local basalt = require("basalt")

local displayData = {
    clientInfo = {},
    displayFrm = {},
    dpName = "",
    dpRateIn = "",
    dpRateOut = "",
    dpType = "",
    dpState = ""
}

local capacitors = {}
local capacitorsCount = 0
local transferrers = {}
local sortedTransferrers = {}
local transferrersCount = 0
local storedEnergy = 0
local maxEnergy = 0
local energyPercentage = 0
local inputRate = 0
local outputRate = 0
local effectiveRate = 0
local monitorUpdateAvailable = false
local lastUpdateCheck = -60
local noticeBlinkState = false

local displayFilter = {
    showDisconnected = true,
    showInput = true,
    showOutput = true,
}

local sortingAttr = "name"
local sortingDir = "asc"

-- debugging
local debugPrint = true
local debugUI = false
local lastServerWarning = 0

-- table contrains energyMeters[i].id as key and the value is the displayData{clientInfo = energyMeters[i], display = already created frame}
local displayCells = {}
setmetatable(displayCells, {__index = "displayData"})


-- GUI COMPONENT SETTINGS

-- header settings
local headerHeight = 5
local headerColor = colors.blue
local filterHeaderHeight = 2
local filterHeaderColor = colors.lightBlue
local filterHeaderBtnSpacing = 2

-- footer settings (including prev/next buttons and page label)
local footerHeight = 3
local footerColor = colors.green
local btnWidth,btnHeight = 6,1
local lblWidth,lblHeight = 20, btnHeight
local btnDefaultColor, btnClickedColor = colors.gray, colors.lime
local btnHighlighDuration = 0.2

-- version footer settings
local versionFooterHeight = 1
local versionFooterColor = colors.lightBlue


-- all settings for displayed cells
local cellWidth, cellHeight = 18, 6
local cellBackground = colors.yellow
local cellSpacing = 1

-- background Color
local bgColor = colors.lightGray

-- if not debug mode, set header and footer color to bgColor
if not debugUI then
    headerColor = bgColor
    filterHeaderColor = bgColor
    footerColor = bgColor
end

-- GUI COMPONENT SETTINGS END



-- GUI COMPONENTS

local displayedCells = {}
local versionLbl = {}
local versionNoticeLbl = {}

-- create main window
local main = basalt.addMonitor()
main:setMonitor(_G.controlMonitor)
local monitorRoot = main

-- default content pane
local flex = main:addFlexbox():setWrap("wrap"):setBackground(colors.red):setPosition(1, 1):setSize("parent.w", "parent.h"):setDirection("column"):setSpacing(0)

-- frame that contains the header (energy stored, input/output rates)
local header = flex:addFrame():setBackground(headerColor):setSize("parent.w", headerHeight)
local filterHeader = flex:addFlexbox():setWrap("wrap"):setBackground(filterHeaderColor):setSize("parent.w", filterHeaderHeight):setSpacing(filterHeaderBtnSpacing):setJustifyContent("center")
local filterAllBtn = {}
local filterInputBtn = {}
local filterOutputBtn = {}
local filterBtnGroup = {}
local sortAttrBtn = {}
local sortOrderBtn = {}

-- flexbox that contains the individual energy meter displays
local main = flex:addFlexbox():setWrap("wrap"):setBackground(bgColor):setSize("parent.w", "parent.h" .. "-" .. headerHeight + filterHeaderHeight + footerHeight + versionFooterHeight):setSpacing(cellSpacing):setJustifyContent("center")--:setOffset(-1, 0)

-- frame that contains the footer (previous, next, page number)
local footer = flex:addFrame():setBackground(footerColor):setSize("parent.w", footerHeight)
local prevBtn = {}
local nextBtn = {}
local versionFooter = flex:addFrame():setBackground(versionFooterColor):setSize("parent.w", 1)
local timeLbl = {}
local noticeFrame = {}
local noticeTitle = {}
local noticeLineOne = {}
local noticeLineTwo = {}
local noticeLineThree = {}

-- amount of cells per page
local flexWidth, flexHeight = main:getSize()
local numCellsRow = math.floor((flexWidth + cellSpacing) / (cellWidth + cellSpacing))
local numCellsCol = math.floor((flexHeight + cellSpacing) / (cellHeight + cellSpacing))
local totalCellsPerPage = numCellsRow * numCellsCol

-- static elements with dynamic content
local pageLbl = {}

local energyLbl = {}
local energyBar = {}

local rateLblIn = {}
local rateLblOut = {}
local effectiveRateLbl = {}
local etaLbl = {}

-- GUI COMPONENTS END

-- page settings
local currentPageId = 1
local totalPageCount = 1


---------------------------
-- function declarations --
---------------------------
local checkFilter
local reloadPage
local listen
local addDisplayCell
local removeDisplayCell
local updateEnergyDisplay
local updateTransferDisplay
local updateDisplayCells
local countDisplayableCells
local updatePageCount
local updateMonitorValues
local updateRuntimeFooter
local showServerNotice
local hideServerNotice
local animateButtonClick
local animateButtonToggle
local animateButtonToggleGroup
local nextPage
local prevPage
local toggleFilterShowDisconnected
local toggleFilterShowSpecificType
local setupMonitor
local toggleSortDirText
local toggleSortAttrText
local sortTransferrers
local toggleFilterShowSpecificTypeText

--------------------------
-- function definitions --
--------------------------

---------------------
-- Retrieving Data --
---------------------

-- function to receive monitor data from server
listen = function()
    -- Receive data from server
    while true do
        local msg = _G.receiveMessage({
            type = _G.MessageType.Monitor,
            sender = _G.Sender.Server,
            recipient = _G.Sender.Monitor
        }, 10)

        if msg == nil then
            local now = os.clock()
            if now - lastServerWarning >= 10 then
                lastServerWarning = now
                showServerNotice()
            end
        elseif msg.type == _G.MessageType.Monitor and msg.sender == _G.Sender.Server then
            hideServerNotice()
            
            local clock = os.clock()
            if debugPrint then
                term.redirect(term.native())
                term.clear()
                term.setCursorPos(1,1)
                print(clock)
                print("Receiving monitor data from server on channel: ".._G.modemChannel)
            end

            -- extract data from message
            local data = msg.data

            capacitors = data.capacitors
            capacitorsCount = data.capacitorsCount
            transferrers = data.transferrers
            transferrersCount = data.transferrersCount
            storedEnergy = data.storedEnergy
            maxEnergy = data.maxEnergy
            energyPercentage = data.energyPercentage
            inputRate = data.inputRate
            outputRate = data.outputRate

            -- calculate if the energy storage is being charged or discharged
            effectiveRate = inputRate - outputRate
			
			-- sort the transferrers that are displayed on screen based on filters
			sortTransferrers()

            -- update monitor display with new values
			reloadPage()
            updateVersionFooter()
        end
    end
end

checkMonitorUpdates = function()
    local now = os.clock()
    if now - lastUpdateCheck < 60 then
        return
    end

    lastUpdateCheck = now

    if _G.version == nil or _G.version == "n/a" or _G.repoUrl == nil then
        monitorUpdateAvailable = false
        updateVersionFooter()
        return
    end

    local currBranch = ""
    if string.find(_G.version, "beta") or string.find(_G.version, "development") then
        currBranch = "development"
    else
        currBranch = "main"
    end

    local ok = pcall(_G.downloadFile, _G.repoUrl..currBranch.."/EnergyMonitor/", currBranch..".ver")
    if not ok then
        monitorUpdateAvailable = false
        updateVersionFooter()
        return
    end

    local file = fs.open(currBranch..".ver", "r")
    if file == nil then
        monitorUpdateAvailable = false
        updateVersionFooter()
        return
    end

    local remoteVer = file.readLine()
    file.close()
    shell.run("rm "..currBranch..".ver")

    if remoteVer == nil then
        monitorUpdateAvailable = false
        updateVersionFooter()
        return
    end

    local versionSeparator = string.find(_G.version, "-")
    local remoteVersionSeparator = string.find(remoteVer, "-")
    if versionSeparator == nil or remoteVersionSeparator == nil then
        monitorUpdateAvailable = false
        updateVersionFooter()
        return
    end

    local vNum = string.sub(_G.version, 0, versionSeparator - 1)
    local rvNum = string.sub(remoteVer, 0, remoteVersionSeparator - 1)
    monitorUpdateAvailable = rvNum > vNum
    updateVersionFooter()
end

updateVersionFooter = function()
    if versionLbl ~= nil and versionLbl.setText ~= nil then
        local versionText = "version: " .. _G.version
        local versionTextWidth = math.max(1, string.len(versionText))
        local noticeText = _G.language:getText("updateFooterAvailable")
        local noticeTextWidth = math.max(1, string.len(noticeText))

        versionLbl:setForeground(colors.gray)

        if monitorUpdateAvailable then
            versionLbl:setText(versionText)
            versionLbl:setSize(versionTextWidth, 1)
            versionLbl:setPosition("parent.w-" .. (versionTextWidth + noticeTextWidth + 1), versionFooterHeight)
            versionLbl:setTextAlign("left")

            if versionNoticeLbl ~= nil and versionNoticeLbl.setText ~= nil then
                versionNoticeLbl:setText(noticeText)
                versionNoticeLbl:setSize(noticeTextWidth, 1)
                versionNoticeLbl:setPosition("parent.w-" .. noticeTextWidth, versionFooterHeight)
                versionNoticeLbl:setTextAlign("left")
                versionNoticeLbl:setForeground(noticeBlinkState and colors.red or versionFooterColor)
                if versionNoticeLbl.show ~= nil then
                    versionNoticeLbl:show()
                end
            end
        else
            versionLbl:setText(versionText)
            versionLbl:setSize(versionTextWidth, 1)
            versionLbl:setPosition("parent.w-" .. versionTextWidth, versionFooterHeight)
            versionLbl:setTextAlign("left")

            if versionNoticeLbl ~= nil and versionNoticeLbl.hide ~= nil then
                versionNoticeLbl:hide()
            end
        end
    end
end

updateRuntimeFooterLabel = function()
    if timeLbl ~= nil and timeLbl.setText ~= nil then
        local runtimeText = "Time running: " .. _G.convertTicksToTime(os.clock() * 20)
        local runtimeTextWidth = math.max(1, string.len(runtimeText))
        timeLbl:setText(runtimeText)
        timeLbl:setSize(runtimeTextWidth, 1)
        timeLbl:setPosition(1, versionFooterHeight)
        timeLbl:setTextAlign("left")
    end
end



--------------
-- Setup UI --
--------------

-- set up all ui element references 
setupMonitor = function()
    -- setup header
    energyLbl = header:addLabel():setText("Energy: STORED"):setFontSize(1):setSize("parent.w / 2", 1):setPosition(0, 1):setTextAlign("center")
    energyBar = header:addProgressbar():setProgress(0):setSize("parent.w / 3", 1):setPosition("1/12 * parent.w", 3):setProgressBar(colors.lime):setDirection("right"):setBackground(colors.black)
    rateLblIn = header:addLabel():setText("Transfer: IN"):setFontSize(1):setSize("parent.w / 3", 1):setPosition("2 * parent.w / 3", 1):setTextAlign("left")
    rateLblOut = header:addLabel():setText("Transfer: OUT" ):setFontSize(1):setSize("parent.w / 3", 1):setPosition(" 2 * parent.w / 3", 2):setTextAlign("left")
    effectiveRateLbl = header:addLabel():setText("Eff. Rate: "):setFontSize(1):setSize("parent.w / 3", 1):setPosition("2 * parent.w / 3", 3):setTextAlign("left")
    etaLbl = header:addLabel():setText("ETA: "):setFontSize(1):setSize("parent.w / 3", 1):setPosition("2 * parent.w / 3", 4):setTextAlign("left")

    -- setup filter header
    local showDisconnectedBtn = filterHeader:addButton():setText("Hide Disconnected"):setSize(19, 1):setBackground(btnDefaultColor):onClick(basalt.schedule(function(self)
        animateButtonClick(self)
        toggleFilterShowDisconnected(self)
      end))

    filterAllBtn = filterHeader:addButton():setText("Filter All"):setSize(12, 1):setBackground(btnDefaultColor)
    
    filterAllBtn:onClick(basalt.schedule(function(self)
        animateButtonClick(self)
        toggleFilterShowSpecificTypeText(self)
      end))

    
    sortAttrBtn = filterHeader:addButton():setText("Sort by Name"):setSize(14, 1):setBackground(btnDefaultColor)
    sortOrderBtn = filterHeader:addButton():setText("Sort Ascending"):setSize(16, 1):setBackground(btnDefaultColor)

    sortAttrBtn:onClick(basalt.schedule(function(self)
        animateButtonClick(self)
        toggleSortAttrText(self)
      end))

    sortOrderBtn:onClick(basalt.schedule(function(self)
        animateButtonClick(self)
        toggleSortDirText(self)
      end))

      
    -- setup footer
    prevBtn = footer:addButton():setText("Prev"):setSize(btnWidth, btnHeight):setPosition(2, math.ceil(footerHeight / 2) + math.floor(btnHeight / 2)):setBackground(btnDefaultColor):onClick(basalt.schedule(function(self)
        animateButtonClick(self)
      end), prevPage)
    pageLbl = footer:addLabel():setText("Page: 0/0"):setFontSize(1):setSize(lblWidth,lblHeight):setPosition("(parent.w / 2) - " .. (lblWidth / 2), math.ceil(footerHeight / 2) + math.floor(btnHeight / 2)):setTextAlign("center")
    nextBtn = footer:addButton():setText("Next"):setSize(btnWidth, btnHeight):setPosition("parent.w-"..btnWidth, math.ceil(footerHeight / 2) + math.floor(btnHeight / 2)):setBackground(btnDefaultColor):onClick(basalt.schedule(function(self)
        animateButtonClick(self)
      end), nextPage)
    versionLbl = versionFooter:addLabel():setText("version: " .. _G.version):setFontSize(1):setSize(1, 1):setPosition("parent.w", versionFooterHeight):setTextAlign("left"):setForeground(colors.gray)
    versionNoticeLbl = versionFooter:addLabel():setText(""):setFontSize(1):setSize(1, 1):setPosition("parent.w", versionFooterHeight):setTextAlign("left"):setForeground(colors.red):hide()
    timeLbl = versionFooter:addLabel():setText("Time running: 0s"):setFontSize(1):setSize(1, 1):setPosition(1, versionFooterHeight):setTextAlign("left"):setForeground(colors.gray)
    updateVersionFooter()
    updateRuntimeFooterLabel()
    checkMonitorUpdates()

    noticeFrame = monitorRoot:addFrame()
        :setBackground(colors.gray)
        :setForeground(colors.white)
        :setSize(36, 8)
        :setPosition("(parent.w / 2) - 18", "(parent.h / 2) - 4")
        :setZIndex(50)
        :hide()
    noticeTitle = noticeFrame:addLabel():setText("Server not reachable"):setSize("parent.w", 1):setPosition(1, 2):setTextAlign("center"):setForeground(colors.white)
    noticeLineOne = noticeFrame:addLabel():setText("No update received."):setSize("parent.w", 1):setPosition(1, 4):setTextAlign("center"):setForeground(colors.white)
    noticeLineTwo = noticeFrame:addLabel():setText("Channel: " .. tostring(_G.modemChannel)):setSize("parent.w", 1):setPosition(1, 5):setTextAlign("center"):setForeground(colors.white)
    noticeLineThree = noticeFrame:addLabel():setText("Check server/modems."):setSize("parent.w", 1):setPosition(1, 6):setTextAlign("center"):setForeground(colors.white)

    -- auto update the monitor
    basalt.autoUpdate()
end

showServerNotice = function()
    if noticeFrame ~= nil and noticeFrame.show ~= nil then
        noticeLineTwo:setText("Channel: " .. tostring(_G.modemChannel))
        noticeFrame:show()
    end
end

hideServerNotice = function()
    if noticeFrame ~= nil and noticeFrame.hide ~= nil then
        noticeFrame:hide()
    end
end

-- add a new display cell for a given peripheral id
addDisplayCell = function(peripheralId)
    -- add display cell to the monitor
    if displayCells[peripheralId] == nil then
        -- reload page and update displayed cells
        reloadPage()
    else
        -- update values stored in table
        displayCells[peripheralId].clientInfo = transferrers[peripheralId]
    end
end

-- remove an existing display cell for a given peripheral id
removeDisplayCell = function(peripheralId)
    -- remove display cell from the monitor
    if displayCells[peripheralId] ~= nil then
        displayCells[peripheralId].displayFrm:remove()
        displayCells[peripheralId] = nil

        -- reload page and update displayed cells
        reloadPage()
    end
end



----------------------
-- UPDATE UI VALUES --
----------------------

-- function to update the stored energy on UI
updateEnergyDisplay = function()
    energyLbl:setText("Energy: " .. _G.numberToEnergyUnit(storedEnergy) .. "/" .. _G.numberToEnergyUnit(maxEnergy) .. " (" .. _G.formatDecimals(energyPercentage, 2) .. "%)")
    energyBar:setProgress(tonumber(_G.defaultInf(_G.defaultNil(_G.formatDecimals(energyPercentage, 0), 0), 0)))
end

-- function to update the current energy transfer on UI
updateTransferDisplay = function()
    rateLblIn:setText("Transfer IN: " .. _G.numberToEnergyUnit(inputRate) .. "/t")
    rateLblOut:setText("Transfer OUT: " .. _G.numberToEnergyUnit(outputRate) .. "/t")

    -- adjust effective rate (green for positive/red for negative)
    local effectiveRateColor = {}
    if effectiveRate < 0 then
        effectiveRateColor = colors.red
        effectiveRateLbl:setText("Eff. Rate: -" .. _G.numberToEnergyUnit(effectiveRate * -1) .. "/t")
    elseif effectiveRate > 0 then
        effectiveRateColor = colors.lime
        effectiveRateLbl:setText("Eff. Rate: +" .. _G.numberToEnergyUnit(effectiveRate) .. "/t")
    else
        effectiveRateColor = colors.yellow
        effectiveRateLbl:setText("Eff. Rate: +" .. _G.numberToEnergyUnit(effectiveRate) .. "/t")
    end
    effectiveRateLbl:setForeground(effectiveRateColor)



    -- calculate estimated time until full/empty
    local eta = 0
    
    if effectiveRate < 0 then
        -- time until empty
        eta = storedEnergy / effectiveRate
        etaLbl:setText("ETA: " .. _G.convertTicksToTime(-eta))
    elseif effectiveRate > 0 then
        -- time until full
        eta = (maxEnergy - storedEnergy) / effectiveRate
        etaLbl:setText("ETA: " .. _G.convertTicksToTime(eta))
    else
        -- time should be "inf"
        eta = -1
        etaLbl:setText("ETA: inf")
    end
end

-- function to update all display cells (transferrers) with their new current values
updateDisplayCells = function()
    for k,v in pairs(displayCells) do
        local i = v.clientInfo
        local d = i.data
        displayCells[k].dpName:setText(d.name)

        if displayCells[k].dpRateIn then
            displayCells[k].dpRateIn:setText(_G.numberToEnergyUnit(d.transferIn) .. "/t")
        end
        if displayCells[k].dpRateOut then
            displayCells[k].dpRateOut:setText(_G.numberToEnergyUnit(d.transferOut) .. "/t")
        end
        displayCells[k].dpType:setText(_G.parseTransferType(d.transferType))
        --displayCells[k].dpState:setText(d.status)
    end
end

-- function that simply returns how many display cells we need for all transferrers
countDisplayableCells = function ()
    local cnt = 0
    for k,v in pairs(transferrers) do
        if checkFilter(v) then
            cnt = cnt + 1
        end
    end
    return cnt
end

-- function that calculates how many pages we need to display all cells (transferrers)
updatePageCount = function()
    -- calculate pages needed to display all cells
    totalPageCount = math.ceil(countDisplayableCells() / totalCellsPerPage)

    -- total page count always >= 1, even if 0 display cells available
    totalPageCount = math.max(totalPageCount, 1)

    -- display page status on UI
    pageLbl:setText("Page: " .. currentPageId .. "/" .. totalPageCount)

    -- set currentPageId to last page if last page got deleted
    if currentPageId > totalPageCount or (currentPageId <= 0 and totalPageCount > 0)then
        currentPageId = totalPageCount

        reloadPage()
    end
end

-- function that is called to update the whole monitor screen using the above functions
updateMonitorValues = function()
    while true do

        -- iterate over all energy meters and add them to the display
        for k,v in ipairs(sortedTransferrers) do
            addDisplayCell(v.id)
        end

        -- remove all energy meters that are not in the received data
        for k,v in pairs(displayCells) do
            if transferrers[k] == nil then
                removeDisplayCell(k)
            end
        end

        updateEnergyDisplay()
        updateTransferDisplay()
        updateDisplayCells()
        
        if transferrersCount > 0 then
            updatePageCount()
        end

        os.sleep(0.1)
    end
end

updateRuntimeFooter = function()
    while true do
        updateRuntimeFooterLabel()
        if monitorUpdateAvailable then
            noticeBlinkState = not noticeBlinkState
        else
            noticeBlinkState = false
        end
        checkMonitorUpdates()
        updateVersionFooter()
        os.sleep(1)
    end
end



-----------------
-- CHANGE PAGE --
-----------------

-- function to load the next page
nextPage = function()
    if currentPageId < totalPageCount then
        currentPageId = currentPageId + 1
        reloadPage()
    end
end

-- function to load the previous page
prevPage = function()
    if currentPageId > 1 then
        currentPageId = currentPageId - 1
        reloadPage()
    end
end

-- function that updates all cells on the current page with their new values, handles filtering and updates page count
reloadPage = function()
    -- iterate over table with displays and hide all except the ones that are on the current page
    local startIdx = (currentPageId - 1) * totalCellsPerPage + 1
    local endIdx = currentPageId * totalCellsPerPage
    local currIdx = 1

    -- remove all cells from the monitor
    for k,v in pairs(displayedCells) do
        v:remove()
    end

    -- add cells to the monitor
    for i,v in ipairs(sortedTransferrers) do
        local k = v.id

        -- check display filter in addition to indices
        local matchesFilter = checkFilter(v)

        if currIdx >= startIdx and currIdx <= endIdx and matchesFilter then

            -- calculate relative index on the current page
            local relIdx = currIdx - startIdx + 1

            -- create new cell for every idx shown on the current page
            local frm = main:addFrame():setBackground(cellBackground):setSize(cellWidth, cellHeight)

            displayCells[k] = {
                clientInfo = transferrers[k],
                displayFrm = frm,
                dpName = frm:addLabel()
                    :setText(transferrers[k].name)
                    :setFontSize(1)
                    :setSize("parent.w-1", 1)
                    :setPosition(2, 2)
                    :setTextAlign("center"),
                
                dpType = frm:addLabel()
                    :setText(_G.parseTransferType(transferrers[k].data.transferType))
                    :setFontSize(1)
                    :setSize("parent.w-1", 1)
                    :setPosition(2, 3)
                    :setTextAlign("center"),

                -- Conditionally display input rate on line 4 if InputType is "Input" or "Both"
                dpRateIn = (transferrers[k].data.transferType == _G.TransferType.Input or transferrers[k].data.transferType == _G.TransferType.Both) and 
                frm:addLabel()
                    :setText(_G.numberToEnergyUnit(transferrers[k].data.transferIn) .. "/t")
                    :setFontSize(1)
                    :setSize("parent.w-1", 1)
                    :setPosition(2, 4)  -- Position on line 4
                    :setTextAlign("center") or nil,

            -- Conditionally display output rate on line 4 if InputType is "Output"
                dpRateOut = (transferrers[k].data.transferType == _G.TransferType.Output or transferrers[k].data.transferType == _G.TransferType.Both) and 
                frm:addLabel()
                    :setText(_G.numberToEnergyUnit(transferrers[k].data.transferOut) .. "/t")
                    :setFontSize(1)
                    :setSize("parent.w-1", 1)
                    :setPosition(2, transferrers[k].data.transferType == _G.TransferType.Both and 5 or 4)  -- Position on line 5 if Both
                    :setTextAlign("center") or nil,

                --dpState = frm:addLabel():setText(transferrers[k].data.status):setFontSize(1):setSize("parent.w-1", 1):setPosition(2, 6):setTextAlign("center")
            }

            displayedCells[relIdx] = frm
        end

        if matchesFilter then
            currIdx = currIdx + 1
        end
        
    end

    updatePageCount()
end



---------------
-- FILTERING --
---------------

-- function to check if a specific cell should be displayed according to set filters or not
checkFilter = function(displayData)
    -- check if the displayData should be shown on the monitor
    local disconnected = "DISCONNECTED"

    local status = displayData.data.status
    local transferType = displayData.data.transferType

    local showDisconnected = (displayFilter.showDisconnected and status == disconnected)
    local showConnected = status ~= disconnected
    local showInput = (displayFilter.showInput and (transferType == _G.TransferType.Input or transferType == _G.TransferType.Both))
    local showOutput = (displayFilter.showOutput and (transferType == _G.TransferType.Output or transferType == _G.TransferType.Both))

    local show = (showDisconnected and (showInput or showOutput)) or (showConnected and (showInput or showOutput))

    return show
end

-- toggle if disconnected devices should be shown or hidden
toggleFilterShowDisconnected = function(btn)
    displayFilter.showDisconnected = not displayFilter.showDisconnected
    if not displayFilter.showDisconnected then
        btn:setText("Show Disconnected")
    else
        btn:setText("Hide Disconnected")
    end

    reloadPage()
end

-- toggle to show cells only of specific type (input/output/all)
toggleFilterShowSpecificType = function(type)
    displayFilter.showInput = false
    displayFilter.showOutput = false
    if type == "Input" then
        displayFilter.showInput = true
    elseif type == "Output" then
        displayFilter.showOutput = true
    elseif type == "All" then
        displayFilter.showInput = true
        displayFilter.showOutput = true
    end

    reloadPage()
end



-------------
-- SORTING --
-------------

-- function to sort the transferrers by either name or rate ASC/DESC
sortTransferrers = function()
	sortedTransferrers = {}
	for k,v in pairs(transferrers) do table.insert(sortedTransferrers, v) end

    if sortingAttr == "name" then
        table.sort(sortedTransferrers, function(v1, v2) 
            return v1.name:upper() < v2.name:upper()
        end)
    elseif sortingAttr == "rate" then
        table.sort(sortedTransferrers, function(v1, v2) 
            local t1 = math.max(v1.data.transferIn or 0, v1.data.transferOut or 0)
            local t2 = math.max(v2.data.transferIn or 0, v2.data.transferOut or 0)
            return t1 < t2
        end)
    end
    

    if sortingDir == "desc" then
        local reversed = {}
        for i = #sortedTransferrers, 1, -1 do
            table.insert(reversed, sortedTransferrers[i])
        end
        sortedTransferrers = reversed
    end
end



----------------
-- ANIMATIONS --
----------------

-- animation for button click
animateButtonClick = function(btn)
    btn:setBackground(btnClickedColor)
    sleep(btnHighlighDuration)
    btn:setBackground(btnDefaultColor)
end

-- animation for button toggle
animateButtonToggle = function(btn, state)
    if state then
        btn:setBackground(btnClickedColor)
    else
        btn:setBackground(btnDefaultColor)
    end
end

-- animation for button group toggle
animateButtonToggleGroup = function(btnGroup, btn)
    for k,v in pairs(btnGroup) do
        if v ~= btn then
            animateButtonToggle(v, false)
        end
    end
    animateButtonToggle(btn, true)
end

-- animation with text update for filter button
toggleFilterShowSpecificTypeText = function(btn)
    local type = btn:getText()
    if type == "Filter All" then
        btn:setText("Filter Input")
        btn:setSize(14,1)
        toggleFilterShowSpecificType("Input")
    elseif type == "Filter Input" then
        btn:setText("Filter Output")
        btn:setSize(15,1)
        toggleFilterShowSpecificType("Output")
    elseif type == "Filter Output" then
        btn:setText("Filter All")
        btn:setSize(14,1)
        toggleFilterShowSpecificType("All")
    end
end

-- animation with text update for sorting attribute button
toggleSortAttrText = function(btn)
    if btn:getText() == "Sort by Name" then
        btn:setText("Sort by Rate")
        sortingAttr = "rate"
    else
        btn:setText("Sort by Name")
        sortingAttr = "name"
    end
end

-- animation with text update for sorting direction button
toggleSortDirText = function(btn)
    if btn:getText() == "Sort Ascending" then
        btn:setText("Sort Descending")
		btn:setSize(17,1)
        sortingDir = "desc"
    else
        btn:setText("Sort Ascending")
		btn:setSize(16,1)
        sortingDir = "asc"
    end
end



----------------------------------------
-- ACTUAL MONITOR PROGRAM STARTS HERE --
----------------------------------------
print("THIS IS THE MONITOR PROGRAM!")

-- Run the pinger and the listener and monitor updaters in parallel
parallel.waitForAll(setupMonitor, listen, updateMonitorValues, updateRuntimeFooter)

--------------------------------------
-- ACTUAL MONITOR PROGRAM ENDS HERE --
--------------------------------------
