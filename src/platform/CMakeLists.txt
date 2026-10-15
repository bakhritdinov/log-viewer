# The application executable: platform services + the design chosen with
# LOGVIEWER_UI. Named logviewer-next until the legacy app is removed (stage 8).
find_package(Qt6 6.8 REQUIRED COMPONENTS Gui Quick)

qt_add_executable(logviewer-next MACOSX_BUNDLE main.cpp)
qt_add_resources(logviewer-next "logviewer_icon"
    PREFIX /logviewer
    BASE ${PROJECT_SOURCE_DIR}/src/resources
    FILES ${PROJECT_SOURCE_DIR}/src/resources/icon.png)
target_link_libraries(logviewer-next PRIVATE
    Qt6::Gui Qt6::Quick
    logviewer_app logviewer_appplugin
    logviewer_ui logviewer_uiplugin
    ${LOGVIEWER_UI_TARGET} ${LOGVIEWER_UI_TARGET}plugin)
target_compile_definitions(logviewer-next PRIVATE
    LOGVIEWER_UI_MODULE="${LOGVIEWER_UI_URI}"
    LOGVIEWER_UI_PLUGIN=${LOGVIEWER_UI_PLUGIN_CLASS})
set_target_properties(logviewer-next PROPERTIES
    OUTPUT_NAME "LogViewerNext"
    MACOSX_BUNDLE_GUI_IDENTIFIER com.logviewer.LogViewerNext)
