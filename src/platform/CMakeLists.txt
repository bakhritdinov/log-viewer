# The application executable: platform services + the design chosen with
# LOGVIEWER_UI.
find_package(Qt6 6.8 REQUIRED COMPONENTS Gui Quick)

qt_add_executable(LogViewer MACOSX_BUNDLE main.cpp WebShell.cpp WebShell.h)

# Passwords in the system keychain (QtKeychain, built from source); the browser
# and phone builds keep them in the settings (SettingsSecretStore).
if(NOT EMSCRIPTEN AND NOT ANDROID AND NOT IOS)
    include(FetchContent)
    set(BUILD_WITH_QT6 ON CACHE BOOL "" FORCE)
    set(BUILD_TRANSLATIONS OFF CACHE BOOL "" FORCE)
    set(BUILD_TEST_APPLICATION OFF CACHE BOOL "" FORCE)
    set(BUILD_SHARED_LIBS OFF)
    # Its own install rules (library, headers, CMake files) go to a component
    # of their own that is never installed or packaged (CPACK_COMPONENTS_ALL).
    set(CMAKE_INSTALL_DEFAULT_COMPONENT_NAME qtkeychain-dev)
    FetchContent_Declare(qtkeychain
        GIT_REPOSITORY https://github.com/frankosterfeld/qtkeychain.git
        GIT_TAG 0.15.0
        GIT_SHALLOW ON)
    FetchContent_MakeAvailable(qtkeychain)
    unset(CMAKE_INSTALL_DEFAULT_COMPONENT_NAME)
    target_sources(LogViewer PRIVATE KeychainSecretStore.cpp KeychainSecretStore.h
                                     LinkHandler.cpp LinkHandler.h)
    target_link_libraries(LogViewer PRIVATE qt6keychain Qt6::Network)
    # The keychain, and logviewer:// links with one app at a time.
    target_compile_definitions(LogViewer PRIVATE LOGVIEWER_KEYCHAIN LOGVIEWER_DESKTOP_LINKS)
endif()
qt_add_resources(LogViewer "logviewer_icon"
    PREFIX /logviewer
    BASE ${PROJECT_SOURCE_DIR}/src/resources
    FILES ${PROJECT_SOURCE_DIR}/src/resources/icon.png)
target_link_libraries(LogViewer PRIVATE
    Qt6::Gui Qt6::Quick
    logviewer_app logviewer_appplugin
    logviewer_ui logviewer_uiplugin
    ${LOGVIEWER_UI_TARGET} ${LOGVIEWER_UI_TARGET}plugin)
target_compile_definitions(LogViewer PRIVATE
    LOGVIEWER_UI_MODULE="${LOGVIEWER_UI_URI}"
    LOGVIEWER_UI_PLUGIN=${LOGVIEWER_UI_PLUGIN_CLASS})
# The phone design starts with its own preference defaults (Preferences::Defaults).
if(LOGVIEWER_UI_URI STREQUAL "LogViewer.Mobile")
    target_compile_definitions(LogViewer PRIVATE LOGVIEWER_UI_PHONE)
endif()
# Must match setOrganizationDomain("logviewer.com") + setApplicationName("LogViewer")
# in main.cpp: QSettings, the Homebrew cask's `quit:` and `zap` paths and 2.x's
# settings all use this reverse-DNS identifier.
set_target_properties(LogViewer PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/macos/Info.plist.in
    MACOSX_BUNDLE_GUI_IDENTIFIER com.logviewer.LogViewer
    MACOSX_BUNDLE_BUNDLE_NAME LogViewer
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION})

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
qt_add_resources(LogViewer "logviewer_qml_imports"
    PREFIX /logviewer
    BASE ${CMAKE_CURRENT_BINARY_DIR}/qml_imports
    FILES ${CMAKE_CURRENT_BINARY_DIR}/qml_imports/imports.qml)

# The file icon: Windows takes it from the resource script, macOS from the
# bundle (sources: src/resources/icon.svg, rebuilt with tools/icons).
if(WIN32)
    target_sources(LogViewer PRIVATE ${PROJECT_SOURCE_DIR}/src/resources/resources.rc)
elseif(APPLE)
    set(LOGVIEWER_ICNS ${PROJECT_SOURCE_DIR}/src/resources/icon.icns)
    set_source_files_properties(${LOGVIEWER_ICNS} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    target_sources(LogViewer PRIVATE ${LOGVIEWER_ICNS})
    set_target_properties(LogViewer PROPERTIES MACOSX_BUNDLE_ICON_FILE icon.icns)
endif()

# The browser build is a PWA: our page instead of Qt's, the manifest, icons
# and a service worker next to the WebAssembly. The worker's cache name
# changes with every build, so the browser sees a new version.
if(EMSCRIPTEN)
    set(LOGVIEWER_WEB ${CMAKE_CURRENT_SOURCE_DIR}/wasm)
    set(LOGVIEWER_WEB_OUT $<TARGET_FILE_DIR:LogViewer>)
    add_custom_command(TARGET LogViewer POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${LOGVIEWER_WEB}/index.html ${LOGVIEWER_WEB}/manifest.webmanifest ${LOGVIEWER_WEB_OUT}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${LOGVIEWER_WEB_OUT}/icons
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${PROJECT_SOURCE_DIR}/src/resources/pwa/icon-192.png ${PROJECT_SOURCE_DIR}/src/resources/pwa/icon-512.png
                ${PROJECT_SOURCE_DIR}/src/resources/pwa/maskable-192.png ${PROJECT_SOURCE_DIR}/src/resources/pwa/maskable-512.png
                ${LOGVIEWER_WEB_OUT}/icons
        COMMAND ${CMAKE_COMMAND} -DIN=${LOGVIEWER_WEB}/sw.js.in -DOUT=${LOGVIEWER_WEB_OUT}/sw.js
                -DVERSION=${PROJECT_VERSION} -P ${LOGVIEWER_WEB}/stamp_sw.cmake
        VERBATIM)
endif()

# --- Install and Qt deployment (desktop) ---
if(NOT EMSCRIPTEN AND NOT ANDROID AND NOT IOS)
    include(GNUInstallDirs)
    install(TARGETS LogViewer
        BUNDLE DESTINATION . COMPONENT app
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT app)
    # windeployqt / macdeployqt copy the Qt libraries and the QML modules the
    # designs import (scanned from src/ui). On Linux CPack DEB relies on the
    # system Qt and the AppImage target runs linuxdeploy-qt instead.
    if(NOT (UNIX AND NOT APPLE))
        set(deploy_args "-qmldir=${PROJECT_SOURCE_DIR}/src/ui")
        if(WIN32)
            list(APPEND deploy_args "--no-translations" "--compiler-runtime")
        endif()
        qt_generate_deploy_app_script(
            TARGET LogViewer
            OUTPUT_SCRIPT deploy_script
            DEPLOY_TOOL_OPTIONS ${deploy_args}
            NO_UNSUPPORTED_PLATFORM_ERROR)
        install(SCRIPT ${deploy_script} COMPONENT app)
    endif()
endif()
