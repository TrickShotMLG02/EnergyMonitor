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

-- create main window
local main = basalt.addMonitor()
main:setMonitor(_G.controlMonitor)

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

listen = function()
    -- Receive data from server
    while true do
        local clock = os.clock()
		
		timeLbl:setText("Time running: " .. os.clock() .. "s")
		
        local msg = _G.receiveMessage()

        if debugPrint then
            term.redirect(term.native())
            term.clear()
            term.setCursorPos(1,1)
            print(clock)
            print("Receiving monitor data from server on channel: ".._G.modemChannel)
        end

        if msg.type == _G.MessageType.Monitor and msg.sender == _G.Sender.Server then

            -- extract data from message
            local data = msg.messageData.data

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
			
            sortTransferrers()
			reloadPage()
        end
    end
end



--------------
-- Setup UI --
--------------


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
	versionFooter:addLabel():setText("version: " .. _G.version):setFontSize(1):setSize("parent.w/2", 1):setPosition("parent.w/2", versionFooterHeight):setTextAlign("right"):setForeground(colors.gray)
	timeLbl = versionFooter:addLabel():setText("Time running: "):setFontSize(1):setSize("parent.w/2", 1):setPosition(1, versionFooterHeight):setTextAlign("left"):setForeground(colors.gray)

    -- auto update the monitor
    basalt.autoUpdate()
end

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

updateEnergyDisplay = function()
    energyLbl:setText("Energy: " .. _G.numberToEnergyUnit(storedEnergy) .. "/" .. _G.numberToEnergyUnit(maxEnergy) .. " (" .. _G.formatDecimals(energyPercentage, 1) .. "%)")
    energyBar:setProgress(tonumber(_G.defaultInf(_G.defaultNil(_G.formatDecimals(energyPercentage, 0), 0), 0)))
end

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
        --displayCells[k].dpType:setText(_G.parseTransferType(d.transferType))
        --displayCells[k].dpState:setText(d.status)
    end
end

countDisplayableCells = function ()
    local cnt = 0
    for k,v in pairs(transferrers) do
        if checkFilter(v) then
            cnt = cnt + 1
        end
    end
    return cnt
end

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



-----------------
-- CHANGE PAGE --
-----------------

nextPage = function()
    if currentPageId < totalPageCount then
        currentPageId = currentPageId + 1
        reloadPage()
    end
end

prevPage = function()
    if currentPageId > 1 then
        currentPageId = currentPageId - 1
        reloadPage()
    end
end

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

toggleFilterShowDisconnected = function(btn)
    displayFilter.showDisconnected = not displayFilter.showDisconnected
    if not displayFilter.showDisconnected then
        btn:setText("Show Disconnected")
    else
        btn:setText("Hide Disconnected")
    end

    reloadPage()
end

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

animateButtonClick = function(btn)
    btn:setBackground(btnClickedColor)
    sleep(btnHighlighDuration)
    btn:setBackground(btnDefaultColor)
end

animateButtonToggle = function(btn, state)
    if state then
        btn:setBackground(btnClickedColor)
    else
        btn:setBackground(btnDefaultColor)
    end
end

animateButtonToggleGroup = function(btnGroup, btn)
    for k,v in pairs(btnGroup) do
        if v ~= btn then
            animateButtonToggle(v, false)
        end
    end
    animateButtonToggle(btn, true)
end

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

toggleSortAttrText = function(btn)
    if btn:getText() == "Sort by Name" then
        btn:setText("Sort by Rate")
        sortingAttr = "rate"
    else
        btn:setText("Sort by Name")
        sortingAttr = "name"
    end
end

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



---------------------------------------
-- ACTUAL SERVER PROGRAM STARTS HERE --
---------------------------------------
print("THIS IS THE MONITOR PROGRAM!")

-- Run the pinger and the listener and monitor updaters in parallel
parallel.waitForAll(setupMonitor, listen, updateMonitorValues)

-------------------------------------
-- ACTUAL SERVER PROGRAM ENDS HERE --
-------------------------------------
