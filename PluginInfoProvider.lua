local LrView = import 'LrView'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'

return {
    sectionsForTopOfDialog = function(_, _)
        local f = LrView.osFactory()
        local pluginId = _PLUGIN and _PLUGIN.id or '(unknown)'
        local pluginName = _PLUGIN and _PLUGIN.name or '(unknown)'
        local lrVer = tostring(LrApplication.versionString())
        return {
            {
                title = 'GB Keyword Editor',
                f:static_text {
                    title = 'Use Library > Plug-in Extras in Grid view.',
                },

                f:static_text {
                    title = string.format('Plugin loaded: name=%s id=%s Lightroom=%s', tostring(pluginName), tostring(pluginId), lrVer),
                },

                f:push_button {
                    title = 'Test: Launch Keyword Editor',
                    action = function()
                        LrDialogs.message(
                            'GB Keyword Editor',
                            'Use Library → Plug-in Extras → Open GB Keyword Editor to launch.\n\nThis button cannot launch the modal reliably in this Lightroom build.',
                            'info'
                        )
                    end,
                },
            },
        }
    end,
}
