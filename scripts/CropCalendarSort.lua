-- FS25_CropCalendarSort
-- Native crop-calendar quality-of-life sorting.
--
-- v0.3.0.0
--   * Native calendar bottom-bar SORT action
--   * Native OptionDialog selector
--   * Persistent player preference under modSettings
--   * Reference sorts: Native / A-Z / Plantable A-Z / Planting Start / Harvest Start
--   * Gameplay sorts: Plant Now / Harvest Now / Next Planting / Next Harvest
--
-- This mod changes presentation order only. It never edits fruit types,
-- seasonal growth data, fields, contracts or savegame crop state.

CropCalendarSort = CropCalendarSort or {}

local CCS = CropCalendarSort
CCS.MOD_NAME = g_currentModName or "FS25_CropCalendarSort"
CCS.VERSION = "0.3.0.0"
CCS.DEBUG = true
CCS._installed = false
CCS._lastFrame = nil

CCS.MODE_NATIVE = "native"
CCS.MODE_AZ = "az"
CCS.MODE_PLANTABLE_AZ = "plantableAz"
CCS.MODE_PLANTING_START = "plantingStart"
CCS.MODE_HARVEST_START = "harvestStart"
CCS.MODE_PLANT_NOW = "plantNow"
CCS.MODE_HARVEST_NOW = "harvestNow"
CCS.MODE_NEXT_PLANTING = "nextPlanting"
CCS.MODE_NEXT_HARVEST = "nextHarvest"

CCS.DEFAULT_MODE = CCS.MODE_PLANTABLE_AZ
CCS.currentMode = CCS.DEFAULT_MODE

CCS.MODES = {
    { id = CCS.MODE_NATIVE,         label = "Native Order",    shortLabel = "NATIVE" },
    { id = CCS.MODE_AZ,             label = "Alphabetical A-Z", shortLabel = "A-Z" },
    { id = CCS.MODE_PLANTABLE_AZ,   label = "Plantable A-Z",  shortLabel = "PLANTABLE A-Z" },
    { id = CCS.MODE_PLANTING_START, label = "Planting Start", shortLabel = "PLANTING START" },
    { id = CCS.MODE_HARVEST_START,  label = "Harvest Start",  shortLabel = "HARVEST START" },
    { id = CCS.MODE_PLANT_NOW,      label = "Plant Now",      shortLabel = "PLANT NOW" },
    { id = CCS.MODE_HARVEST_NOW,    label = "Harvest Now",    shortLabel = "HARVEST NOW" },
    { id = CCS.MODE_NEXT_PLANTING,  label = "Next Planting",  shortLabel = "NEXT PLANTING" },
    { id = CCS.MODE_NEXT_HARVEST,   label = "Next Harvest",   shortLabel = "NEXT HARVEST" },
}

CCS.SETTINGS_DIR = "FS25_CropCalendarSort/"
CCS.SETTINGS_FILE = "settings.xml"
CCS.SETTINGS_ROOT = "cropCalendarSort"

local function log(message)
    print(("[%s] %s"):format(CCS.MOD_NAME, tostring(message)))
end

local function debug(message)
    if CCS.DEBUG == true then
        log(message)
    end
end

local function copyArray(values)
    local result = {}
    for index, value in ipairs(values or {}) do
        result[index] = value
    end
    return result
end

local function normalizedText(value)
    local text = tostring(value or "")

    if utf8ToLower ~= nil then
        local ok, lowered = pcall(utf8ToLower, text)
        if ok and lowered ~= nil then
            return tostring(lowered)
        end
    end

    return string.lower(text)
end

function CCS:getModeDefinition(modeId)
    for index, mode in ipairs(self.MODES) do
        if mode.id == modeId then
            return mode, index
        end
    end
    return self.MODES[1], 1
end

function CCS:isValidMode(modeId)
    for _, mode in ipairs(self.MODES) do
        if mode.id == modeId then
            return true
        end
    end
    return false
end

function CCS:getModeLabel(modeId, short)
    local mode = self:getModeDefinition(modeId)
    return short == true and mode.shortLabel or mode.label
end

function CCS:getDisplayName(fruitType)
    if fruitType == nil then
        return ""
    end

    if g_fruitTypeManager ~= nil
        and g_fruitTypeManager.getFillTypeByFruitTypeIndex ~= nil
        and fruitType.index ~= nil then

        local ok, fillType = pcall(
            g_fruitTypeManager.getFillTypeByFruitTypeIndex,
            g_fruitTypeManager,
            fruitType.index
        )

        if ok and fillType ~= nil and fillType.title ~= nil and tostring(fillType.title) ~= "" then
            return tostring(fillType.title)
        end
    end

    return tostring(fruitType.name or "")
end

function CCS:isPlantable(fruitType)
    return fruitType ~= nil and fruitType.allowsSeeding == true
end

function CCS:getSeasonalGrowthData(fruitType)
    if fruitType == nil then
        return nil
    end

    if fruitType.getSeasonalGrowthData ~= nil then
        local ok, data = pcall(fruitType.getSeasonalGrowthData, fruitType)
        if ok and type(data) == "table" and type(data.periods) == "table" then
            return data
        end
    end

    if type(fruitType.growthDataSeasonal) == "table"
        and type(fruitType.growthDataSeasonal.periods) == "table" then
        return fruitType.growthDataSeasonal
    end

    if type(fruitType.data) == "table"
        and type(fruitType.data.growthDataSeasonal) == "table"
        and type(fruitType.data.growthDataSeasonal.periods) == "table" then
        return fruitType.data.growthDataSeasonal
    end

    return nil
end

function CCS:getFirstSeasonalPeriod(fruitType, propertyName)
    local seasonalData = self:getSeasonalGrowthData(fruitType)
    if seasonalData == nil then
        return 999
    end

    for period = 1, 12 do
        local periodInfo = seasonalData.periods[period]
        if type(periodInfo) == "table" and periodInfo[propertyName] == true then
            return period
        end
    end

    return 999
end

function CCS:getCurrentSeasonalPeriod()
    local env = g_currentMission ~= nil and g_currentMission.environment or nil
    local period = nil

    if env ~= nil then
        period = env.currentPeriod or env.period or env.currentSeasonPeriod

        if period == nil and env.getCurrentPeriod ~= nil then
            local ok, result = pcall(function()
                return env:getCurrentPeriod()
            end)
            if ok then
                period = result
            end
        end

        if period == nil and env.getPeriod ~= nil then
            local ok, result = pcall(function()
                return env:getPeriod()
            end)
            if ok then
                period = result
            end
        end

        if period == nil then
            period = env.currentMonth or env.month
        end
    end

    period = tonumber(period)
    if period == nil then
        return nil
    end

    period = math.floor(period)
    if period < 1 or period > 12 then
        return nil
    end

    return period
end

function CCS:isSeasonalPropertyActive(fruitType, propertyName, period)
    if period == nil then
        return false
    end

    local seasonalData = self:getSeasonalGrowthData(fruitType)
    if seasonalData == nil then
        return false
    end

    local periodInfo = seasonalData.periods[period]
    return type(periodInfo) == "table" and periodInfo[propertyName] == true
end

function CCS:getNextSeasonalDistance(fruitType, propertyName, currentPeriod)
    if currentPeriod == nil then
        return 999
    end

    local seasonalData = self:getSeasonalGrowthData(fruitType)
    if seasonalData == nil then
        return 999
    end

    for offset = 0, 11 do
        local period = ((currentPeriod - 1 + offset) % 12) + 1
        local periodInfo = seasonalData.periods[period]

        if type(periodInfo) == "table" and periodInfo[propertyName] == true then
            return offset
        end
    end

    return 999
end

local function compareDisplayName(a, b)
    local aDisplay = normalizedText(CCS:getDisplayName(a))
    local bDisplay = normalizedText(CCS:getDisplayName(b))

    if aDisplay ~= bDisplay then
        return aDisplay < bDisplay
    end

    return normalizedText(a ~= nil and a.name or "") < normalizedText(b ~= nil and b.name or "")
end

function CCS:sortFruitTypes(fruitTypes, modeId)
    local sorted = copyArray(fruitTypes)
    local mode = self:isValidMode(modeId) and modeId or self.DEFAULT_MODE

    if mode == self.MODE_NATIVE then
        return sorted
    end

    if mode == self.MODE_AZ then
        table.sort(sorted, compareDisplayName)
        return sorted
    end

    if mode == self.MODE_PLANTABLE_AZ then
        table.sort(sorted, function(a, b)
            local aPlantable = CCS:isPlantable(a)
            local bPlantable = CCS:isPlantable(b)

            if aPlantable ~= bPlantable then
                return aPlantable
            end

            return compareDisplayName(a, b)
        end)
        return sorted
    end

    if mode == self.MODE_PLANT_NOW or mode == self.MODE_HARVEST_NOW then
        local currentPeriod = self:getCurrentSeasonalPeriod()
        if currentPeriod == nil then
            debug("current seasonal period unavailable; NOW sort falling back to A-Z")
            table.sort(sorted, compareDisplayName)
            return sorted
        end

        local propertyName = mode == self.MODE_HARVEST_NOW and "isHarvestable" or "plantingAllowed"

        table.sort(sorted, function(a, b)
            local aActive = CCS:isSeasonalPropertyActive(a, propertyName, currentPeriod)
            local bActive = CCS:isSeasonalPropertyActive(b, propertyName, currentPeriod)

            if aActive ~= bActive then
                return aActive
            end

            return compareDisplayName(a, b)
        end)

        return sorted
    end

    if mode == self.MODE_NEXT_PLANTING or mode == self.MODE_NEXT_HARVEST then
        local currentPeriod = self:getCurrentSeasonalPeriod()
        if currentPeriod == nil then
            debug("current seasonal period unavailable; NEXT sort falling back to A-Z")
            table.sort(sorted, compareDisplayName)
            return sorted
        end

        local propertyName = mode == self.MODE_NEXT_HARVEST and "isHarvestable" or "plantingAllowed"

        table.sort(sorted, function(a, b)
            local aDistance = CCS:getNextSeasonalDistance(a, propertyName, currentPeriod)
            local bDistance = CCS:getNextSeasonalDistance(b, propertyName, currentPeriod)

            if aDistance ~= bDistance then
                return aDistance < bDistance
            end

            return compareDisplayName(a, b)
        end)

        return sorted
    end

    local propertyName = mode == self.MODE_HARVEST_START and "isHarvestable" or "plantingAllowed"

    table.sort(sorted, function(a, b)
        local aPeriod = CCS:getFirstSeasonalPeriod(a, propertyName)
        local bPeriod = CCS:getFirstSeasonalPeriod(b, propertyName)

        if aPeriod ~= bPeriod then
            return aPeriod < bPeriod
        end

        return compareDisplayName(a, b)
    end)

    return sorted
end

local function orderChanged(before, after)
    if type(before) ~= "table" or type(after) ~= "table" then
        return true
    end

    if #before ~= #after then
        return true
    end

    for index = 1, #after do
        if before[index] ~= after[index] then
            return true
        end
    end

    return false
end

function CCS:captureNativeOrder(frame)
    if frame == nil or type(frame.fruitTypes) ~= "table" then
        return false
    end

    frame.ccsNativeFruitTypes = copyArray(frame.fruitTypes)
    debug(("captured native calendar order rows=%d"):format(#frame.ccsNativeFruitTypes))
    return true
end

function CCS:logOrder(fruitTypes, source)
    if self.DEBUG ~= true then
        return
    end

    local currentPeriod = self:getCurrentSeasonalPeriod()

    debug(("calendar order mode=%s source=%s rows=%d currentPeriod=%s"):format(
        self:getModeLabel(self.currentMode, true),
        tostring(source or "unknown"),
        #(fruitTypes or {}),
        tostring(currentPeriod or "-")
    ))

    for index, fruitType in ipairs(fruitTypes or {}) do
        local planting = self:getFirstSeasonalPeriod(fruitType, "plantingAllowed")
        local harvest = self:getFirstSeasonalPeriod(fruitType, "isHarvestable")

        debug(("%02d | %-24s | %-24s | plantable=%-5s | plant=%s | harvest=%s"):format(
            index,
            tostring(fruitType.name or "?"),
            self:getDisplayName(fruitType),
            tostring(self:isPlantable(fruitType)),
            planting == 999 and "-" or tostring(planting),
            harvest == 999 and "-" or tostring(harvest)
        ))
    end
end

function CCS:reloadCalendar(frame)
    if frame ~= nil and frame.calendar ~= nil and frame.calendar.reloadData ~= nil then
        local ok, err = pcall(frame.calendar.reloadData, frame.calendar)
        if not ok then
            debug("calendar reloadData failed: " .. tostring(err))
            return false
        end
        return true
    end
    return false
end

function CCS:applySortToFrame(frame, source, captureNative)
    if frame == nil then
        debug(("sort skipped (%s): frame unavailable"):format(tostring(source)))
        return false
    end

    if type(frame.fruitTypes) ~= "table" then
        debug(("sort skipped (%s): frame.fruitTypes unavailable"):format(tostring(source)))
        return false
    end

    self._lastFrame = frame

    if captureNative == true or type(frame.ccsNativeFruitTypes) ~= "table" then
        self:captureNativeOrder(frame)
    end

    local sourceRows = type(frame.ccsNativeFruitTypes) == "table"
        and frame.ccsNativeFruitTypes
        or frame.fruitTypes

    local sorted = self:sortFruitTypes(sourceRows, self.currentMode)
    local changed = orderChanged(frame.fruitTypes, sorted)

    frame.fruitTypes = sorted

    if changed then
        self:reloadCalendar(frame)
    end

    self:logOrder(frame.fruitTypes, source)
    return changed
end

function CCS:getSettingsPath()
    if g_modSettingsDirectory == nil or g_modSettingsDirectory == "" then
        return nil
    end

    local directory = g_modSettingsDirectory .. self.SETTINGS_DIR
    if createFolder ~= nil then
        pcall(createFolder, directory)
    end

    return directory .. self.SETTINGS_FILE
end

function CCS:loadSettings()
    local path = self:getSettingsPath()
    if path == nil or XMLFile == nil or XMLFile.loadIfExists == nil then
        debug("settings load skipped: modSettings/XMLFile unavailable")
        return false
    end

    local xmlFile = XMLFile.loadIfExists("CropCalendarSortSettings", path, self.SETTINGS_ROOT)
    if xmlFile == nil then
        debug("settings file not found; using default mode " .. self:getModeLabel(self.DEFAULT_MODE, true))
        self.currentMode = self.DEFAULT_MODE
        return false
    end

    local mode = xmlFile:getString(self.SETTINGS_ROOT .. "#mode", self.DEFAULT_MODE)
    xmlFile:delete()

    if not self:isValidMode(mode) then
        debug("invalid saved sort mode '" .. tostring(mode) .. "'; using default")
        mode = self.DEFAULT_MODE
    end

    self.currentMode = mode
    log("loaded sort preference: " .. self:getModeLabel(self.currentMode, true))
    return true
end

function CCS:saveSettings()
    local path = self:getSettingsPath()
    if path == nil or XMLFile == nil or XMLFile.create == nil then
        debug("settings save skipped: modSettings/XMLFile unavailable")
        return false
    end

    local xmlFile = XMLFile.create("CropCalendarSortSettings", path, self.SETTINGS_ROOT)
    if xmlFile == nil then
        debug("settings save failed: XMLFile.create returned nil")
        return false
    end

    xmlFile:setString(self.SETTINGS_ROOT .. "#mode", self.currentMode)
    xmlFile:setString(self.SETTINGS_ROOT .. "#version", self.VERSION)
    xmlFile:save()
    xmlFile:delete()

    debug("saved sort preference: " .. self:getModeLabel(self.currentMode, true))
    return true
end

function CCS:setMode(modeId, frame)
    if not self:isValidMode(modeId) then
        return false
    end

    self.currentMode = modeId
    self:saveSettings()

    local targetFrame = frame or self._lastFrame
    if targetFrame ~= nil then
        self:applySortToFrame(targetFrame, "modeChange", false)
        self:addNativeCalendarSortButton(targetFrame)
    end

    log("sort mode changed to " .. self:getModeLabel(self.currentMode, true))
    return true
end

function CCS:cycleMode(frame)
    local _, currentIndex = self:getModeDefinition(self.currentMode)
    local nextIndex = (tonumber(currentIndex) or 1) + 1
    if nextIndex > #self.MODES then
        nextIndex = 1
    end

    local mode = self.MODES[nextIndex]
    if mode ~= nil then
        log("OptionDialog unavailable; cycling sort mode to " .. tostring(mode.shortLabel or mode.label))
        self:setMode(mode.id, frame)
        return true
    end

    return false
end

function CCS:showSortDialog(frame)
    local options = {}
    for index, mode in ipairs(self.MODES) do
        options[index] = mode.label
    end

    local _, currentIndex = self:getModeDefinition(self.currentMode)

    local callbackArgs = { frame }
    local callback = function(target, selectedOption, args)
        debug("sort dialog callback selectedOption=" .. tostring(selectedOption))

        if type(selectedOption) ~= "number" or selectedOption <= 0 then
            return
        end

        local selectedFrame = frame
        if type(args) == "table" and args[1] ~= nil then
            selectedFrame = args[1]
        end

        local mode = CCS.MODES[selectedOption]
        if mode ~= nil then
            CCS:setMode(mode.id, selectedFrame)
        end
    end

    -- Current FS25 working pattern: create the stock OptionDialog directly
    -- from the game's existing GUI instead of depending on wrapper helpers.
    if OptionDialog ~= nil and OptionDialog.createFromExistingGui ~= nil then
        debug("opening sort dialog through OptionDialog.createFromExistingGui")

        local ok, err = pcall(function()
            OptionDialog.createFromExistingGui({
                options = options,
                optionText = "Current: " .. self:getModeLabel(self.currentMode, false)
                    .. "\nChoose how crops are ordered in the calendar.",
                optionTitle = "Crop Calendar Sort",
                callbackFunc = callback,
            }, self.MOD_NAME .. "SortOptionDialog")

            local optionDialog = OptionDialog.INSTANCE
            if optionDialog == nil then
                error("OptionDialog.INSTANCE was nil after createFromExistingGui")
            end

            if optionDialog.optionElement ~= nil and optionDialog.optionElement.setState ~= nil then
                optionDialog.optionElement:setState(currentIndex or 1)
            end

            if optionDialog.setCallback ~= nil then
                optionDialog:setCallback(callback, self, callbackArgs)
            end
        end)

        if ok then
            return
        end

        log("ERROR: direct OptionDialog failed: " .. tostring(err))
    else
        log("ERROR: OptionDialog class/createFromExistingGui unavailable")
    end

    -- Never leave the visible SORT action as a no-op. If a future game build
    -- changes the dialog API, the action still cycles modes and remains useful.
    self:cycleMode(frame)
end

function CCS:addNativeCalendarSortButton(frame)
    if frame == nil or InputAction == nil then
        return false
    end

    local menuController = (g_gui ~= nil and g_gui.currentGui ~= nil and g_gui.currentGui.target) or nil
    local source = (type(frame.menuButtonInfo) == "table" and #frame.menuButtonInfo > 0 and frame.menuButtonInfo)
        or (menuController ~= nil and type(menuController.defaultMenuButtonInfo) == "table"
            and #menuController.defaultMenuButtonInfo > 0 and menuController.defaultMenuButtonInfo)
        or nil

    if type(source) ~= "table" then
        debug("native Calendar sort button skipped: menu button source unavailable")
        return false
    end

    local buttons = {}
    local usedActions = {}

    for _, entry in ipairs(source) do
        if entry.ccsCalendarSortButton ~= true then
            buttons[#buttons + 1] = entry
            if entry.inputAction ~= nil then
                usedActions[entry.inputAction] = true
            end
        end
    end

    if #buttons == 0 then
        return false
    end

    local action = nil
    local candidateNames = { "MENU_EXTRA_3", "MENU_EXTRA_2", "MENU_EXTRA_1" }
    for _, name in ipairs(candidateNames) do
        local candidate = InputAction[name]
        if candidate ~= nil and usedActions[candidate] ~= true then
            action = candidate
            break
        end
    end

    if action == nil then
        debug("native Calendar sort button skipped: no unused MENU_EXTRA action")
        return false
    end

    buttons[#buttons + 1] = {
        ccsCalendarSortButton = true,
        inputAction = action,
        text = "SORT: " .. self:getModeLabel(self.currentMode, true),
        callback = function()
            debug("sort menu action invoked")
            CCS:showSortDialog(frame)
        end,
    }

    if frame.setMenuButtonInfo ~= nil then
        local ok, err = pcall(frame.setMenuButtonInfo, frame, buttons)
        if not ok then
            debug("setMenuButtonInfo failed: " .. tostring(err))
            return false
        end
    else
        frame.menuButtonInfo = buttons
    end

    frame.hasCustomMenuButtons = true
    if frame.setMenuButtonInfoDirty ~= nil then
        pcall(frame.setMenuButtonInfoDirty, frame)
    end

    return true
end

function CCS:install()
    if self._installed == true then
        return true
    end

    if InGameMenuCalendarFrame == nil or Utils == nil or Utils.appendedFunction == nil then
        log("native calendar hook unavailable; mod not installed")
        return false
    end

    if InGameMenuCalendarFrame.rebuildTable ~= nil then
        InGameMenuCalendarFrame.rebuildTable = Utils.appendedFunction(
            InGameMenuCalendarFrame.rebuildTable,
            function(frame, ...)
                -- At this point GIANTS (or another compatible calendar provider)
                -- has just populated fruitTypes. Capture that as the true native
                -- baseline before applying the player's selected presentation sort.
                CCS:applySortToFrame(frame, "rebuildTable", true)
            end
        )
    end

    if InGameMenuCalendarFrame.onFrameOpen ~= nil then
        InGameMenuCalendarFrame.onFrameOpen = Utils.appendedFunction(
            InGameMenuCalendarFrame.onFrameOpen,
            function(frame, ...)
                CCS._lastFrame = frame

                -- Some calendar implementations rebuild in onFrameOpen, others
                -- arrive here with a ready list. Only capture here if the rebuild
                -- hook has not already established a baseline.
                CCS:applySortToFrame(frame, "onFrameOpen", type(frame.ccsNativeFruitTypes) ~= "table")
                CCS:addNativeCalendarSortButton(frame)
            end
        )
    end

    if Mission00 ~= nil and Mission00.loadItemsFinished ~= nil then
        Mission00.loadItemsFinished = Utils.appendedFunction(
            Mission00.loadItemsFinished,
            function(...)
                CCS:loadSettings()
            end
        )
    end

    self._installed = true
    log(("loaded v%s - selectable native crop calendar sorting enabled"):format(self.VERSION))
    return true
end

-- Small public surface so another mod (including CCO) can deliberately reuse
-- this standalone sort engine when it is present instead of competing with it.
CropCalendarSortAPI = CropCalendarSortAPI or {
    version = 1,
}

function CropCalendarSortAPI:getMode()
    return CCS.currentMode
end

function CropCalendarSortAPI:setMode(modeId, frame)
    return CCS:setMode(modeId, frame)
end

function CropCalendarSortAPI:sortFruitTypes(fruitTypes, modeId)
    return CCS:sortFruitTypes(fruitTypes, modeId or CCS.currentMode)
end

function CropCalendarSortAPI:getModes()
    local result = {}
    for index, mode in ipairs(CCS.MODES) do
        result[index] = {
            id = mode.id,
            label = mode.label,
            shortLabel = mode.shortLabel,
        }
    end
    return result
end

CCS:install()
