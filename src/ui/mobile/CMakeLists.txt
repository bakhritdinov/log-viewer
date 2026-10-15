# logviewer_ui_mobile — LogViewer.Mobile: layout and navigation of the mobile
# design (touch, one column, bottom navigation and sheets). Built when
# LOGVIEWER_UI=mobile: WASM/PWA, Android, iOS — and on desktop for development.
find_package(Qt6 6.8 REQUIRED COMPONENTS Quick QuickControls2)

qt_add_library(logviewer_ui_mobile STATIC)
qt_add_qml_module(logviewer_ui_mobile
    URI LogViewer.Mobile
    VERSION 1.0
    QML_FILES
        Main.qml
        AppBar.qml
        BottomNav.qml
        BottomSheet.qml
        Snackbar.qml
        LogCard.qml
        LogsPage.qml
        ChartPage.qml
        SettingsPage.qml
        SetupGuide.qml
        SearchScreen.qml
        SaveQuerySheet.qml
        SavedQuerySheet.qml
        ShareSheet.qml
    IMPORTS
        LogViewer.App
        LogViewer.Ui
)
target_link_libraries(logviewer_ui_mobile PUBLIC Qt6::Quick Qt6::QuickControls2
                                                 logviewer_ui logviewer_uiplugin)

set(LOGVIEWER_UI_TARGET logviewer_ui_mobile PARENT_SCOPE)
set(LOGVIEWER_UI_URI LogViewer.Mobile PARENT_SCOPE)
set(LOGVIEWER_UI_PLUGIN_CLASS LogViewer_MobilePlugin PARENT_SCOPE)
