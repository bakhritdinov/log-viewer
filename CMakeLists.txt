cmake_minimum_required(VERSION 3.16)

project(LogViewer VERSION 2.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_definitions(-DAPP_VERSION="${PROJECT_VERSION}")
add_definitions(-DGITHUB_REPO="boburbakhritdinov/log-viewer")

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

if(APPLE)
    set(CMAKE_MACOSX_RPATH ON)
    set(CMAKE_INSTALL_RPATH "@executable_path/../Frameworks")
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Quick Network Svg Gui)

# Set Qt policies for compatibility
if(POLICY QTP0004)
    cmake_policy(SET QTP0004 NEW)
endif()

# qt_standard_project_setup() was introduced in Qt 6.3.
# For compatibility with Qt 6.2 (Ubuntu 22.04), we set the necessary variables manually.
if(Qt6_VERSION VERSION_GREATER_EQUAL "6.3.0")
    qt_standard_project_setup()
else()
    set(CMAKE_INCLUDE_CURRENT_DIR ON)
endif()

qt_add_executable(LogViewer
    MACOSX_BUNDLE
    src/main.cpp
    src/GrafanaClient.cpp src/GrafanaClient.h
    src/LogModel.cpp src/LogModel.h
    src/ConfigManager.cpp src/ConfigManager.h
)

# Application Icon
if(APPLE)
    set(MACOS_ICON src/resources/icon.icns)
    set_source_files_properties(${MACOS_ICON} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    target_sources(LogViewer PRIVATE ${MACOS_ICON})
    set_target_properties(LogViewer PROPERTIES MACOSX_BUNDLE_ICON_FILE icon.icns)
elseif(WIN32)
    set(WIN_ICON src/resources/resources.rc)
    target_sources(LogViewer PRIVATE ${WIN_ICON})
endif()

set_source_files_properties(src/qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(LogViewer
    URI LogViewerApp
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        src/qml/Main.qml
        src/qml/AppContent.qml
        src/qml/SearchHeader.qml
        src/qml/LogTableView.qml
        src/qml/Sidebar.qml
        src/qml/SettingsDialog.qml
        src/qml/CalendarPopup.qml
        src/qml/Theme.qml
        src/qml/Card.qml
        src/qml/Badge.qml
        src/qml/Chip.qml
        src/qml/SectionHeader.qml
        src/qml/IconButton.qml
        src/qml/PageButton.qml
        src/qml/PrimaryButton.qml
        src/qml/SecondaryButton.qml
        src/qml/AppTextField.qml
        src/qml/TimeRangePicker.qml
    RESOURCES
        src/resources/icon.png
)

target_link_libraries(LogViewer PRIVATE 
    Qt6::Core 
    Qt6::Quick 
    Qt6::Network 
    Qt6::Svg
)

include(GNUInstallDirs)
install(TARGETS LogViewer
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# --- Автоматическое развертывание Qt ---
if(Qt6_VERSION VERSION_GREATER_EQUAL "6.3.0")
    set(deploy_args "-qmldir=${CMAKE_CURRENT_SOURCE_DIR}/src/qml")
    
    if(WIN32)
        list(APPEND deploy_args "--no-translations" "--compiler-runtime")
    endif()

    qt_generate_deploy_app_script(
        TARGET LogViewer
        OUTPUT_SCRIPT deploy_script
        DEPLOY_TOOL_OPTIONS ${deploy_args}
        NO_UNSUPPORTED_PLATFORM_ERROR
    )
    install(SCRIPT ${deploy_script})

    if(APPLE)
        install(CODE "
            execute_process(COMMAND codesign --force --deep --sign - \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/LogViewer.app\")
        ")
    endif()
endif()

# --- Linux Desktop Integration ---
if(UNIX AND NOT APPLE)
    set(DESKTOP_FILE_CONTENT
        "[Desktop Entry]\nType=Application\nName=LogViewer\nExec=LogViewer\nIcon=LogViewer\nCategories=Development;\nTerminal=false\n"
    )
    file(WRITE ${CMAKE_BINARY_DIR}/log-viewer.desktop ${DESKTOP_FILE_CONTENT})
    install(FILES ${CMAKE_BINARY_DIR}/log-viewer.desktop DESTINATION share/applications)
    install(FILES src/resources/icon.png DESTINATION share/icons/hicolor/256x256/apps RENAME LogViewer.png)
endif()

# --- CPack Configuration ---
set(CPACK_PACKAGE_NAME "LogViewer")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_VENDOR "Bobur Bakhritdinov")

if(APPLE)
    set(CPACK_GENERATOR "DragNDrop")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-macOS-Universal")
elseif(WIN32)
    set(CPACK_GENERATOR "NSIS;ZIP")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-Windows-x64")
elseif(UNIX AND NOT APPLE)
    set(CPACK_GENERATOR "DEB")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-Linux-x86_64")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_VENDOR}")
    set(CPACK_DEBIAN_PACKAGE_DEPENDS "libqt6core6, libqt6gui6, libqt6quick6, libqt6network6, libqt6svg6")
    
    find_program(QT_QMAKE_EXECUTABLE NAMES qmake6 qmake PATHS /usr/lib/qt6/bin /usr/bin)

    add_custom_target(appimage
        COMMAND mkdir -p ${CMAKE_BINARY_DIR}/AppDir
        COMMAND DESTDIR=${CMAKE_BINARY_DIR}/AppDir cmake --install ${CMAKE_BINARY_DIR} --prefix /usr
        COMMAND test -f linuxdeploy-x86_64.AppImage || (wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage && chmod +x linuxdeploy-x86_64.AppImage)
        COMMAND test -f linuxdeploy-plugin-qt-x86_64.AppImage || (wget -q https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage && chmod +x linuxdeploy-plugin-qt-x86_64.AppImage)
        COMMAND env QMAKE=${QT_QMAKE_EXECUTABLE} EXTRA_QT_PLUGINS=svg,iconengines QML_SOURCES_PATHS=${CMAKE_CURRENT_SOURCE_DIR}/src/qml ./linuxdeploy-x86_64.AppImage --appdir ${CMAKE_BINARY_DIR}/AppDir --plugin qt --output appimage --desktop-file ${CMAKE_BINARY_DIR}/log-viewer.desktop --icon-file ${CMAKE_CURRENT_SOURCE_DIR}/src/resources/icon.png
        COMMAND mkdir -p ${CMAKE_SOURCE_DIR}/dist
        COMMAND mv LogViewer*.AppImage ${CMAKE_SOURCE_DIR}/dist/${CPACK_PACKAGE_NAME}-Linux.AppImage
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
endif()

include(CPack)
