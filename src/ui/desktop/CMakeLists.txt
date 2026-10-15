# logviewer_ui_desktop — LogViewer.Desktop: layout and navigation of the
# desktop design (mouse + keyboard, wide screens). Built when LOGVIEWER_UI=desktop.
find_package(Qt6 6.8 REQUIRED COMPONENTS Quick QuickControls2)

qt_add_library(logviewer_ui_desktop STATIC)
qt_add_qml_module(logviewer_ui_desktop
    URI LogViewer.Desktop
    VERSION 1.0
    QML_FILES
        Main.qml
        Kbd.qml
        TopBar.qml
        SourcePicker.qml
        TimeRangePopup.qml
        CalendarView.qml
        SharePopup.qml
        SavedQueriesPopup.qml
        SearchBar.qml
        LinkBanner.qml
        FieldsPanel.qml
        HistogramPanel.qml
        LogTable.qml
        PageFooter.qml
        ResultsView.qml
        PatternsView.qml
        FocusView.qml
        LiveView.qml
        DetailsPanel.qml
        StatusBar.qml
        SettingsDialog.qml
        ConnectionsPage.qml
        LanguagePage.qml
        AppearancePage.qml
        ShortcutsPage.qml
        AboutPage.qml
    IMPORTS
        LogViewer.App
        LogViewer.Ui
)
target_link_libraries(logviewer_ui_desktop PUBLIC Qt6::Quick Qt6::QuickControls2
                                                  logviewer_ui logviewer_uiplugin)

set(LOGVIEWER_UI_TARGET logviewer_ui_desktop PARENT_SCOPE)
set(LOGVIEWER_UI_URI LogViewer.Desktop PARENT_SCOPE)
set(LOGVIEWER_UI_PLUGIN_CLASS LogViewer_DesktopPlugin PARENT_SCOPE)
