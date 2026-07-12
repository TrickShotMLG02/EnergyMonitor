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
local historyMinutes = math.max(1, math.min(120, tonumber(_G.historyMinutes) or 5))
local historySampleSeconds = math.max(1, historyMinutes * 60)
local historyScalePadding = 0.1
local historyMode = false
local historyData = {}
local historyHasServerData = false

local displayFilter = {
    showDisconnected = true,
    showInput = true,
    showOutput = true,
}

local sortingAttr = "name"
local sortingDir = "asc"

-- debugging
local debugPrint = (_G.debugEnabled == 1 or _G.debugEnabled == true)
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
local historyView = {}
local historyHeader = {}
local historyExitBtn = {}
local historyTitleLbl = {}
local historyDebugLbl = {}
local historyInOutLbl = {}
local historyRateLbl = {}
local historyEtaLbl = {}
local historyPlot = {}
local historyAxisPanel = {}
local historyAxisMaxLbl = {}
local historyAxisMidLbl = {}
local historyAxisMinLbl = {}
local historyTimeLbl = {}

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
local main = flex:addFlexbox():setWrap("wrap"):setBackground(bgColor):setSize("parent.w", "parent.h-" .. (headerHeight + filterHeaderHeight + footerHeight + versionFooterHeight)):setSpacing(cellSpacing):setJustifyContent("center")--:setOffset(-1, 0)

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
local updateHistoryOverlay
local computeHistoryScale
local getEtaText
local setMonitorMode
local pruneHistoryData
local sampleHistoryPoint
local drawHistoryPlot
local safeHistoryDraw
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
            historyHasServerData = true
            sampleHistoryPoint()
			
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

    local currChannel = _G.getVersionChannel(_G.version)
    if currChannel == nil then
        monitorUpdateAvailable = false
        updateVersionFooter()
        return
    end

    local remoteVer = _G.fetchLatestRepositoryTag(currChannel)
    if remoteVer == nil then
        monitorUpdateAvailable = false
        updateVersionFooter()
        return
    end

    local cmp = _G.compareRepositoryTags(remoteVer, _G.version)
    monitorUpdateAvailable = cmp ~= nil and cmp > 0
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

getEtaText = function()
    if effectiveRate < 0 then
        local eta = storedEnergy / effectiveRate
        return _G.convertTicksToTime(-eta)
    elseif effectiveRate > 0 then
        local eta = (maxEnergy - storedEnergy) / effectiveRate
        return _G.convertTicksToTime(eta)
    end

    return "inf"
end

pruneHistoryData = function()
    local cutoff = os.clock() - historySampleSeconds
    local pruned = {}

    for _, point in ipairs(historyData) do
        if point.time >= cutoff then
            table.insert(pruned, point)
        end
    end

    historyData = pruned
end

computeHistoryScale = function(points)
    local minValue = nil
    local maxValue = nil

    for _, point in ipairs(points or {}) do
        local value = math.max(0, tonumber(point.value) or 0)
        if minValue == nil or value < minValue then
            minValue = value
        end
        if maxValue == nil or value > maxValue then
            maxValue = value
        end
    end

    if minValue == nil or maxValue == nil then
        return 0, 1
    end

    if minValue ~= minValue or maxValue ~= maxValue then
        return 0, 1
    end

    local range = maxValue - minValue
    local padding = math.max(range * historyScalePadding, math.max(1, math.abs(maxValue) * 0.05))
    minValue = math.max(0, minValue - padding)
    maxValue = maxValue + padding

    if minValue ~= minValue or maxValue ~= maxValue then
        return 0, 1
    end

    if maxValue <= minValue then
        maxValue = minValue + 1
    end

    return minValue, maxValue
end

sampleHistoryPoint = function()
    if not historyHasServerData then
        return
    end

    local now = os.clock()
    if #historyData > 0 and now - historyData[#historyData].time < 1 then
        return
    end

    table.insert(historyData, {
        time = now,
        value = math.max(0, tonumber(storedEnergy) or 0)
    })
    pruneHistoryData()
end

local function drawLineCell(target, x, y, color)
    target:addBackgroundBox(x, y, 1, 1, color)
    target:addForegroundBox(x, y, 1, 1, color)
    target:addTextBox(x, y, 1, 1, " ")
end

local function drawPlotLine(target, x1, y1, x2, y2, color)
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy

    while true do
        drawLineCell(target, x1, y1, color)
        if x1 == x2 and y1 == y2 then
            break
        end

        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x1 = x1 + sx
        end
        if e2 < dx then
            err = err + dx
            y1 = y1 + sy
        end
    end
end

drawHistoryPlot = function()
    if historyPlot == nil then
        return
    end

    local width, height = historyPlot:getSize()
    if width == nil or height == nil or width < 1 or height < 1 then
        return
    end

    local now = os.clock()
    local cutoff = now - historySampleSeconds
    local points = {}

    for _, point in ipairs(historyData) do
        if point.time >= cutoff then
            table.insert(points, point)
        end
    end

    local plotBg = colors.black
    local frameColor = colors.gray
    local fillColor = colors.green
    local lineColor = colors.lime
    local dotColor = colors.lime
    for y = 1, height do
        historyPlot:addBackgroundBox(1, y, width, 1, plotBg)
        historyPlot:addForegroundBox(1, y, width, 1, plotBg)
        historyPlot:addTextBox(1, y, width, 1, string.rep(" ", width))
    end

    for x = 1, width do
        historyPlot:addBackgroundBox(x, 1, 1, 1, frameColor)
        historyPlot:addForegroundBox(x, 1, 1, 1, frameColor)
        historyPlot:addTextBox(x, 1, 1, 1, " ")
        historyPlot:addBackgroundBox(x, height, 1, 1, frameColor)
        historyPlot:addForegroundBox(x, height, 1, 1, frameColor)
        historyPlot:addTextBox(x, height, 1, 1, " ")
    end

    for y = 1, height do
        historyPlot:addBackgroundBox(1, y, 1, 1, frameColor)
        historyPlot:addForegroundBox(1, y, 1, 1, frameColor)
        historyPlot:addTextBox(1, y, 1, 1, " ")
        historyPlot:addBackgroundBox(width, y, 1, 1, frameColor)
        historyPlot:addForegroundBox(width, y, 1, 1, frameColor)
        historyPlot:addTextBox(width, y, 1, 1, " ")
    end

    if #points == 0 then
        return
    end

    local scaleMin, scaleMax = computeHistoryScale(points)
    local scaleRange = math.max(1, scaleMax - scaleMin)
    local plotLeft = 2
    local plotTop = 2
    local plotRight = math.max(2, width - 1)
    local plotBottom = math.max(2, height - 1)
    local plotWidth = math.max(1, plotRight - plotLeft + 1)
    local plotHeight = math.max(1, plotBottom - plotTop + 1)
    local plotted = {}

    for _, point in ipairs(points) do
        local ratio = 0
        if historySampleSeconds > 0 then
            ratio = (point.time - cutoff) / historySampleSeconds
        end
        local x = plotLeft + math.floor(ratio * (plotWidth - 1))
        if x < plotLeft then
            x = plotLeft
        elseif x > plotRight then
            x = plotRight
        end

        local yRatio = (math.max(0, point.value) - scaleMin) / scaleRange
        if yRatio < 0 then
            yRatio = 0
        elseif yRatio > 1 then
            yRatio = 1
        end

        local y = plotBottom - math.floor(yRatio * (plotHeight - 1))
        if y < plotTop then
            y = plotTop
        elseif y > plotBottom then
            y = plotBottom
        end

        plotted[x] = plotted[x] or {}
        plotted[x].y = y
        plotted[x].value = point.value
    end

    local prevX = nil
    local prevY = nil
    for x = 1, width do
        local point = plotted[x]
        if point ~= nil then
            local fillHeight = plotBottom - point.y + 1
            if fillHeight > 0 then
                historyPlot:addBackgroundBox(x, point.y, 1, fillHeight, fillColor)
                historyPlot:addForegroundBox(x, point.y, 1, fillHeight, fillColor)
                historyPlot:addTextBox(x, point.y, 1, fillHeight, " ")
            end

            if prevX ~= nil and prevY ~= nil then
                drawPlotLine(historyPlot, prevX, prevY, x, point.y, lineColor)
            else
                drawLineCell(historyPlot, x, point.y, lineColor)
            end

            drawLineCell(historyPlot, x, point.y, dotColor)
            prevX = x
            prevY = point.y
        end
    end
end

safeHistoryDraw = function()
    local ok, err = pcall(drawHistoryPlot)
    if not ok and debugPrint then
        print("History draw error: " .. tostring(err))
    end
end

setMonitorMode = function(mode)
    historyMode = (mode == "history")

    if historyMode then
        sampleHistoryPoint()
    end

    if historyView ~= nil and historyView.show ~= nil and historyView.hide ~= nil then
        if historyMode then
            historyView:show()
        else
            historyView:hide()
        end
    end

    if historyMode and historyPlot ~= nil and historyPlot.updateDraw ~= nil then
        historyPlot:updateDraw()
    end

    if noticeFrame ~= nil and noticeFrame.hide ~= nil then
        if historyMode then
            noticeFrame:show()
        elseif _G.receiveMessage ~= nil then
            -- default mode restores server notice on demand
        end
    end
end

updateHistoryOverlay = function()
    if historyTitleLbl ~= nil and historyTitleLbl.setText ~= nil then
        historyTitleLbl:setText("Stored Energy History (last " .. historyMinutes .. "m)")
    end

    if historyExitBtn ~= nil and historyExitBtn.setText ~= nil then
        historyExitBtn:setText("Back")
    end

    local inOutText = "In: " .. _G.numberToEnergyUnit(inputRate) .. "/t  Out: " .. _G.numberToEnergyUnit(outputRate) .. "/t"
    local rateColor = colors.yellow
    local rateText = "Eff: +0.0 FE/t"
    if effectiveRate < 0 then
        rateColor = colors.red
        rateText = "Eff: -" .. _G.numberToEnergyUnit(math.abs(effectiveRate)) .. "/t"
    elseif effectiveRate > 0 then
        rateColor = colors.lime
        rateText = "Eff: +" .. _G.numberToEnergyUnit(effectiveRate) .. "/t"
    end
    local etaText = "ETA: " .. getEtaText()

    local headerWidth = nil
    if historyHeader ~= nil and historyHeader.getSize ~= nil then
        local headerW = historyHeader:getSize()
        headerWidth = tonumber(headerW)
    end
    if headerWidth == nil or headerWidth < 1 then
        headerWidth = 1
    end

    local inOutWidth = math.max(1, string.len(inOutText))
    local rateWidth = math.max(1, string.len(rateText))
    local etaWidth = math.max(1, string.len(etaText))
    local gap = 2

    if historyInOutLbl ~= nil and historyInOutLbl.setText ~= nil then
        historyInOutLbl:setText(inOutText)
        historyInOutLbl:setSize(math.max(1, math.min(inOutWidth, headerWidth - 1)), 1)
        historyInOutLbl:setPosition(2, 2)
        historyInOutLbl:setTextAlign("left")
    end

    if historyRateLbl ~= nil and historyRateLbl.setText ~= nil then
        local rateLeft = 2 + inOutWidth + gap
        local rateMaxRight = math.floor(headerWidth * 0.7)
        local rateLabelWidth = math.max(1, math.min(rateWidth, math.max(1, rateMaxRight - rateLeft)))
        historyRateLbl:setText(rateText)
        historyRateLbl:setSize(rateLabelWidth, 1)
        historyRateLbl:setPosition(rateLeft, 2)
        historyRateLbl:setTextAlign("left")
        historyRateLbl:setForeground(rateColor)
    end

    if historyEtaLbl ~= nil and historyEtaLbl.setText ~= nil then
        local etaRight = math.max(2, headerWidth - 1)
        local etaLeft = math.max(2, etaRight - etaWidth + 1)
        local etaLabelWidth = math.max(1, etaRight - etaLeft + 1)
        historyEtaLbl:setText(etaText)
        historyEtaLbl:setSize(etaLabelWidth, 1)
        historyEtaLbl:setPosition(etaLeft, 2)
        historyEtaLbl:setTextAlign("left")
        historyEtaLbl:setForeground(colors.white)
    end

    local scaleMin, scaleMax = computeHistoryScale(historyData)
    local midValue = scaleMin + ((scaleMax - scaleMin) / 2)
    local minText = _G.numberToEnergyUnit(scaleMin)
    local midText = _G.numberToEnergyUnit(midValue)
    local maxText = _G.numberToEnergyUnit(scaleMax)
    if historyAxisMaxLbl ~= nil and historyAxisMaxLbl.setText ~= nil then
        historyAxisMaxLbl:setText("Max " .. maxText)
    end
    if historyAxisMidLbl ~= nil and historyAxisMidLbl.setText ~= nil then
        historyAxisMidLbl:setText("Mid " .. midText)
    end
    if historyAxisMinLbl ~= nil and historyAxisMinLbl.setText ~= nil then
        historyAxisMinLbl:setText("Min " .. minText)
    end
    if historyTimeLbl ~= nil and historyTimeLbl.setText ~= nil then
        historyTimeLbl:setText("Time " .. historyMinutes .. "m")
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
    local historyBtn = header:addButton()
        :setText("Graph")
        :setSize(7, 1)
        :setBackground(btnDefaultColor)
        :setPosition("(1/12 * parent.w) + (parent.w / 3) + 1", 3)
    historyBtn:onClick(basalt.schedule(function(self)
        animateButtonClick(self)
        pcall(setMonitorMode, "history")
        updateHistoryOverlay()
    end))
    rateLblIn = header:addLabel():setText("Transfer: IN"):setFontSize(1):setSize("parent.w / 3", 1):setPosition("2 * parent.w / 3", 1):setTextAlign("left")
    rateLblOut = header:addLabel():setText("Transfer: OUT" ):setFontSize(1):setSize("parent.w / 3", 1):setPosition(" 2 * parent.w / 3", 2):setTextAlign("left")
    effectiveRateLbl = header:addLabel():setText("Eff. Rate: "):setFontSize(1):setSize("parent.w / 3", 1):setPosition("2 * parent.w / 3", 3):setTextAlign("left")
    etaLbl = header:addLabel():setText("ETA: "):setFontSize(1):setSize("parent.w / 3", 1):setPosition("2 * parent.w / 3", 4):setTextAlign("left")

    historyView = monitorRoot:addFrame()
        :setBackground(colors.black)
        :setSize("parent.w", "parent.h-" .. versionFooterHeight)
        :setPosition(1, 1)
        :setZIndex(60)
        :hide()
    historyHeader = historyView:addFrame()
        :setBackground(colors.black)
        :setSize("parent.w", 3)
        :setPosition(1, 1)
    historyTitleLbl = historyHeader:addLabel()
        :setText("Stored Energy History (last " .. historyMinutes .. "m)")
        :setFontSize(1)
        :setSize("parent.w-14", 1)
        :setPosition(1, 1)
        :setTextAlign("left")
        :setForeground(colors.lime)
    historyDebugLbl = historyHeader:addLabel()
        :setText("Debug")
        :setSize("parent.w-14", 1)
        :setPosition(2, 3)
        :setTextAlign("left")
        :setForeground(colors.gray)
    if not debugPrint and historyDebugLbl.hide ~= nil then
        historyDebugLbl:hide()
    end
    historyInOutLbl = historyHeader:addLabel()
        :setText("")
        :setSize("parent.w / 2 - 2", 1)
        :setPosition(2, 2)
        :setTextAlign("left")
        :setForeground(colors.white)
    historyRateLbl = historyHeader:addLabel()
        :setText("")
        :setSize("parent.w / 4", 1)
        :setPosition("parent.w / 2 - (parent.w / 8) + 1", 2)
        :setTextAlign("center")
        :setForeground(colors.yellow)
    historyEtaLbl = historyHeader:addLabel()
        :setText("")
        :setSize("parent.w / 4", 1)
        :setPosition("parent.w - (parent.w / 4) - 1", 2)
        :setTextAlign("right")
        :setForeground(colors.white)
    historyExitBtn = historyView:addButton()
        :setText("Back")
        :setSize(8, 1)
        :setBackground(btnDefaultColor)
        :setPosition("parent.w-9", "parent.h-1")
    historyExitBtn:onClick(basalt.schedule(function(self)
        animateButtonClick(self)
        pcall(setMonitorMode, "default")
    end))
    historyPlot = historyView:addFrame()
        :setBackground(colors.black)
        :setSize("parent.w-18", "parent.h-7")
        :setPosition(2, 4)
    historyAxisPanel = historyView:addFrame()
        :setBackground(colors.black)
        :setSize(14, "parent.h-7")
        :setPosition("parent.w-14", 4)
    historyAxisMaxLbl = historyAxisPanel:addLabel()
        :setText("Max")
        :setSize("parent.w", 1)
        :setPosition(1, 2)
        :setTextAlign("right")
        :setForeground(colors.white)
    historyAxisMidLbl = historyAxisPanel:addLabel()
        :setText("Mid")
        :setSize("parent.w", 1)
        :setPosition(1, "parent.h/2")
        :setTextAlign("right")
        :setForeground(colors.white)
    historyAxisMinLbl = historyAxisPanel:addLabel()
        :setText("Min")
        :setSize("parent.w", 1)
        :setPosition(1, "parent.h-1")
        :setTextAlign("right")
        :setForeground(colors.white)
    historyTimeLbl = historyView:addLabel()
        :setText("Time")
        :setSize("parent.w-18", 1)
        :setPosition(2, "parent.h-2")
        :setTextAlign("center")
        :setForeground(colors.gray)
    historyPlot:addPostDraw("history-plot", function()
        safeHistoryDraw()
    end, 1)
    updateHistoryOverlay()
    setMonitorMode((_G.monitorOpenGraphOnStart == true) and "history" or "default")

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
        if noticeFrame.setZIndex ~= nil then
            noticeFrame:setZIndex(70)
        end
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



    etaLbl:setText("ETA: " .. getEtaText())
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

updateHistoryGraph = function()
    while true do
        sampleHistoryPoint()
        updateHistoryOverlay()
        if historyMode and historyPlot ~= nil and historyPlot.updateDraw ~= nil then
            historyPlot:updateDraw()
        end
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
parallel.waitForAll(setupMonitor, listen, updateMonitorValues, updateRuntimeFooter, updateHistoryGraph)

--------------------------------------
-- ACTUAL MONITOR PROGRAM ENDS HERE --
--------------------------------------
