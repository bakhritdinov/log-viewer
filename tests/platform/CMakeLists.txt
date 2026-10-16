# The platform layer's own pieces (the system keychain).
if(TARGET qt6keychain)
    logviewer_add_test(tst_platform_keychain
        SOURCES tst_keychain.cpp
                ${PROJECT_SOURCE_DIR}/src/platform/KeychainSecretStore.cpp
                ${PROJECT_SOURCE_DIR}/src/platform/KeychainSecretStore.h
        LIBS logviewer_core qt6keychain)
    target_include_directories(tst_platform_keychain PRIVATE ${PROJECT_SOURCE_DIR}/src/platform)
endif()

# logviewer:// links and one app at a time (desktop).
if(NOT EMSCRIPTEN AND NOT ANDROID AND NOT IOS)
    find_package(Qt6 REQUIRED COMPONENTS Network Gui)
    logviewer_add_test(tst_platform_links
        SOURCES tst_links.cpp
                ${PROJECT_SOURCE_DIR}/src/platform/LinkHandler.cpp
                ${PROJECT_SOURCE_DIR}/src/platform/LinkHandler.h
        LIBS logviewer_app Qt6::Network Qt6::Gui)
    target_include_directories(tst_platform_links PRIVATE ${PROJECT_SOURCE_DIR}/src/platform)
endif()
