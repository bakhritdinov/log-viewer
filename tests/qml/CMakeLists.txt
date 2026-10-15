# Qt Quick tests of the LogViewer.Ui components (tst_*.qml in this directory),
# run once per UI language.
find_package(Qt6 REQUIRED COMPONENTS QuickTest Quick QuickControls2)

qt_add_executable(tst_ui_shared tst_ui_shared.cpp)
target_link_libraries(tst_ui_shared PRIVATE Qt6::QuickTest logviewer_ui logviewer_uiplugin)
target_compile_definitions(tst_ui_shared PRIVATE QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")
set_target_properties(tst_ui_shared PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)

foreach(lang ru uz en)
    add_test(NAME tst_ui_shared_${lang} COMMAND tst_ui_shared)
    set_tests_properties(tst_ui_shared_${lang} PROPERTIES ENVIRONMENT
        "QT_QPA_PLATFORM=offscreen;QT_QUICK_CONTROLS_STYLE=Basic;LOGVIEWER_TEST_LANGUAGE=${lang}")
endforeach()
