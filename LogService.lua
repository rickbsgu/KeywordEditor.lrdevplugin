local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

local LogService = {}

local function nowIso()
    -- Lightroom's Lua has os.date.
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

function LogService.append(message)
    local logPath = "/Volumes/INVME/dev/lightroom/KeywordEditor.lrdevplugin/log/log.txt"
    local fh = io.open(logPath, 'w')
    if not fh then return false end

    fh:write(string.format('[%s] %s\n', nowIso(), message))
    fh:close()
    return true
end

return LogService
