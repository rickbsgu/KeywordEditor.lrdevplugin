local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

local LogService = {}

local function nowIso()
    -- Lightroom's Lua has os.date.
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function ensureParentDir(path)
    if type(path) ~= 'string' or path == '' then return false end
    local parent = LrPathUtils.parent(path)
    if not parent or parent == '' then return false end
    if LrFileUtils.exists(parent) then return true end
    return LrFileUtils.createAllDirectories(parent)
end

local function expandHome(path)
    if type(path) ~= 'string' then return path end
    if path:sub(1, 2) == '~/' then
        local home = os.getenv('HOME')
        if home and home ~= '' then
            return home .. path:sub(2)
        end
    end
    return path
end

function LogService.append(logPath, message)
    if type(logPath) ~= 'string' or logPath == '' then return false end
    logPath = expandHome(logPath)
    if type(message) ~= 'string' then message = tostring(message) end

    ensureParentDir(logPath)

    local fh = io.open(logPath, 'a')
    if not fh then return false end

    fh:write(string.format('[%s] %s\n', nowIso(), message))
    fh:close()
    return true
end

return LogService
