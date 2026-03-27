local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'

local UI = require 'UI'
local KeywordService = require 'KeywordService'
local okLogService, LogService = pcall(require, 'LogService')

local function trace(msg)
    if not okLogService or not LogService or type(LogService.append) ~= 'function' then
        return
    end
    local logPath = '~/Library/Logs/Adobe/Lightroom/GBKeywordEditor.log'
    if _G and type(_G.GBKeywordEditorLogPath) == 'string' and _G.GBKeywordEditorLogPath ~= '' then
        logPath = _G.GBKeywordEditorLogPath
    end
    LogService.append(logPath, msg)
end

local function getCatalogKeywordCountsByName(catalog, names)
    local countsByName = {}

    local function countItems(listLike)
        if not listLike then return 0 end

        local okLen, len = pcall(function()
            return #listLike
        end)
        if okLen and type(len) == 'number' then
            return len
        end

        local count = 0
        for _, _ in ipairs(listLike) do
            count = count + 1
        end
        return count
    end

    local targetNames = {}
    for _, name in ipairs(names or {}) do
        countsByName[name] = 0
        targetNames[name] = true
    end

    local function walk(keyword)
        if not keyword then return end

        local keywordName = keyword:getName()
        if targetNames[keywordName] then
            local photos = keyword:getPhotos()
            if photos then
                local count = countItems(photos)
                countsByName[keywordName] = (countsByName[keywordName] or 0) + count
            end
        end

        local children = keyword:getChildren()
        if children then
            for _, child in ipairs(children) do
                walk(child)
            end
        end
    end

    local roots = catalog:getKeywords()
    if roots then
        for _, root in ipairs(roots) do
            walk(root)
        end
    end
    return countsByName
end

LrTasks.startAsyncTask(function()
    trace('OpenKeywordEditor invoked')

    local catalog = LrApplication.activeCatalog()
    if not catalog then
        trace('No active catalog')
        LrDialogs.message('GB Keyword Editor', 'No active catalog.', 'warning')
        return
    end

    local targetPhotos = catalog:getTargetPhotos() or {}
    trace(string.format('Target photos: %d', #targetPhotos))
    if #targetPhotos == 0 then
        LrDialogs.message('GB Keyword Editor', 'Select one or more photos in Grid view.', 'info')
        return
    end

    -- Precompute initial rows with counts so the modal can render quickly.
    local union = KeywordService.getKeywordNameUnionForPhotos(targetPhotos)
    local catalogCountsByName = getCatalogKeywordCountsByName(catalog, union.names or {})
    local initialRows = {}
    local debugRows = {}
    for _, name in ipairs(union.names or {}) do
        local count = catalogCountsByName[name] or 0
        initialRows[#initialRows + 1] = { keyword = name, count = count }
        debugRows[#debugRows + 1] = string.format('%s=%s', tostring(name), tostring(count))
    end

    trace(string.format('Initial rows: %d', #initialRows))

    UI.showEditor {
        catalog = catalog,
        targetPhotos = targetPhotos,
        initialRows = initialRows,
        debugText = table.concat({
            'Launched via Library → Plug-in Extras',
            string.format('Initial keyword counts: %s', table.concat(debugRows, ', ')),
        }, '\n'),
        toolkitId = (_PLUGIN and _PLUGIN.id) or 'com.gb.keywordeditor',
    }
end)
