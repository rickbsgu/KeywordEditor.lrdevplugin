local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'

local KeywordService = {}

local function normalizeKeywordName(name)
    if not name then return '' end
    name = tostring(name)
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    return name
end

function KeywordService.getAllKeywordNames(catalog)
    local root = catalog:getKeywords()
    local out = {}

    local function walk(keyword)
        local name = keyword:getName()
        if name and name ~= '' then
            out[#out + 1] = name
        end
        local children = keyword:getChildren()
        if children then
            for _, child in ipairs(children) do
                walk(child)
            end
        end
    end

    if root then
        for _, kw in ipairs(root) do
            walk(kw)
        end
    end

    table.sort(out)
    return out
end

function KeywordService.findKeywordByName(catalog, name)
    name = normalizeKeywordName(name)
    if name == '' then return nil end
    return catalog:findKeywordByName(name)
end

function KeywordService.ensureKeywordExists(catalog, name)
    name = normalizeKeywordName(name)
    if name == '' then return nil end

    local kw = catalog:findKeywordByName(name)
    if kw then return kw end

    catalog:withWriteAccessDo('Create Keyword', function()
        kw = catalog:createKeyword(name, {}, true, nil, true)
    end)

    return kw
end

function KeywordService.applyKeywordToPhotos(catalog, keyword, photos)
    if not keyword or not photos or #photos == 0 then return end

    catalog:withWriteAccessDo('Apply Keyword', function()
        for _, photo in ipairs(photos) do
            photo:addKeyword(keyword)
        end
    end)
end

function KeywordService.countPhotosWithKeyword(catalog, keyword)
    if not keyword then return 0 end

    local photos = keyword:getPhotos()
    if not photos then return 0 end
    return #photos
end

function KeywordService.searchKeywordNames(prefix, allNames, limit)
    prefix = normalizeKeywordName(prefix)
    if prefix == '' then return {} end

    limit = limit or 7
    local lowerPrefix = prefix:lower()

    local matches = {}
    for _, name in ipairs(allNames) do
        if #matches >= limit then break end
        if name:lower():find(lowerPrefix, 1, true) == 1 then
            matches[#matches + 1] = name
        end
    end
    return matches
end

return KeywordService
