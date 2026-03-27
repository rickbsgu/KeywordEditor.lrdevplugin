local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrColor = import 'LrColor'

local KeywordService = require 'KeywordService'
local RecentlyUsed = require 'RecentlyUsed'
local PrefsService = require 'PrefsService'
local okLogService, LogService = pcall(require, 'LogService')

local UI = {}
local loadRowsFromSelection

local MAX_ROWS = 200
local DEBUG_MAX_LINES = 80
local ROW_VERTICAL_GAP = 6
local KEYWORD_LIST_BG = LrColor(0.94, 0.94, 0.94)

local function trim(s)
    if not s then return '' end
    s = tostring(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function rowVisibleKey(i) return 'row_' .. tostring(i) .. '_visible' end
local function rowCountKey(i) return 'row_' .. tostring(i) .. '_count' end
local function rowKeywordKey(i) return 'row_' .. tostring(i) .. '_keyword' end

local function renderDebugText(context)
    local header = (context and context._debugHeader) or ''
    local lines = (context and context._debugLines) or {}
    if #lines == 0 then
        return header
    end
    if header == '' then
        return table.concat(lines, '\n')
    end
    return header .. '\n\n' .. table.concat(lines, '\n')
end

local function setDebugHeader(context, header)
    if not context then return end
    context._debugHeader = header or ''
    if context.props then
        context.props.debugText = renderDebugText(context)
    end
end

local function appendDebug(context, msg)
    if not context then return end
    if not context._debugLines then
        context._debugLines = {}
    end

    context._debugLines[#context._debugLines + 1] = tostring(msg)
    while #context._debugLines > DEBUG_MAX_LINES do
        table.remove(context._debugLines, 1)
    end

    if context.props then
        context.props.debugText = renderDebugText(context)
    end
end

local function trace(context, msg)
    appendDebug(context, msg)

    if not okLogService or not LogService or type(LogService.append) ~= 'function' then
        return
    end

    local logPath = '~/Library/Logs/Adobe/Lightroom/GBKeywordEditor.log'
    if _G and type(_G.GBKeywordEditorLogPath) == 'string' and _G.GBKeywordEditorLogPath ~= '' then
        logPath = _G.GBKeywordEditorLogPath
    end

    local prefix = 'UI'
    if context and type(context) == 'table' then
        local toolkitId = context.toolkitId
        if type(toolkitId) == 'string' and toolkitId ~= '' then
            prefix = prefix .. ' ' .. toolkitId
        end
    end

    LogService.append(logPath, string.format('%s: %s', prefix, tostring(msg)))
end

local function syncRowsToProps(context)
    local props = context.props
    local rows = context.rows or {}

    props.rows = rows

    for i = 1, MAX_ROWS do
        local row = rows[i]
        props[rowVisibleKey(i)] = row and true or false
        props[rowCountKey(i)] = row and tostring(row.count or '') or ''
        props[rowKeywordKey(i)] = row and tostring(row.keyword or '') or ''
    end

    if not props.currentRow or props.currentRow < 0 then
        props.currentRow = 0
    end
    if props.currentRow > #rows then
        props.currentRow = 0
    end
end

local function setCurrentRow(context, index)
    local props = context.props
    local rows = context.rows or {}
    if not rows[index] then return end
    props.currentRow = index
end

local function refreshSuggestions(context)
    local props = context.props
    local rows = context.rows or {}

    if props.suggestionsDismissed then
        props.suggestions = {}
        return
    end

    local idx = props.currentRow
    if not idx or idx <= 0 then
        props.suggestions = {}
        return
    end

    local row = rows[idx]
    if not row then
        props.suggestions = {}
        return
    end

    local prefix = trim(row.keyword)
    if prefix == '' then
        props.suggestions = {}
        return
    end

    props.suggestions = KeywordService.searchKeywordNames(prefix, context.allKeywordNames, 7)
end

local function updateCountForCurrentRow(context)
    local props = context.props
    local rows = context.rows or {}

    local rowIndex = props.currentRow
    if not rowIndex or rowIndex <= 0 then return end
    local row = rows[rowIndex]
    if not row then return end

    local count = KeywordService.countPhotosWithKeywordName(context.catalog, row.keyword)
    row.count = tostring(count)
    syncRowsToProps(context)

    trace(context, string.format('updateCountForCurrentRow: %s -> %s', tostring(row.keyword), tostring(row.count)))
end

local function applyKeywordToSelection(context, keywordName)
    keywordName = trim(keywordName)
    if keywordName == '' then return end

    LrTasks.startAsyncTask(function()
        local kw = KeywordService.findKeywordByName(context.catalog, keywordName)
        if not kw then
            local btn = LrDialogs.confirm(
                'Confirm New Keyword',
                'Keyword "' .. keywordName .. '" does not exist. Create it?',
                'Ok',
                'Cancel'
            )
            if btn ~= 'ok' then return end
            kw = KeywordService.ensureKeywordExists(context.catalog, keywordName)
        end

        if not kw then return end

        KeywordService.applyKeywordToPhotos(context.catalog, kw, context.targetPhotos)

        local rowIndex = context.props.currentRow
        if rowIndex and rowIndex > 0 and context.rows and context.rows[rowIndex] then
            context.rows[rowIndex].keywordRef = kw
            context.rows[rowIndex].keyword = keywordName
        end

        RecentlyUsed.bump(context.recent, keywordName)
        PrefsService.saveRecent(context.toolkitId, RecentlyUsed.exportItems(context.recent))

        updateCountForCurrentRow(context)
        context.props.recentVersion = (context.props.recentVersion or 0) + 1
        context.props.suggestions = {}

        syncRowsToProps(context)
    end)
end

local function addRow(context)
    if not context.rows then context.rows = {} end

    context.rows[#context.rows + 1] = {
        count = '',
        keyword = '',
        keywordRef = nil,
    }

    context.props.currentRow = #context.rows
    context.props.suggestionsDismissed = false

    syncRowsToProps(context)
    refreshSuggestions(context)
end

local function deleteRow(context, index)
    local rows = context.rows or {}
    local row = rows[index]
    if not row then return end

    -- Optimistic UI update so the row disappears immediately.
    local keywordName = trim(row.keyword)
    table.remove(rows, index)
    context.rows = rows
    context.props.currentRow = 0
    context.props.suggestions = {}
    context.props.suggestionsDismissed = false
    syncRowsToProps(context)

    LrTasks.startAsyncTask(function()
        local kw = row.keywordRef

        if not kw and keywordName ~= '' then
            kw = KeywordService.findKeywordByName(context.catalog, keywordName)
        end

        if kw then
            KeywordService.removeKeywordFromPhotos(context.catalog, kw, context.targetPhotos)
            trace(context, string.format('delete-row applied for %s', tostring(keywordName)))
        else
            trace(context, string.format('delete-row could not resolve keyword for %s', tostring(keywordName)))
        end

        -- Reconcile rows from fresh selected-photo state after deletion.
        context.targetPhotos = context.catalog:getTargetPhotos() or context.targetPhotos
        context.initialRows = nil
        loadRowsFromSelection(context)
        syncRowsToProps(context)
    end)
end

loadRowsFromSelection = function(context)
    local rows = {}

    if context.initialRows and #context.initialRows > 0 then
        for _, r in ipairs(context.initialRows) do
            local keyword = r.keyword or r.name or ''
            local count = r.count
            if count == nil then count = '' end

            rows[#rows + 1] = {
                keyword = keyword,
                count = tostring(count),
                keywordRef = r.keywordRef,
            }
        end
    else
        local data = KeywordService.getKeywordNameUnionForPhotos(context.targetPhotos or {})
        local countsByName = KeywordService.getCatalogKeywordCountsByName(context.catalog, data.names or {})

        for _, name in ipairs(data.names or {}) do
            rows[#rows + 1] = {
                keyword = name,
                count = tostring(countsByName[name] or 0),
                keywordRef = data.keywordByName and data.keywordByName[name],
            }
        end
    end

    context.rows = rows
    syncRowsToProps(context)
    refreshSuggestions(context)
end

local function buildRowsView(f, context)
    local props = context.props
    local bind = LrView.bind

    local children = {}
    for i = 1, MAX_ROWS do
        children[#children + 1] = f:view {
            bind_to_object = props,
            visible = bind(rowVisibleKey(i)),

            f:column {
                spacing = 0,

                f:row {
                    spacing = 2,

                    f:static_text {
                        width_in_chars = 1,
                        title = bind {
                            keys = { 'currentRow' },
                            operation = function(values)
                                return (tonumber(values.currentRow) == i) and '>' or ' '
                            end,
                        },
                    },

                    f:static_text {
                        width_in_chars = 3,
                        title = bind(rowCountKey(i)),
                        alignment = 'right',
                        mouse_down = function()
                            setCurrentRow(context, i)
                            refreshSuggestions(context)
                        end,
                    },

                    f:edit_field {
                        width_in_chars = 24,
                        value = bind(rowKeywordKey(i)),
                        immediate = true,
                        mouse_down = function()
                            setCurrentRow(context, i)
                            context.props.suggestionsDismissed = false
                            refreshSuggestions(context)
                        end,
                        value_change = function(v)
                            local row = context.rows and context.rows[i]
                            if not row then return end

                            row.keyword = v
                            row.keywordRef = nil
                            syncRowsToProps(context)
                            refreshSuggestions(context)
                        end,
                        action = function()
                            setCurrentRow(context, i)
                            local row = context.rows and context.rows[i]
                            if row then
                                applyKeywordToSelection(context, row.keyword)
                            end
                        end,
                    },

                    f:push_button {
                        title = 'X',
                        width = 24,
                        action = function()
                            deleteRow(context, i)
                        end,
                    },
                },

                f:spacer { height = ROW_VERTICAL_GAP },
            },
        }
    end

    return f:scrolled_view {
        height = 220,
        width = 600,
        horizontal_scroller = false,
        vertical_scroller = true,
        background_color = KEYWORD_LIST_BG,

        f:view {
            background_color = KEYWORD_LIST_BG,

            f:column {
                -- Hidden slot views still participate in column spacing in some LR builds.
                -- Keep spacing at 0 so invisible rows don't consume vertical layout.
                spacing = 0,
                unpack(children),
            },
        },
    }
end

local function buildSuggestionsView(f, context)
    local props = context.props
    local children = {}

    if props.suggestionsDismissed then
        children[#children + 1] = f:row {
            spacing = f:control_spacing(),
            f:static_text { title = 'Suggestions dismissed' },
            f:push_button {
                title = 'Show',
                action = function()
                    props.suggestionsDismissed = false
                    refreshSuggestions(context)
                end,
            },
        }
        return f:column { spacing = f:control_spacing(), unpack(children) }
    end

    if not props.suggestions or #props.suggestions == 0 then
        return f:column { spacing = f:control_spacing(), f:static_text { title = '' } }
    end

    children[#children + 1] = f:static_text { title = 'Suggestions:' }
    for _, name in ipairs(props.suggestions) do
        children[#children + 1] = f:push_button {
            title = name,
            action = function()
                local idx = props.currentRow
                if not idx or idx <= 0 then return end
                if not context.rows or not context.rows[idx] then return end

                context.rows[idx].keyword = name
                context.rows[idx].keywordRef = nil
                syncRowsToProps(context)
                refreshSuggestions(context)
            end,
        }
    end

    children[#children + 1] = f:push_button {
        title = 'Dismiss',
        action = function()
            props.suggestionsDismissed = true
            props.suggestions = {}
        end,
    }

    return f:column { spacing = f:control_spacing(), unpack(children) }
end

local function buildRecentView(f, context)
    local props = context.props
    local children = {}

    for _, name in ipairs(RecentlyUsed.getNames(context.recent)) do
        children[#children + 1] = f:push_button {
            title = name,
            action = function()
                local idx = props.currentRow
                if not idx or idx <= 0 then return end
                if not context.rows or not context.rows[idx] then return end

                context.rows[idx].keyword = name
                context.rows[idx].keywordRef = nil
                RecentlyUsed.bump(context.recent, name)
                PrefsService.saveRecent(context.toolkitId, RecentlyUsed.exportItems(context.recent))
                props.recentVersion = (props.recentVersion or 0) + 1
                syncRowsToProps(context)
                applyKeywordToSelection(context, name)
            end,
        }
    end

    if #children == 0 then
        children[#children + 1] = f:static_text { title = 'No recent keywords yet' }
    end

    return f:row { spacing = f:control_spacing(), unpack(children) }
end

function UI.showEditor(context)
    LrFunctionContext.callWithContext('GBKeywordEditor', function(fc)
        context._debugLines = {}
        context._debugHeader = ''

        trace(context, 'showEditor: begin')

        context.recent = RecentlyUsed.new(10)
        context.toolkitId = context.toolkitId or 'com.gb.keywordeditor.dev2'
        RecentlyUsed.loadInto(context.recent, PrefsService.loadRecent(context.toolkitId))
        context.allKeywordNames = KeywordService.getAllKeywordNames(context.catalog)
        trace(context, string.format('showEditor: loaded %d keyword names', context.allKeywordNames and #context.allKeywordNames or 0))

        local f = LrView.osFactory()
        local bind = LrView.bind
        local props = LrBinding.makePropertyTable(fc)
        context.props = props

        props.currentRow = 0
        props.recentVersion = 0
        props.suggestions = {}
        props.suggestionsDismissed = false
        props.debugText = ''

        loadRowsFromSelection(context)
        trace(context, string.format('showEditor: rows=%d currentRow=%d', context.rows and #context.rows or 0, tonumber(props.currentRow) or 0))

        local function buildDebugHeader()
            local lines = {}
            lines[#lines + 1] = 'DEBUG:'
            lines[#lines + 1] = string.format('Selected photos: %s', tostring(context.targetPhotos and #context.targetPhotos or 0))
            lines[#lines + 1] = string.format('Initial rows: %s', tostring(context.initialRows and #context.initialRows or 0))
            lines[#lines + 1] = string.format('catalog.findPhotos type: %s (must be called in LrTask)', tostring(type(context.catalog.findPhotos)))
            return (context.debugText and (context.debugText .. '\n\n' .. table.concat(lines, '\n'))) or table.concat(lines, '\n')
        end

        setDebugHeader(context, buildDebugHeader())
        appendDebug(context, 'debug channel active')

        local content = f:column {
            spacing = f:control_spacing(),
            fill_horizontal = 1,

            f:scrolled_view {
                width = 700,
                height = 160,
                horizontal_scroller = true,
                vertical_scroller = true,

                f:edit_field {
                    bind_to_object = props,
                    value = bind 'debugText',
                    width_in_chars = 90,
                    height_in_lines = 30,
                    tooltip = 'Debug output (temporary). You can select/copy this text.',
                },
            },

            f:row {
                fill_horizontal = 1,
                f:spacer { fill_horizontal = 1 },
                f:push_button {
                    title = 'Create Keyword',
                    action = function()
                        addRow(context)
                    end,
                },
            },

            f:separator { fill_horizontal = 1 },

            f:group_box {
                title = 'Keywords',
                fill_horizontal = 1,
                buildRowsView(f, context),
            },

            f:group_box {
                title = 'Completion',
                fill_horizontal = 1,
                buildSuggestionsView(f, context),
            },

            f:separator { fill_horizontal = 1 },

            f:group_box {
                title = 'Recently Used Keywords',
                fill_horizontal = 1,
                buildRecentView(f, context),
            },
        }

        local result = LrDialogs.presentModalDialog {
            title = 'GB Keyword Editor',
            contents = content,
            actionVerb = 'Close',
        }

        trace(context, string.format('showEditor: dialog closed result=%s', tostring(result)))
        return result
    end)
end

return UI
