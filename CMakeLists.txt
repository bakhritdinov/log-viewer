cmake_minimum_required(VERSION 3.16)

project(LogViewer VERSION 2.7.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_definitions(-DAPP_VERSION="${PROJECT_VERSION}")
add_definitions(-DGITHUB_REPO="bakhritdinov/log-viewer")

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

if(APPLE)
    set(CMAKE_MACOSX_RPATH ON)
    set(CMAKE_INSTALL_RPATH "@executable_path/../Frameworks")
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Quick Network Svg Gui Sql Concurrent)

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

# --- Module static libraries -------------------------------------------------
# Code is grouped by concern: logs (Grafana/Loki) and ecotone (DLQ from Postgres).
# Shared QML lives in src/common/qml and is bundled into the executable's QML
# module below, so no separate "common" static library is needed at the C++ level.

add_library(LogViewerLogs STATIC
    src/logs/GrafanaClient.cpp src/logs/GrafanaClient.h
    src/logs/LogModel.cpp src/logs/LogModel.h
)
target_include_directories(LogViewerLogs PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(LogViewerLogs PUBLIC Qt6::Core Qt6::Network)

add_library(LogViewerEcotone STATIC
    src/ecotone/EcotoneClient.cpp src/ecotone/EcotoneClient.h
    src/ecotone/ErrorMessagesModel.cpp src/ecotone/ErrorMessagesModel.h
    src/ecotone/EcotoneConfigManager.cpp src/ecotone/EcotoneConfigManager.h
    src/ecotone/FifoChannels.cpp src/ecotone/FifoChannels.h
)
target_include_directories(LogViewerEcotone PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_link_libraries(LogViewerEcotone PUBLIC Qt6::Core Qt6::Sql Qt6::Concurrent)

qt_add_executable(LogViewer
    MACOSX_BUNDLE
    src/main.cpp
    src/ConfigManager.cpp src/ConfigManager.h
    src/UpdateChecker.cpp src/UpdateChecker.h
)
target_include_directories(LogViewer PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

# Application Icon
if(APPLE)
    set(MACOS_ICON src/resources/icon.icns)
    set_source_files_properties(${MACOS_ICON} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    target_sources(LogViewer PRIVATE ${MACOS_ICON})
    set_target_properties(LogViewer PROPERTIES
        MACOSX_BUNDLE_ICON_FILE icon.icns
        # Must match setOrganizationDomain("logviewer.com") + setApplicationName("LogViewer")
        # in main.cpp so that QSettings, Cask `quit:` AppleEvent and zap paths
        # all converge on the same reverse-DNS identifier.
        MACOSX_BUNDLE_GUI_IDENTIFIER com.logviewer.LogViewer
    )
elseif(WIN32)
    set(WIN_ICON src/resources/resources.rc)
    target_sources(LogViewer PRIVATE ${WIN_ICON})
endif()

# Theme.qml не указываем как QML_FILES + QT_QML_SINGLETON_TYPE: на Qt 6.2
# (Ubuntu 22.04) source-file property неполностью поддерживается, qmldir
# не содержит строку "singleton Theme ..." и Theme.* резолвится в undefined.
# Файл идёт через RESOURCES (попадает в qrc), а singleton регистрируется
# вручную через qmlRegisterSingletonType() в main.cpp.

qt_add_qml_module(LogViewer
    URI LogViewerApp
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        # Logs module — Grafana/Loki UI
        src/logs/qml/Main.qml
        src/logs/qml/AppContent.qml
        src/logs/qml/SearchHeader.qml
        src/logs/qml/LogTableView.qml
        src/logs/qml/Sidebar.qml
        src/logs/qml/SettingsDialog.qml
        src/logs/qml/CalendarPopup.qml
        src/logs/qml/TimeRangePicker.qml
        src/logs/qml/SkeletonRow.qml
        src/logs/qml/PageBar.qml
        src/logs/qml/PageButton.qml
        src/logs/qml/HistogramChart.qml
        src/logs/qml/UpdateBanner.qml
        # Common module — shared UI primitives
        src/common/qml/Card.qml
        src/common/qml/Badge.qml
        src/common/qml/Chip.qml
        src/common/qml/SectionHeader.qml
        src/common/qml/IconButton.qml
        src/common/qml/PrimaryButton.qml
        src/common/qml/SecondaryButton.qml
        src/common/qml/AppTextField.qml
        src/common/qml/StatusPill.qml
        # Ecotone module — DLQ viewer
        src/ecotone/qml/EcotoneWindow.qml
        src/ecotone/qml/EcotoneTableView.qml
        src/ecotone/qml/EcotoneDetailsPane.qml
        src/ecotone/qml/EcotoneSettingsDialog.qml
        src/ecotone/qml/ReplayConfirmDialog.qml
        src/ecotone/qml/ReplayFifoGroupDialog.qml
        src/ecotone/qml/ReplayHistoryDialog.qml
        src/ecotone/qml/MessageDetailsWindow.qml
    RESOURCES
        src/resources/icon.png
        src/common/qml/Theme.qml
)

target_link_libraries(LogViewer PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Network
    Qt6::Svg
    LogViewerLogs
    LogViewerEcotone
)

include(GNUInstallDirs)
install(TARGETS LogViewer
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# --- Автоматическое развертывание Qt ---
# qt_generate_deploy_app_script with OUTPUT_SCRIPT / DEPLOY_TOOL_OPTIONS landed in Qt 6.5.
# Ubuntu noble ships Qt 6.4.2 which knows the function under a different signature
# (FILENAME_VARIABLE, no DEPLOY_TOOL_OPTIONS) and rejects our call -- so PPA builds
# on noble were failing with "Unexpected arguments". On Linux the block is unnecessary
# anyway: CPack DEB uses install(TARGETS ...) and the AppImage target uses linuxdeploy-qt.
if(NOT (UNIX AND NOT APPLE) AND Qt6_VERSION VERSION_GREATER_EQUAL "6.5.0")
    set(deploy_args
        "-qmldir=${CMAKE_CURRENT_SOURCE_DIR}/src/logs/qml"
        "-qmldir=${CMAKE_CURRENT_SOURCE_DIR}/src/common/qml"
        "-qmldir=${CMAKE_CURRENT_SOURCE_DIR}/src/ecotone/qml"
    )

    if(WIN32)
        # Ecotone talks to PostgreSQL via the QPSQL driver. windeployqt does not
        # bundle sql drivers unless asked, so without this the released build
        # fails with "Driver not loaded". (macOS handled separately below.)
        list(APPEND deploy_args "--no-translations" "--compiler-runtime" "-extra-plugins=sqldrivers")
    endif()

    qt_generate_deploy_app_script(
        TARGET LogViewer
        OUTPUT_SCRIPT deploy_script
        DEPLOY_TOOL_OPTIONS ${deploy_args}
        NO_UNSUPPORTED_PLATFORM_ERROR
    )
    install(SCRIPT ${deploy_script})

    if(APPLE)
        # macdeployqt has no -extra-plugins flag and its -appstore-compliant mode
        # (set by the Qt deploy script) explicitly blacklists qsqlpsql, so the
        # QPSQL driver is never bundled -> "Driver not loaded". Copy the plugin in
        # ourselves, then re-run macdeployqt with -executable so it pulls in libpq
        # and its full dependency chain (libssl/libcrypto/libgssapi_krb5/...) and
        # rewrites the install_names. Finally re-sign the bundle.
        find_program(MACDEPLOYQT_EXECUTABLE macdeployqt
            HINTS "${QT6_INSTALL_PREFIX}/bin" "${Qt6_DIR}/../../../bin" REQUIRED)
        find_file(QPSQL_PLUGIN_PATH libqsqlpsql.dylib
            HINTS
                "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_PLUGINS}/sqldrivers"
                "${QT6_INSTALL_PREFIX}/plugins/sqldrivers"
                "${QT6_INSTALL_PREFIX}/share/qt/plugins/sqldrivers"
            REQUIRED)

        install(CODE "
            set(_bundle \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/LogViewer.app\")
            set(_dst \"\${_bundle}/Contents/PlugIns/sqldrivers/libqsqlpsql.dylib\")
            # Resolve symlinks (Homebrew ships the plugin as a symlink into Cellar)
            # so we copy the real Mach-O, not a link that breaks inside the bundle.
            get_filename_component(_src \"${QPSQL_PLUGIN_PATH}\" REALPATH)
            file(MAKE_DIRECTORY \"\${_bundle}/Contents/PlugIns/sqldrivers\")
            execute_process(COMMAND \${CMAKE_COMMAND} -E copy \"\${_src}\" \"\${_dst}\")
            execute_process(COMMAND \"${MACDEPLOYQT_EXECUTABLE}\" \"\${_bundle}\" -executable=\"\${_dst}\" -no-strip)
            execute_process(COMMAND codesign --force --deep --sign - \"\${_bundle}\")
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

# Without these, CPack defaults to "<name> <version>" — every release would
# install to C:\Program Files\LogViewer 2.0.0\ and register a separate
# Add/Remove Programs entry, leaving duplicates after upgrades.
set(CPACK_PACKAGE_INSTALL_DIRECTORY "${CPACK_PACKAGE_NAME}")
set(CPACK_PACKAGE_INSTALL_REGISTRY_KEY "${CPACK_PACKAGE_NAME}")

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
elseif(UNIX AND NOT APPLE)
    set(CPACK_GENERATOR "DEB")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-Linux-x86_64")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_VENDOR}")
    # Runtime deps for a Qt 6 Quick app on Ubuntu. Beyond the obvious Qt libs we
    # must list:
    #   * libqt6quickcontrols2-6 — C++ backing for Controls (Dialog/Popup/Menu).
    #   * qml6-module-* — QML imports loaded by name at runtime; the linker
    #     can't see them, so dpkg-shlibdeps won't add them.
    #   * libxcb-cursor0 — Qt 6.5+ requires it for the xcb platform plugin but
    #     libqt6gui6 still does not depend on it, so a fresh Ubuntu install
    #     fails with `Could not find the Qt platform plugin "xcb"`.
    #   * libxkbcommon-x11-0 — keyboard layout under X11.
    #   * qt6-qpa-plugins — bundles the xcb (and offscreen/minimal) plugins.
    #   * qt6-wayland — wayland session fallback so the app launches under
    #     GNOME/KDE Wayland without forcing XWayland.
    set(CPACK_DEBIAN_PACKAGE_DEPENDS
        "libqt6core6, libqt6gui6, libqt6qml6, libqt6quick6, libqt6quickcontrols2-6, libqt6network6, libqt6svg6, \
libqt6sql6-psql, libqt6concurrent6, \
qt6-qpa-plugins, qt6-wayland, \
qml6-module-qtqml, qml6-module-qtqml-workerscript, qml6-module-qtquick, qml6-module-qtquick-controls, \
qml6-module-qtquick-layouts, qml6-module-qtquick-templates, qml6-module-qtquick-window, \
libxcb-cursor0, libxkbcommon-x11-0, libgl1, libegl1, \
fontconfig, libfontconfig1")
    
    find_program(QT_QMAKE_EXECUTABLE NAMES qmake6 qmake PATHS /usr/lib/qt6/bin /usr/bin)

    add_custom_target(appimage
        COMMAND mkdir -p ${CMAKE_BINARY_DIR}/AppDir
        COMMAND DESTDIR=${CMAKE_BINARY_DIR}/AppDir cmake --install ${CMAKE_BINARY_DIR} --prefix /usr
        COMMAND test -f linuxdeploy-x86_64.AppImage || (wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage && chmod +x linuxdeploy-x86_64.AppImage)
        COMMAND test -f linuxdeploy-plugin-qt-x86_64.AppImage || (wget -q https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage && chmod +x linuxdeploy-plugin-qt-x86_64.AppImage)
        COMMAND env QMAKE=${QT_QMAKE_EXECUTABLE} EXTRA_QT_PLUGINS=svg,iconengines,sqldrivers QML_SOURCES_PATHS=${CMAKE_CURRENT_SOURCE_DIR}/src/logs/qml:${CMAKE_CURRENT_SOURCE_DIR}/src/common/qml:${CMAKE_CURRENT_SOURCE_DIR}/src/ecotone/qml ./linuxdeploy-x86_64.AppImage --appdir ${CMAKE_BINARY_DIR}/AppDir --plugin qt --output appimage --desktop-file ${CMAKE_BINARY_DIR}/log-viewer.desktop --icon-file ${CMAKE_CURRENT_SOURCE_DIR}/src/resources/icon.png
        COMMAND mkdir -p ${CMAKE_SOURCE_DIR}/dist
        COMMAND mv LogViewer*.AppImage ${CMAKE_SOURCE_DIR}/dist/${CPACK_PACKAGE_NAME}-Linux.AppImage
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )
endif()

include(CPack)
