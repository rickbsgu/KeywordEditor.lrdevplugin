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

    local ok, kw = pcall(function()
        return catalog:findKeywordByName(name)
    end)
    if ok and kw then
        return kw
    end

    -- Fallback for older/variant SDKs without catalog:findKeywordByName.
    local function walk(keyword)
        if not keyword then return nil end
        local kname = keyword:getName()
        if kname == name then
            return keyword
        end
        local children = keyword:getChildren()
        if children then
            for _, child in ipairs(children) do
                local found = walk(child)
                if found then return found end
            end
        end
        return nil
    end

    local rootsOk, roots = pcall(function()
        return catalog:getKeywords()
    end)
    if rootsOk and roots then
        for _, root in ipairs(roots) do
            local found = walk(root)
            if found then return found end
        end
    end

    return nil
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

    local okCount, cnt = pcall(function()
        return keyword:getPhotoCount()
    end)
    if okCount and cnt then
        return cnt
    end

    local okPhotos, photos = pcall(function()
        return keyword:getPhotos()
    end)
    if okPhotos and photos then
        return #photos
    end

    -- Fallback: some LR builds expose counts only via raw metadata.
    local okMeta, metaCount = pcall(function()
        return keyword:getRawMetadata('photoCount')
            or keyword:getRawMetadata('count')
            or keyword:getRawMetadata('photos')
    end)
    if okMeta and type(metaCount) == 'number' then
        return metaCount
    end

    return 0
end

-- Catalog-wide count using catalog:findPhotos keyword search (works in LR builds where keyword:getPhotos isn't available).
function KeywordService.countPhotosWithKeywordViaCatalogFind(catalog, keyword)
    if not catalog or not keyword then return 0 end

    local ok, photos = pcall(function()
        return catalog:findPhotos {
            searchDesc = {
                criteria = {
                    {
                        criteria = 'keywords',
                        operation = 'contains',
                        value = keyword,
                    },
                },
            },
        }
    end)

    if ok and photos then
        return #photos
    end
    return 0
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

-- Returns { names = {..sorted..}, countsByName = { [name] = nSelectedPhotosWithKeyword } }
function KeywordService.getKeywordNameUnionForPhotos(photos)
    local countsByName = {}
    local keywordByName = {}
    if not photos or #photos == 0 then
        return { names = {}, countsByName = countsByName, keywordByName = keywordByName }
    end

    local function safeGetRawMetadata(photo, key)
        local ok, val = pcall(function()
            return photo:getRawMetadata(key)
        end)
        if ok then return val end
        return nil
    end

    local foundViaRawMetadata = false

    for _, photo in ipairs(photos) do
        -- Different Lightroom versions expose keyword info under different keys.
        -- Use pcall so unknown keys don't throw and break the plugin.
        local kws = safeGetRawMetadata(photo, 'keywords')
            or safeGetRawMetadata(photo, 'keywordTags')
            or safeGetRawMetadata(photo, 'keywordTag')
            or safeGetRawMetadata(photo, 'keyword')
        if kws then
            foundViaRawMetadata = true
            local seenOnThisPhoto = {}
            for _, kw in ipairs(kws) do
                local name = normalizeKeywordName(kw:getName())
                if name ~= '' and not seenOnThisPhoto[name] then
                    seenOnThisPhoto[name] = true
                    countsByName[name] = (countsByName[name] or 0) + 1
                    keywordByName[name] = kw
                end
            end
        end
    end

    -- Fallback: If photo keyword raw metadata isn't available, walk keywords in catalog.
    if not foundViaRawMetadata then
        local catalog = LrApplication.activeCatalog()
        local selectedSet = {}
        for _, p in ipairs(photos) do
            local ok, id = pcall(function() return p.localIdentifier end)
            if ok and id then
                selectedSet[id] = true
            end
        end

        local function walk(keyword)
            local name = normalizeKeywordName(keyword:getName())
            local photosWithKw = keyword:getPhotos()
            if photosWithKw and #photosWithKw > 0 then
                local n = 0
                for _, p in ipairs(photosWithKw) do
                    local ok, id = pcall(function() return p.localIdentifier end)
                    if ok and id and selectedSet[id] then
                        n = n + 1
                    end
                end
                if n > 0 and name ~= '' then
                    countsByName[name] = n
                    keywordByName[name] = keyword
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
            for _, kw in ipairs(roots) do
                walk(kw)
            end
        end
    end

    local names = {}
    for name, _ in pairs(countsByName) do
        names[#names + 1] = name
    end
    table.sort(names)
    return { names = names, countsByName = countsByName, keywordByName = keywordByName }
end

return KeywordService
