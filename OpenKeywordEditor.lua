local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'

local UI = require 'UI'
local KeywordService = require 'KeywordService'
local LogService = require 'LogService'

local function trace(msg)
    LogService.append(msg)
end
--[[
if not status then
  LrDialogs.message('OpenKeywordEditor, requireKeywordService error: ' .. KeywordService)
end
]]

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
    local union = KeywordService.getKeywordDataForPhotos(targetPhotos)
    local catalogCountsByName = KeywordService.getCatalogKeywordCountsByName(catalog, union.names or {})
    local initialRows = {}
    for _, name in ipairs(union.names or {}) do
        local count = catalogCountsByName[name] or 0
        initialRows[#initialRows + 1] = {
            keyword = name,
            count = count,
            keywordRef = union.keywordByName and union.keywordByName[name],
        }
    end

    trace(string.format('Initial rows: %d', #initialRows))

    UI.showEditor {
        catalog = catalog,
        targetPhotos = targetPhotos,
        initialRows = initialRows,
        toolkitId = (_PLUGIN and _PLUGIN.id) or 'com.gb.keywordeditor',
    }
end)
