#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>
#include <QStringConverter>
#include <QIcon>
#include "GrafanaClient.h"
#include "LogModel.h"
#include "ConfigManager.h"

int main(int argc, char *argv[]) {
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/qt/qml/LogViewerApp/src/resources/icon.png"));
    app.setOrganizationName("LogViewer");
    app.setOrganizationDomain("logviewer.com");
    app.setApplicationName("LogViewer");
    app.setApplicationVersion(APP_VERSION);

    // Register the Theme singleton manually. The QT_QML_SINGLETON_TYPE
    // source-file property isn't fully honored by qt_add_qml_module on
    // Qt 6.2 (Ubuntu 22.04) — the generated qmldir omits "singleton Theme ..."
    // and Theme.* resolves to undefined. Manual registration works on all
    // Qt 6.x versions.
    qmlRegisterSingletonType(
        QUrl(QStringLiteral("qrc:/qt/qml/LogViewerApp/src/qml/Theme.qml")),
        "LogViewerApp", 1, 0, "Theme");

    QQmlApplicationEngine engine;

    GrafanaClient client;
    LogModel model;
    ConfigManager config;

    // Direct C++ wiring — the QML signal hop can't convert JS-array back to
    // QList<LogEntry> (LogEntry isn't a Q_GADGET), so QML can't call appendEntries
    // itself. Each batch lands in the model directly; QML handler then decides
    // whether to fetch the next batch based on totalCount delta.
    QObject::connect(&client, &GrafanaClient::logsReceived, &model, &LogModel::appendEntries);
    QObject::connect(&client, &GrafanaClient::loadingChanged, &model, &LogModel::setLoading);

    engine.rootContext()->setContextProperty("grafanaClient", &client);
    engine.rootContext()->setContextProperty("logModel", &model);
    engine.rootContext()->setContextProperty("configManager", &config);
    engine.rootContext()->setContextProperty("appVersion", APP_VERSION);

    const QUrl url(QStringLiteral("qrc:/qt/qml/LogViewerApp/src/qml/Main.qml"));
    if (url.isEmpty()) {
        qCritical() << "URL is empty!";
    }
    
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
