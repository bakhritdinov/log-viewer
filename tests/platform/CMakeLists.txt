# The platform layer's own pieces (the system keychain).
if(TARGET qt6keychain)
    logviewer_add_test(tst_platform_keychain
        SOURCES tst_keychain.cpp
                ${PROJECT_SOURCE_DIR}/src/platform/KeychainSecretStore.cpp
                ${PROJECT_SOURCE_DIR}/src/platform/KeychainSecretStore.h
        LIBS logviewer_core qt6keychain)
    target_include_directories(tst_platform_keychain PRIVATE ${PROJECT_SOURCE_DIR}/src/platform)
endif()
