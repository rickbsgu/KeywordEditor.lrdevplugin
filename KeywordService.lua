local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'

local KeywordService = {}

local function normalizeKeywordName(name)
    if not name then return '' end
    name = tostring(name)
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    return name
end

local function splitKeywordString(value)
    if type(value) ~= 'string' or value == '' then return {} end

    local out = {}
    for part in value:gmatch('[^,]+') do
        local name = normalizeKeywordName(part)
        if name ~= '' then
            out[#out + 1] = name
        end
    end
    return out
end

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

    -- Some LR builds do not expose catalog:findKeywordByName.
    if type(catalog.findKeywordByName) == 'function' then
        local ok, kw = pcall(function()
            return catalog:findKeywordByName(name)
        end)
        if ok and kw then
            return kw
        end
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

    local roots = catalog:getKeywords()
    if roots then
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

    local kw = KeywordService.findKeywordByName(catalog, name)
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

    local function countViaCatalogFind()
        if not catalog then return 0 end

        local function tryFind(value)
            local photos = catalog:findPhotos {
                searchDesc = {
                    criteria = {
                        {
                            criteria = 'keywords',
                            operation = 'contains',
                            value = value,
                        },
                    },
                },
            }

            if photos then
                return countItems(photos)
            end
            return 0
        end

        local count = tryFind(keyword)
        if count > 0 then return count end

        local name = keyword:getName()
        if type(name) == 'string' and name ~= '' then
            count = tryFind(name)
            if count > 0 then return count end
        end

        return 0
    end

    -- getPhotos() is the documented LrKeyword method; try it first.
    local photos = keyword:getPhotos()
    if photos then
        local count = countItems(photos)
        if count > 0 then
            return count
        end
    end

    -- Some builds expose a getPhotoCount() shortcut.
    local okCount, cnt = pcall(function()
        return keyword:getPhotoCount()
    end)
    if okCount and type(cnt) == 'number' then
        if cnt > 0 then
            return cnt
        end
    end

    -- Fallback: raw metadata.
    local okMeta, metaCount = pcall(function()
        return keyword:getRawMetadata('photoCount')
            or keyword:getRawMetadata('count')
    end)
    if okMeta and type(metaCount) == 'number' then
        if metaCount > 0 then
            return metaCount
        end
    end

    return countViaCatalogFind()
end

-- Catalog-wide count using catalog:findPhotos keyword search (works in LR builds where keyword:getPhotos isn't available).
function KeywordService.countPhotosWithKeywordViaCatalogFind(catalog, keyword)
    return KeywordService.countPhotosWithKeyword(catalog, keyword)
end

function KeywordService.getCatalogKeywordCountsByName(catalog, names)
    local countsByName = {}
    if not catalog or type(names) ~= 'table' or #names == 0 then
        return countsByName
    end

    local targetNames = {}
    for _, name in ipairs(names) do
        local normalized = normalizeKeywordName(name)
        if normalized ~= '' then
            targetNames[normalized] = true
            countsByName[normalized] = 0
        end
    end

    local function walk(keyword)
        if not keyword then return end

        local name = normalizeKeywordName(keyword:getName())
        if targetNames[name] then
            local photos = keyword:getPhotos()
            if photos then
                countsByName[name] = (countsByName[name] or 0) + countItems(photos)
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

    -- Last-resort fallback for builds where catalog:getKeywords() works poorly but
    -- string metadata may still exist on photos.
    local allZero = true
    for _, count in pairs(countsByName) do
        if count > 0 then
            allZero = false
            break
        end
    end

    if allZero then
        local function safeGetRawMetadata(photo, key)
            local ok, val = pcall(function()
                return photo:getRawMetadata(key)
            end)
            if ok then return val end
            return nil
        end

        local function safeGetFormattedMetadata(photo, key)
            local ok, val = pcall(function()
                return photo:getFormattedMetadata(key)
            end)
            if ok then return val end
            return nil
        end

        local okAllPhotos, photos = pcall(function()
            return catalog:getAllPhotos()
        end)
        if okAllPhotos and photos then
            for _, photo in ipairs(photos) do
                local namesFound = {}
                local seen = {}
                local formatted = safeGetFormattedMetadata(photo, 'keywordTagsForDisplay')
                    or safeGetFormattedMetadata(photo, 'keywordTags')
                    or safeGetFormattedMetadata(photo, 'keywords')
                    or safeGetRawMetadata(photo, 'keywordTags')
                    or safeGetRawMetadata(photo, 'keywords')

                if type(formatted) == 'string' then
                    namesFound = splitKeywordString(formatted)
                end

                for _, name in ipairs(namesFound) do
                    if targetNames[name] and not seen[name] then
                        seen[name] = true
                        countsByName[name] = (countsByName[name] or 0) + 1
                    end
                end
            end
        end
    end

    return countsByName
end

function KeywordService.countPhotosWithKeywordName(catalog, name)
    name = normalizeKeywordName(name)
    if name == '' then return 0 end

    local countsByName = KeywordService.getCatalogKeywordCountsByName(catalog, { name })
    return countsByName[name] or 0
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
