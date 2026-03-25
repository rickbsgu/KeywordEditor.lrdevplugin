return {
    LrSdkVersion = 15.0,
    LrSdkMinimumVersion = 15.0,

    LrToolkitIdentifier = 'com.gb.keywordeditor',
    LrPluginName = 'GB Keyword Editor',

    LrLibraryMenuItems = {
        {
            title = 'Open GB Keyword Editor',
            file = 'OpenKeywordEditor.lua',
            enabledWhen = 'photosSelected',
        },
    },

    LrPluginInfoProvider = 'PluginInfoProvider.lua',
}
