local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrColor = import 'LrColor'

local KeywordService = require 'KeywordService'
local RecentlyUsed = require 'RecentlyUsed'
local PrefsService = require 'PrefsService'

local UI = {}

local function trim(s)
    if not s then return '' end
    s = tostring(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function ensureRow(props)
    if not props.rows then props.rows = {} end
end

local function addRow(props)
    ensureRow(props)
    local row = {
        count = '',
        keyword = '',
    }
    table.insert(props.rows, row)
    props.currentRow = #props.rows
end

local function deleteRow(props, index)
    if not props.rows or not props.rows[index] then return end
    table.remove(props.rows, index)
    props.currentRow = 0
end

local function setCurrentRow(props, index)
    if not props.rows or not props.rows[index] then return end
    props.currentRow = index
end

local function updateCountForRow(context)
    local props = context.props
    local rowIndex = props.currentRow
    if not rowIndex or rowIndex <= 0 then return end
    local row = props.rows[rowIndex]
    if not row then return end

    local kw = KeywordService.findKeywordByName(context.catalog, row.keyword)
    if not kw then
        row.count = ''
        props.rows = props.rows
        return
    end
    row.count = tostring(KeywordService.countPhotosWithKeyword(context.catalog, kw))
    props.rows = props.rows
end

local function refreshSuggestions(context)
    local props = context.props
    if props.suggestionsDismissed then
        props.suggestions = {}
        return
    end

    local idx = props.currentRow
    if not idx or idx <= 0 then
        props.suggestions = {}
        return
    end
    local row = props.rows[idx]
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

local function applyKeywordToSelection(context, keywordName)
    keywordName = trim(keywordName)
    if keywordName == '' then return end

    local kw = KeywordService.findKeywordByName(context.catalog, keywordName)
    if not kw then
        local btn = LrDialogs.confirm(
            'Confirm New Keyword',
            'Keyword "' .. keywordName .. '" does not exist. Create it?',
            'Ok',
            'Cancel'
        )
        if btn ~= 'ok' then
            return
        end
        kw = KeywordService.ensureKeywordExists(context.catalog, keywordName)
    end

    if not kw then return end

    KeywordService.applyKeywordToPhotos(context.catalog, kw, context.targetPhotos)
    RecentlyUsed.bump(context.recent, keywordName)
    PrefsService.saveRecent(context.toolkitId, RecentlyUsed.exportItems(context.recent))
    updateCountForRow(context)
    context.props.recentVersion = (context.props.recentVersion or 0) + 1
    context.props.suggestions = {}
end

local function buildRowsView(f, context)
    local props = context.props

    local rows = f:column {
        spacing = f:control_spacing(),
        bind_to_object = props,
    }

    local function rebuild()
        local children = {}
        for i, row in ipairs(props.rows) do
            local isCurrent = (props.currentRow == i)

            children[#children + 1] = f:row {
                spacing = f:control_spacing(),
                background = isCurrent and LrColor.rgb(0x90 / 255, 0xEE / 255, 0x90 / 255) or nil,

                f:static_text {
                    width_in_chars = 6,
                    title = row.count,
                    alignment = 'right',
                    mouse_down = function()
                        setCurrentRow(props, i)
                    end,
                },

                f:edit_field {
                    width_in_chars = 30,
                    value = LrBinding.bind('rows[' .. i .. '].keyword'),
                    immediate = true,
                    mouse_down = function()
                        setCurrentRow(props, i)
                        props.suggestionsDismissed = false
                        refreshSuggestions(context)
                    end,
                    value_change = function()
                        refreshSuggestions(context)
                    end,
                    action = function()
                        applyKeywordToSelection(context, row.keyword)
                    end,
                },

                f:push_button {
                    title = 'X',
                    width = 24,
                    mouse_down = function()
                        deleteRow(props, i)
                    end,
                },
            }
        end

        rows:setChildren(children)
    end

    props:addObserver('rows', rebuild)
    props:addObserver('currentRow', rebuild)

    rebuild()

    return rows
end

local function buildSuggestionsView(f, context)
    local props = context.props

    local container = f:row {
        spacing = f:control_spacing(),
        bind_to_object = props,
    }

    local function rebuild()
        local children = {}

        if props.suggestionsDismissed then
            children[#children + 1] = f:static_text { title = 'Suggestions dismissed' }
            children[#children + 1] = f:push_button {
                title = 'Show',
                action = function()
                    props.suggestionsDismissed = false
                    refreshSuggestions(context)
                    props.suggestionsVersion = (props.suggestionsVersion or 0) + 1
                end,
            }
            container:setChildren(children)
            return
        end

        if not props.suggestions or #props.suggestions == 0 then
            container:setChildren({ f:static_text { title = '' } })
            return
        end

        children[#children + 1] = f:static_text { title = 'Suggestions:' }
        for _, name in ipairs(props.suggestions) do
            children[#children + 1] = f:push_button {
                title = name,
                action = function()
                    local idx = props.currentRow
                    if not idx or idx <= 0 then return end
                    props.rows[idx].keyword = name
                    props.rows = props.rows
                    refreshSuggestions(context)
                end,
            }
        end

        children[#children + 1] = f:push_button {
            title = 'Dismiss',
            action = function()
                props.suggestionsDismissed = true
                props.suggestions = {}
                props.suggestionsVersion = (props.suggestionsVersion or 0) + 1
            end,
        }

        container:setChildren(children)
    end

    props:addObserver('suggestionsVersion', rebuild)
    props:addObserver('suggestions', rebuild)
    rebuild()

    return container
end

local function buildRecentView(f, context)
    local props = context.props

    local container = f:row {
        spacing = f:control_spacing(),
        bind_to_object = props,
    }

    local function rebuild()
        local children = {}
        for _, name in ipairs(RecentlyUsed.getNames(context.recent)) do
            children[#children + 1] = f:push_button {
                title = name,
                action = function()
                    local idx = props.currentRow
                    if not idx or idx <= 0 then
                        return
                    end
                    props.rows[idx].keyword = name
                    props.rows = props.rows
                    RecentlyUsed.bump(context.recent, name)
                    PrefsService.saveRecent(context.toolkitId, RecentlyUsed.exportItems(context.recent))
                    props.recentVersion = (props.recentVersion or 0) + 1
                    applyKeywordToSelection(context, name)
                end,
            }
        end
        container:setChildren(children)
    end

    props:addObserver('recentVersion', rebuild)
    rebuild()

    return container
end

function UI.showEditor(context)
    LrFunctionContext.callWithContext('GBKeywordEditor', function(fc)
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(fc)

        context.props = props
        context.recent = RecentlyUsed.new(10)
        context.toolkitId = context.toolkitId or 'com.gb.keywordeditor'
        RecentlyUsed.loadInto(context.recent, PrefsService.loadRecent(context.toolkitId))
        context.allKeywordNames = KeywordService.getAllKeywordNames(context.catalog)

        props.rows = {}
        props.currentRow = 0
        props.recentVersion = 0
        props.suggestions = {}
        props.suggestionsVersion = 0
        props.suggestionsDismissed = false

        local content = f:column {
            spacing = f:control_spacing(),
            fill_horizontal = 1,

            f:row {
                fill_horizontal = 1,
                f:spacer { fill_horizontal = 1 },
                f:push_button {
                    title = 'Create Keyword',
                    action = function()
                        addRow(props)
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

        return result
    end)
end

return UI
