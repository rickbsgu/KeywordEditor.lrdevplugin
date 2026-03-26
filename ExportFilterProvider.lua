local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrLogger = import 'LrLogger'
local okLogService, LogService = pcall(require, 'LogService')

local logger = LrLogger('GBKeywordEditorLauncher')
logger:enable('logfile')
logger:trace('ExportFilterProvider module loaded')

local function trace(msg)
    logger:trace(msg)
    if not okLogService or not LogService or type(LogService.append) ~= 'function' then
        return
    end
    -- Default to Lightroom's standard log location; allow override via global.
    local logPath = '~/Library/Logs/Adobe/Lightroom/GBKeywordEditor.log'
    if _G and type(_G.GBKeywordEditorLogPath) == 'string' and _G.GBKeywordEditorLogPath ~= '' then
        logPath = _G.GBKeywordEditorLogPath
    end
    LogService.append(logPath, msg)
end

return {
    hideSections = { 'exportLocation' },

    sectionsForTopOfDialog = function(_, _)
        local f = LrView.osFactory()
        return {
            {
                title = 'GB Keyword Editor (Launcher)',
                f:static_text {
                    title = 'Temporary entrypoint: click Run in Post-Process Actions to launch a canary dialog.',
                },
            },
        }
    end,

    startDialog = function(_propertyTable)
        -- Some builds call this when the action is selected.
        trace('startDialog called')
        LrTasks.startAsyncTask(function()
            LrDialogs.message('GB Keyword Editor', 'Post-Process Action startDialog (canary)', 'info')
        end)
    end,

    endDialog = function(_propertyTable)
        -- Some builds call this when the export dialog closes.
    end,

    postProcessRenderedPhotos = function(functionContext, exportContext)
        -- Canonical hook for Post-Process Actions.
        trace('postProcessRenderedPhotos called')
        LrTasks.startAsyncTask(function()
            LrDialogs.message('GB Keyword Editor', 'postProcessRenderedPhotos fired (canary)', 'info')
        end)
    end,

    processRenderedPhotos = function(functionContext, exportContext)
        -- Older/alternate hook name.
        trace('processRenderedPhotos called')
        LrTasks.startAsyncTask(function()
            LrDialogs.message('GB Keyword Editor', 'processRenderedPhotos fired (canary)', 'info')
        end)
    end,

    postProcessRenderedVideo = function(functionContext, exportContext)
        trace('postProcessRenderedVideo called')
        LrTasks.startAsyncTask(function()
            LrDialogs.message('GB Keyword Editor', 'postProcessRenderedVideo fired (canary)', 'info')
        end)
    end,
}
