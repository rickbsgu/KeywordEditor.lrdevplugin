local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'

local UI = require 'UI'

LrTasks.startAsyncTask(function()
    local catalog = LrApplication.activeCatalog()
    local targetPhotos = catalog:getTargetPhotos()
    if not targetPhotos or #targetPhotos == 0 then
        LrDialogs.message('GB Keyword Editor', 'Select one or more photos in Grid view.', 'info')
        return
    end

    UI.showEditor({
        catalog = catalog,
        targetPhotos = targetPhotos,
    })
end)
