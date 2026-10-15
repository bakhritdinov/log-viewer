# Test suite. Enabled with -DLOGVIEWER_TESTS=ON, run with `ctest --test-dir <build>`.
find_package(Qt6 REQUIRED COMPONENTS Test)

set(LOGVIEWER_TESTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
set(LOGVIEWER_FIXTURES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/fixtures")

# logviewer_add_test(<name> SOURCES <files...> LIBS <targets...>)
# One executable per test case class; fixtures are reachable via LOGVIEWER_FIXTURES_DIR.
function(logviewer_add_test name)
    cmake_parse_arguments(ARG "" "" "SOURCES;LIBS" ${ARGN})
    qt_add_executable(${name} ${ARG_SOURCES})
    target_link_libraries(${name} PRIVATE Qt6::Test ${ARG_LIBS})
    target_include_directories(${name} PRIVATE ${LOGVIEWER_TESTS_DIR})
    target_compile_definitions(${name} PRIVATE
        LOGVIEWER_FIXTURES_DIR="${LOGVIEWER_FIXTURES_DIR}")
    set_target_properties(${name} PROPERTIES MACOSX_BUNDLE OFF WIN32_EXECUTABLE OFF)
    add_test(NAME ${name} COMMAND ${name})
    # Headless: no window system needed for core/app tests.
    set_tests_properties(${name} PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
endfunction()

add_subdirectory(characterization)
add_subdirectory(core)
add_subdirectory(app)
add_subdirectory(qml)
if(TARGET logviewer_ui_desktop)
    add_subdirectory(qml_desktop)
endif()
if(TARGET logviewer_ui_mobile)
    add_subdirectory(qml_mobile)
endif()
