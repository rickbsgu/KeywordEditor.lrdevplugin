local LrView = import 'LrView'

return {
    sectionsForTopOfDialog = function(_, _)
        local f = LrView.osFactory()
        return {
            {
                title = 'GB Keyword Editor',
                f:static_text {
                    title = 'Use Library > Open GB Keyword Editor in Grid view.',
                },
            },
        }
    end,
}
