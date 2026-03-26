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
    local initialRows = {}
    for _, name in ipairs(union.names or {}) do
        local kw = KeywordService.findKeywordByName(catalog, name)
        local count = kw and KeywordService.countPhotosWithKeyword(catalog, kw) or ''
        initialRows[#initialRows + 1] = { keyword = name, count = count }
    end

    trace(string.format('Initial rows: %d', #initialRows))

    UI.showEditor {
        catalog = catalog,
        targetPhotos = targetPhotos,
        initialRows = initialRows,
        debugText = 'Launched via Library → Plug-in Extras',
        toolkitId = (_PLUGIN and _PLUGIN.id) or 'com.gb.keywordeditor',
    }
end)
