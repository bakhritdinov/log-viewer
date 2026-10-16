cmake_minimum_required(VERSION 3.16)

project(LogViewer VERSION 2.8.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_definitions(-DAPP_VERSION="${PROJECT_VERSION}")
add_definitions(-DGITHUB_REPO="bakhritdinov/log-viewer")

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

if(APPLE)
    set(CMAKE_MACOSX_RPATH ON)
    set(CMAKE_INSTALL_RPATH "@executable_path/../Frameworks")
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Quick Network Gui)

# Set Qt policies for compatibility
# QML modules live under qrc:/qt/qml (the default import path).
qt_policy(SET QTP0001 NEW)
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

# --- The app: core → app (view-models) → ui (shared + one design) → platform ---
# QML modules are laid out as <build>/qml/<URI path> so qmllint and tooling find them.
set(QT_QML_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml)

add_subdirectory(src/core)
add_subdirectory(src/app)
add_subdirectory(src/ui/shared)

# The design is chosen at build time: one of src/ui/<design> is compiled in.
if(EMSCRIPTEN OR ANDROID OR IOS)
    set(_logviewer_default_ui mobile)
else()
    set(_logviewer_default_ui desktop)
endif()
set(LOGVIEWER_UI "${_logviewer_default_ui}" CACHE STRING "UI design to build: desktop or mobile")
set_property(CACHE LOGVIEWER_UI PROPERTY STRINGS desktop mobile)
if(EXISTS ${PROJECT_SOURCE_DIR}/src/ui/${LOGVIEWER_UI}/CMakeLists.txt)
    add_subdirectory(src/ui/${LOGVIEWER_UI})   # sets LOGVIEWER_UI_TARGET/_URI/_PLUGIN_CLASS
    add_subdirectory(src/platform)
else()
    message(WARNING "LOGVIEWER_UI=${LOGVIEWER_UI}: design not implemented yet, the new app is not built")
endif()

# --- Translations: Russian (default), Uzbek (Latin), English (source) ---------
# `cmake --build <dir> --target update_translations` runs lupdate over the new
# code; the .ts files are compiled to .qm and embedded under :/i18n.
find_package(Qt6 6.8 REQUIRED COMPONENTS LinguistTools)
# Both designs are scanned whichever is built: with -no-obsolete, a design
# left out would lose its translations.
file(GLOB _logviewer_design_qml CONFIGURE_DEPENDS
     ${PROJECT_SOURCE_DIR}/src/ui/desktop/*.qml ${PROJECT_SOURCE_DIR}/src/ui/mobile/*.qml)
qt_add_translations(logviewer_app
    TS_FILES i18n/logviewer_ru.ts i18n/logviewer_uz.ts
    PLURALS_TS_FILE i18n/logviewer_en.ts
    SOURCE_TARGETS logviewer_app logviewer_ui ${LOGVIEWER_UI_TARGET}
    SOURCES ${_logviewer_design_qml}
    RESOURCE_PREFIX /i18n
    LUPDATE_OPTIONS -no-obsolete -locations none)
# lupdate silently skips a QML file it cannot parse and -no-obsolete then
# drops its translations: build (and so compile every QML file) first.
if(TARGET update_translations)
    add_dependencies(update_translations logviewer_app logviewer_ui ${LOGVIEWER_UI_TARGET})
endif()

# --- Tests ---
option(LOGVIEWER_TESTS "Build the test suite (run with ctest)" OFF)
if(LOGVIEWER_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

# --- Linux Desktop Integration ---
if(UNIX AND NOT APPLE)
    set(DESKTOP_FILE_CONTENT
        "[Desktop Entry]\nType=Application\nName=LogViewer\nComment=Logs from Grafana (VictoriaLogs / Loki)\nExec=LogViewer %u\nIcon=LogViewer\nCategories=Development;\nTerminal=false\nMimeType=x-scheme-handler/logviewer;\n"
    )
    file(WRITE ${CMAKE_BINARY_DIR}/log-viewer.desktop ${DESKTOP_FILE_CONTENT})
    install(FILES ${CMAKE_BINARY_DIR}/log-viewer.desktop DESTINATION share/applications COMPONENT app)
    install(FILES src/resources/icon.png DESTINATION share/icons/hicolor/256x256/apps RENAME LogViewer.png COMPONENT app)
endif()

# --- CPack Configuration ---
set(CPACK_PACKAGE_NAME "LogViewer")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_VENDOR "Bobur Bakhritdinov")

# Without these, CPack defaults to "<name> <version>" — every release would
# install to C:\Program Files\LogViewer 2.0.0\ and register a separate
# Add/Remove Programs entry, leaving duplicates after upgrades.
set(CPACK_PACKAGE_INSTALL_DIRECTORY "${CPACK_PACKAGE_NAME}")
set(CPACK_PACKAGE_INSTALL_REGISTRY_KEY "${CPACK_PACKAGE_NAME}")
# Only the app: dependencies built from source (QtKeychain) install their
# development files into components of their own.
set(CPACK_COMPONENTS_ALL app)
set(CPACK_COMPONENTS_GROUPING ALL_COMPONENTS_IN_ONE)
set(CPACK_ARCHIVE_COMPONENT_INSTALL ON)
set(CPACK_COMPONENT_APP_DISPLAY_NAME "LogViewer")
set(CPACK_COMPONENT_APP_REQUIRED ON)

if(APPLE)
    set(CPACK_GENERATOR "DragNDrop")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-macOS-Universal")
elseif(WIN32)
    set(CPACK_GENERATOR "NSIS;ZIP")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-Windows-x64")
    # NSIS-specific: visible name in installer UI, and the brand under which
    # the uninstaller registers itself. Both must be version-free for upgrades
    # to overwrite cleanly rather than accumulating ghost entries.
    set(CPACK_NSIS_PACKAGE_NAME "${CPACK_PACKAGE_NAME}")
    set(CPACK_NSIS_DISPLAY_NAME "${CPACK_PACKAGE_NAME}")
    # The app registers logviewer:// for the user at start; the uninstaller
    # takes it away again.
    set(CPACK_NSIS_EXTRA_UNINSTALL_COMMANDS "DeleteRegKey HKCU 'Software\\\\Classes\\\\logviewer'")
elseif(UNIX AND NOT APPLE)
    # Linux ships as an AppImage that carries its Qt (the distributions' Qt is
    # older than the 6.8 the app needs); `cmake --build <dir> --target appimage`.
    set(CPACK_GENERATOR "TGZ")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-Linux-x86_64")
    find_program(QT_QMAKE_EXECUTABLE NAMES qmake6 qmake HINTS ${QT6_INSTALL_PREFIX}/${QT6_INSTALL_BINS} PATHS /usr/lib/qt6/bin /usr/bin)

    add_custom_target(appimage
        COMMAND mkdir -p ${CMAKE_BINARY_DIR}/AppDir
        COMMAND DESTDIR=${CMAKE_BINARY_DIR}/AppDir cmake --install ${CMAKE_BINARY_DIR} --prefix /usr --component app
        COMMAND test -f linuxdeploy-x86_64.AppImage || (wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage && chmod +x linuxdeploy-x86_64.AppImage)
        COMMAND test -f linuxdeploy-plugin-qt-x86_64.AppImage || (wget -q https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage && chmod +x linuxdeploy-plugin-qt-x86_64.AppImage)
        COMMAND env QMAKE=${QT_QMAKE_EXECUTABLE} EXTRA_QT_PLUGINS=iconengines QML_SOURCES_PATHS=${CMAKE_CURRENT_SOURCE_DIR}/src/ui ./linuxdeploy-x86_64.AppImage --appdir ${CMAKE_BINARY_DIR}/AppDir --plugin qt --output appimage --desktop-file ${CMAKE_BINARY_DIR}/log-viewer.desktop --icon-file ${CMAKE_CURRENT_SOURCE_DIR}/src/resources/icon.png
        COMMAND mkdir -p ${CMAKE_SOURCE_DIR}/dist
        COMMAND mv LogViewer*.AppImage ${CMAKE_SOURCE_DIR}/dist/${CPACK_PACKAGE_NAME}-Linux.AppImage
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
endif()

include(CPack)
