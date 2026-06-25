#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>
#include <QStringConverter>
#include <QIcon>
#include <QTimer>
#include "ConfigManager.h"
#include "UpdateChecker.h"
#include "logs/GrafanaClient.h"
#include "logs/LogModel.h"
#include "ecotone/EcotoneClient.h"
#include "ecotone/ErrorMessagesModel.h"
#include "ecotone/EcotoneConfigManager.h"
#include "ecotone/FifoChannels.h"

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
        QUrl(QStringLiteral("qrc:/qt/qml/LogViewerApp/src/common/qml/Theme.qml")),
        "LogViewerApp", 1, 0, "Theme");

    QQmlApplicationEngine engine;

    ConfigManager config;
    UpdateChecker updateChecker;

    GrafanaClient client;
    LogModel model;

    FifoChannels fifoChannels;
    EcotoneClient ecotoneClient;
    ecotoneClient.setFifoChannels(&fifoChannels);
    ErrorMessagesModel errorMessagesModel;
    errorMessagesModel.setFifoChannels(&fifoChannels);
    EcotoneConfigManager ecotoneConfig;

    // First check 3s after launch so it doesn't compete with initial Loki query;
    // then re-check every 6h while the app stays open.
    QTimer::singleShot(3000, &updateChecker, &UpdateChecker::checkForUpdates);
    QTimer* updateTimer = new QTimer(&app);
    updateTimer->setInterval(6 * 60 * 60 * 1000);
    QObject::connect(updateTimer, &QTimer::timeout,
                     &updateChecker, &UpdateChecker::checkForUpdates);
    updateTimer->start();

    // Direct C++ wiring — the QML signal hop can't convert JS-array back to
    // QList<LogEntry> (LogEntry isn't a Q_GADGET), so QML can't call appendEntries
    // itself. Each batch lands in the model directly; QML handler then decides
    // whether to fetch the next batch based on totalCount delta.
    QObject::connect(&client, &GrafanaClient::logsReceived, &model, &LogModel::appendEntries);
    QObject::connect(&client, &GrafanaClient::loadingChanged, &model, &LogModel::setLoading);

    QObject::connect(&ecotoneClient, &EcotoneClient::errorsReceived,
                     &errorMessagesModel, &ErrorMessagesModel::setEntries);

    engine.rootContext()->setContextProperty("grafanaClient", &client);
    engine.rootContext()->setContextProperty("logModel", &model);
    engine.rootContext()->setContextProperty("configManager", &config);
    engine.rootContext()->setContextProperty("updateChecker", &updateChecker);
    engine.rootContext()->setContextProperty("appVersion", APP_VERSION);

    engine.rootContext()->setContextProperty("ecotoneClient", &ecotoneClient);
    engine.rootContext()->setContextProperty("errorMessagesModel", &errorMessagesModel);
    engine.rootContext()->setContextProperty("ecotoneConfig", &ecotoneConfig);
    engine.rootContext()->setContextProperty("fifoChannels", &fifoChannels);

    // Make the compiled-in module resolvable by `import LogViewerApp`.
    // Main.qml is loaded by direct qrc URL, so the qmldir applied is the one next
    // to Main.qml (src/logs/qml/, which has none). Without the module's own qmldir
    // (at qrc:/qt/qml/LogViewerApp/) on the import path, `import LogViewerApp` and
    // its subdirectory types (PrimaryButton, AppContent, ...) fail to resolve from
    // the qrc — the app only worked when run next to the on-disk build module.
    // Adding the resource module root to the import path fixes it on Qt 6.2 too
    // (QQmlApplicationEngine::loadFromModule() is only available since Qt 6.5).
    engine.addImportPath(QStringLiteral("qrc:/qt/qml"));

    const QUrl url(QStringLiteral("qrc:/qt/qml/LogViewerApp/src/logs/qml/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
