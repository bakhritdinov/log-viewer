# logviewer_core — all application logic, UI-agnostic.
# Depends on Qt Core (and Network from the data layer on); never on Qt Qml/Quick.
find_package(Qt6 6.5 REQUIRED COMPONENTS Core)

add_library(logviewer_core STATIC
    domain/Level.cpp domain/Level.h
    domain/TimeRange.cpp domain/TimeRange.h
    query/Query.cpp query/Query.h
    query/LogsQL.cpp query/LogsQL.h
    query/Suggestions.cpp query/Suggestions.h
)
target_include_directories(logviewer_core PUBLIC ${PROJECT_SOURCE_DIR}/src)
target_compile_features(logviewer_core PUBLIC cxx_std_20)
target_link_libraries(logviewer_core PUBLIC Qt6::Core)
