# logviewer_core — all application logic, UI-agnostic.
# Depends on Qt Core and Network only; never on Qt Qml/Quick.
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Network)

add_library(logviewer_core STATIC
    domain/Level.cpp domain/Level.h
    domain/TimeRange.cpp domain/TimeRange.h
    domain/LogEntry.h
    data/Http.h
    data/QtHttpClient.cpp data/QtHttpClient.h
    data/RetryingHttpClient.cpp data/RetryingHttpClient.h
    data/GrafanaApi.cpp data/GrafanaApi.h
    data/ErrorClassifier.cpp data/ErrorClassifier.h
    data/LabelDiscovery.cpp data/LabelDiscovery.h
    data/ParseExecutor.cpp data/ParseExecutor.h
    features/LogStore.cpp features/LogStore.h
    features/Analysis.cpp features/Analysis.h
    features/ChainedLoader.cpp features/ChainedLoader.h
    features/LiveTail.cpp features/LiveTail.h
    features/Focus.cpp features/Focus.h
    features/ShareLink.cpp features/ShareLink.h
    storage/KeyValueStore.cpp storage/KeyValueStore.h
    storage/SecretStore.cpp storage/SecretStore.h
    storage/Environments.cpp storage/Environments.h
    storage/UserData.cpp storage/UserData.h
    storage/Migration.cpp storage/Migration.h
    query/Query.cpp query/Query.h
    query/LogsQL.cpp query/LogsQL.h
    query/Suggestions.cpp query/Suggestions.h
)
target_include_directories(logviewer_core PUBLIC ${PROJECT_SOURCE_DIR}/src)
target_compile_features(logviewer_core PUBLIC cxx_std_20)
target_link_libraries(logviewer_core PUBLIC Qt6::Core Qt6::Network)
set_target_properties(logviewer_core PROPERTIES AUTOMOC ON)
