# Scenario tests of the desktop design over a fake Grafana (one executable,
# one ctest per scenario file).
find_package(Qt6 REQUIRED COMPONENTS QuickTest Quick QuickControls2)

qt_add_executable(tst_ui_desktop tst_ui_desktop.cpp ${LOGVIEWER_TESTS_DIR}/support/UiHarness.h)
target_link_libraries(tst_ui_desktop PRIVATE Qt6::QuickTest
    logviewer_ui_desktop logviewer_ui_desktopplugin logviewer_ui logviewer_uiplugin
    logviewer_app logviewer_appplugin)
target_include_directories(tst_ui_desktop PRIVATE ${LOGVIEWER_TESTS_DIR})
target_compile_definitions(tst_ui_desktop PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
    LOGVIEWER_FIXTURES_DIR="${LOGVIEWER_FIXTURES_DIR}")
set_target_properties(tst_ui_desktop PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)

foreach(scenario first_run search)
    add_test(NAME tst_ui_desktop_${scenario}
             COMMAND tst_ui_desktop -input ${CMAKE_CURRENT_SOURCE_DIR}/tst_${scenario}.qml)
    set_tests_properties(tst_ui_desktop_${scenario} PROPERTIES ENVIRONMENT
        "QT_QPA_PLATFORM=offscreen;QT_QUICK_CONTROLS_STYLE=Basic;LOGVIEWER_TEST_SCENARIO=${scenario}")
endforeach()
