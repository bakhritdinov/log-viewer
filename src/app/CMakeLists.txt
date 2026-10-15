# logviewer_app — view-models exposed to QML as the LogViewer.App module.
# Presentation logic only: depends on Qt Qml (registration), never on Qt Quick.
find_package(Qt6 6.8 REQUIRED COMPONENTS Core Qml)

qt_add_library(logviewer_app STATIC)
qt_add_qml_module(logviewer_app
    URI LogViewer.App
    VERSION 1.0
    SOURCES
        AppServices.cpp AppServices.h
        ErrorInfo.cpp ErrorInfo.h
        EntryDetails.cpp EntryDetails.h
        MapListModel.cpp MapListModel.h
        LogListModel.cpp LogListModel.h
        Presenters.cpp Presenters.h
        Session.cpp Session.h
        FocusSession.cpp FocusSession.h
        LiveSession.cpp LiveSession.h
        EnvironmentEditor.cpp EnvironmentEditor.h
        Language.cpp Language.h
)
target_include_directories(logviewer_app PUBLIC ${PROJECT_SOURCE_DIR}/src)
target_link_libraries(logviewer_app PUBLIC logviewer_core Qt6::Qml)
