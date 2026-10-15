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

# Static Qt (WebAssembly, iOS): Qt links in the QML modules qmlimportscanner
# finds in this target's resources and, through their qmldir files, everything
# they import (Controls, Layouts, Shapes…). The designs' QML lives in the UI
# libraries, so a one-line file importing the chosen design starts the scan.
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/qml_imports/imports.qml
     "import QtQuick
import LogViewer.App
import LogViewer.Ui
import ${LOGVIEWER_UI_URI}
Item {}
")
qt_add_resources(logviewer-next "logviewer_qml_imports"
    PREFIX /logviewer
    BASE ${CMAKE_CURRENT_BINARY_DIR}/qml_imports
    FILES ${CMAKE_CURRENT_BINARY_DIR}/qml_imports/imports.qml)

# The file icon: Windows takes it from the resource script, macOS from the
# bundle (sources: src/resources/icon.svg, rebuilt with tools/icons).
if(WIN32)
    target_sources(logviewer-next PRIVATE ${PROJECT_SOURCE_DIR}/src/resources/resources.rc)
elseif(APPLE)
    set(LOGVIEWER_ICNS ${PROJECT_SOURCE_DIR}/src/resources/icon.icns)
    set_source_files_properties(${LOGVIEWER_ICNS} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    target_sources(logviewer-next PRIVATE ${LOGVIEWER_ICNS})
    set_target_properties(logviewer-next PROPERTIES MACOSX_BUNDLE_ICON_FILE icon.icns)
endif()
