# logviewer_ui — LogViewer.Ui: design tokens, icons, primitives and composite
# components shared by every design. Components take data through properties
# and report intent through signals; designs wire them to LogViewer.App.
find_package(Qt6 6.8 REQUIRED COMPONENTS Quick QuickControls2 QuickShapes)

set_source_files_properties(Theme.qml Icons.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_library(logviewer_ui STATIC)
qt_add_qml_module(logviewer_ui
    URI LogViewer.Ui
    VERSION 1.0
    QML_FILES
        Theme.qml
        Icons.qml
        Icon.qml
        AppButton.qml
        IconButton.qml
        AppTextField.qml
        FilterChip.qml
        FilterChipBar.qml
        SegmentedControl.qml
        LevelBadge.qml
        EnvironmentBadge.qml
        SectionLabel.qml
        Surface.qml
        SearchBox.qml
        TimePresetGrid.qml
        AbsoluteRangeForm.qml
        HistogramView.qml
        LevelLegend.qml
        ErrorBanner.qml
        FieldRow.qml
        MessageView.qml
        FacetList.qml
        Sparkline.qml
        EmptyState.qml
        Clipboard.qml
        AppMenu.qml
        AppMenuItem.qml
        AppMenuSeparator.qml
        AppRadioButton.qml
        AppCheckBox.qml
        AppSwitch.qml
        ConfirmDialog.qml
    RESOURCES
        fonts/IBMPlexSans.ttf
        fonts/JetBrainsMono.ttf
    IMPORTS
        LogViewer.App
)
target_link_libraries(logviewer_ui PUBLIC Qt6::Quick Qt6::QuickControls2 Qt6::QuickShapes
                                          logviewer_app logviewer_appplugin)
