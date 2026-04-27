cmake_minimum_required(VERSION 3.16)

project(LogViewer VERSION 1.5.6 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_definitions(-DAPP_VERSION="${PROJECT_VERSION}")
add_definitions(-DGITHUB_REPO="boburbakhritdinov/log-viewer")

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Disable MACOSX_BUNDLE to avoid name conflict
set(QT_NO_SET_XCODE_BUNDLE_ATTRIBUTES ON)

if(APPLE)
    set(CMAKE_MACOSX_RPATH ON)
    set(CMAKE_SKIP_BUILD_RPATH FALSE)
    set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
    set(CMAKE_INSTALL_RPATH "@executable_path/../Frameworks")
    set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Quick Network Svg Gui)

# Set Qt policies for compatibility
if(POLICY QTP0004)
    cmake_policy(SET CMP0004 NEW)
endif()

# qt_standard_project_setup() was introduced in Qt 6.3.
# For compatibility with Qt 6.2 (Ubuntu 22.04), we set the necessary variables manually.
if(Qt6_VERSION VERSION_GREATER_EQUAL "6.3.0")
    qt_standard_project_setup()
else()
    set(CMAKE_INCLUDE_CURRENT_DIR ON)
    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)
    set(CMAKE_AUTOUIC ON)
endif()

qt_add_executable(LogViewer
    MACOSX_BUNDLE
    src/main.cpp
    src/GrafanaClient.cpp src/GrafanaClient.h
    src/LogModel.cpp src/LogModel.h
    src/ConfigManager.cpp src/ConfigManager.h
    src/UpdateManager.cpp src/UpdateManager.h
)

# Application Icon configuration
if(APPLE)
    set(MACOS_ICON src/resources/icon.icns)
    file(SIZE ${CMAKE_CURRENT_SOURCE_DIR}/${MACOS_ICON} ICON_SIZE)
    if(ICON_SIZE GREATER 100)
        set_source_files_properties(${MACOS_ICON} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
        target_sources(LogViewer PRIVATE ${MACOS_ICON})
        set_target_properties(LogViewer PROPERTIES MACOSX_BUNDLE_ICON_FILE icon.icns)
        message(STATUS "macOS Icon enabled")
    endif()
elseif(WIN32)
    set(WIN_ICON src/resources/icon.ico)
    if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${WIN_ICON})
        file(SIZE ${CMAKE_CURRENT_SOURCE_DIR}/${WIN_ICON} ICON_SIZE)
        if(ICON_SIZE GREATER 100)
            target_sources(LogViewer PRIVATE src/resources/resources.rc)
            message(STATUS "Windows Icon enabled")
        endif()
    endif()
endif()

qt_add_qml_module(LogViewer
    URI LogViewerApp
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES 
        src/qml/Main.qml
        src/qml/SearchHeader.qml
        src/qml/LogTableView.qml
        src/qml/DetailsArea.qml
        src/qml/Sidebar.qml
        src/qml/SettingsDialog.qml
        src/qml/UpdateDialog.qml
        src/qml/CalendarPopup.qml
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
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

if(Qt6_VERSION VERSION_GREATER_EQUAL "6.3.0" AND NOT ANDROID)
    qt_generate_deploy_qml_app_script(
        TARGET LogViewer
        OUTPUT_SCRIPT deploy_script
        NO_UNSUPPORTED_PLATFORM_ERROR
    )
    install(SCRIPT ${deploy_script})
endif()

# --- Linux Desktop Integration ---
if(UNIX AND NOT APPLE AND NOT ANDROID)
    set(DESKTOP_FILE_CONTENT
        "[Desktop Entry]\n"
        "Type=Application\n"
        "Name=LogViewer\n"
        "Exec=LogViewer\n"
        "Icon=LogViewer\n"
        "Categories=Development;\n"
        "Terminal=false\n"
    )
    file(WRITE ${CMAKE_BINARY_DIR}/log-viewer.desktop ${DESKTOP_FILE_CONTENT})
    install(FILES ${CMAKE_BINARY_DIR}/log-viewer.desktop DESTINATION share/applications)
    install(FILES src/resources/icon.png DESTINATION share/icons/hicolor/256x256/apps RENAME LogViewer.png)
endif()

# --- CPack Configuration ---
set(CPACK_PACKAGE_NAME "LogViewer")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_VENDOR "Bobur Bakhritdinov")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "A reactive log viewer built with Qt6")

if(APPLE)
    set(CPACK_GENERATOR "DragNDrop")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-macOS-Universal")
elseif(WIN32)
    set(CPACK_GENERATOR "NSIS")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-Windows-x64")
    set(CPACK_NSIS_MUI_ICON "${CMAKE_CURRENT_SOURCE_DIR}/src/resources/icon.ico")
    set(CPACK_NSIS_MUI_UNIICON "${CMAKE_CURRENT_SOURCE_DIR}/src/resources/icon.ico")
    set(CPACK_NSIS_INSTDIR_REGKEY "Software\\\\${CPACK_PACKAGE_VENDOR}\\\\${CPACK_PACKAGE_NAME}")
elseif(UNIX AND NOT APPLE AND NOT ANDROID)
    set(CPACK_GENERATOR "DEB")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-Linux-x86_64")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_VENDOR}")
    set(CPACK_DEBIAN_PACKAGE_DEPENDS "libqt6core6, libqt6gui6, libqt6quick6, libqt6network6")
    
    # Find qmake for linuxdeploy
    find_program(QT_QMAKE_EXECUTABLE NAMES qmake6 qmake PATHS /usr/lib/qt6/bin /usr/bin)

    # Custom AppImage target for Linux
    add_custom_target(appimage
        COMMAND mkdir -p ${CMAKE_BINARY_DIR}/AppDir
        COMMAND DESTDIR=${CMAKE_BINARY_DIR}/AppDir cmake --install ${CMAKE_BINARY_DIR} --prefix /usr
        COMMAND test -f linuxdeploy-x86_64.AppImage || (wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage && chmod +x linuxdeploy-x86_64.AppImage)
        COMMAND test -f linuxdeploy-plugin-qt-x86_64.AppImage || (wget -q https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage && chmod +x linuxdeploy-plugin-qt-x86_64.AppImage)
        COMMAND env QMAKE=${QT_QMAKE_EXECUTABLE} ./linuxdeploy-x86_64.AppImage --appdir ${CMAKE_BINARY_DIR}/AppDir --plugin qt --output appimage --desktop-file ${CMAKE_BINARY_DIR}/log-viewer.desktop --icon-file ${CMAKE_CURRENT_SOURCE_DIR}/src/resources/icon.png
        COMMAND mkdir -p ${CMAKE_SOURCE_DIR}/dist
        COMMAND mv LogViewer*.AppImage ${CMAKE_SOURCE_DIR}/dist/${CPACK_PACKAGE_NAME}-Linux.AppImage
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Generating AppImage..."
    )
endif()

include(CPack)
