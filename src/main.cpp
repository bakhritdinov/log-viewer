#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStringConverter>
#include <QIcon>
#include "GrafanaClient.h"
#include "LogModel.h"
#include "ConfigManager.h"
#include "UpdateManager.h"

int main(int argc, char *argv[]) {
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/qt/qml/LogViewerApp/src/resources/icon.png"));
    app.setOrganizationName("LogViewer");
    app.setOrganizationDomain("logviewer.com");
    app.setApplicationName("LogViewer");
    app.setApplicationVersion(APP_VERSION);

    QQmlApplicationEngine engine;

    GrafanaClient client;
    LogModel model;
    ConfigManager config;
    UpdateManager updater;

    // Connect client to model
    QObject::connect(&client, &GrafanaClient::logsReceived, &model, &LogModel::setEntries);
    QObject::connect(&client, &GrafanaClient::loadingChanged, &model, &LogModel::setLoading);

    engine.rootContext()->setContextProperty("grafanaClient", &client);
    engine.rootContext()->setContextProperty("logModel", &model);
    engine.rootContext()->setContextProperty("configManager", &config);
    engine.rootContext()->setContextProperty("updateManager", &updater);

    // Initial check for updates
    updater.checkForUpdates();

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
