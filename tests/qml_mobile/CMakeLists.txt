# Scenario tests of the mobile design over a fake Grafana (one executable,
# one ctest per scenario file), in a phone-sized window.
find_package(Qt6 REQUIRED COMPONENTS QuickTest Quick QuickControls2)

qt_add_executable(tst_ui_mobile tst_ui_mobile.cpp ${LOGVIEWER_TESTS_DIR}/support/UiHarness.h)
target_link_libraries(tst_ui_mobile PRIVATE Qt6::QuickTest
    logviewer_ui_mobile logviewer_ui_mobileplugin logviewer_ui logviewer_uiplugin
    logviewer_app logviewer_appplugin)
target_include_directories(tst_ui_mobile PRIVATE ${LOGVIEWER_TESTS_DIR})
target_compile_definitions(tst_ui_mobile PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
    LOGVIEWER_FIXTURES_DIR="${LOGVIEWER_FIXTURES_DIR}")
set_target_properties(tst_ui_mobile PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)

foreach(scenario first_run feed)
    add_test(NAME tst_ui_mobile_${scenario}
             COMMAND tst_ui_mobile -input ${CMAKE_CURRENT_SOURCE_DIR}/tst_${scenario}.qml)
    set_tests_properties(tst_ui_mobile_${scenario} PROPERTIES ENVIRONMENT
        "QT_QPA_PLATFORM=offscreen;QT_QUICK_CONTROLS_STYLE=Basic;LOGVIEWER_TEST_SCENARIO=${scenario}")
endforeach()
