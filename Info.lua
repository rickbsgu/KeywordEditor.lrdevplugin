return {
    -- Let Lightroom choose the appropriate SDK compatibility.
    -- (Hard-pinning versions can cause load failures across builds.)
    LrSdkVersion = 15.0,

    LrToolkitIdentifier = 'com.gb.keywordeditor',
    LrPluginName = 'GB Keyword Editor',

    LrExportFilterProvider = {
        title = 'GB Keyword Editor (Launcher)',
        file = 'ExportFilterProvider.lua',
        id = 'com.gb.keywordeditor.launcher',
    },

    LrLibraryMenuItems = {
        {
            title = 'Open GB Keyword Editor',
            file = 'OpenKeywordEditor.lua',
        },
    },

    LrPluginInfoProvider = 'PluginInfoProvider.lua',
}
