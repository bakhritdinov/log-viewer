// Entry point of the rewritten app: builds the real services (network,
// settings, secrets), the view-model singletons and loads the design that was
// selected at build time (LOGVIEWER_UI_MODULE).
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QtQml/qqmlextensionplugin.h>

#include "app/AppServices.h"
#include "app/Language.h"
#include "app/Session.h"
#include "core/data/QtHttpClient.h"
#include "core/storage/KeyValueStore.h"
#include "core/storage/SecretStore.h"

Q_IMPORT_QML_PLUGIN(LogViewer_AppPlugin)
Q_IMPORT_QML_PLUGIN(LogViewer_UiPlugin)
Q_IMPORT_QML_PLUGIN(LOGVIEWER_UI_PLUGIN)

int main(int argc, char* argv[])
{
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QGuiApplication app(argc, argv);
    app.setOrganizationName(QStringLiteral("LogViewer"));
    app.setOrganizationDomain(QStringLiteral("logviewer.com"));
    // Own settings while the legacy app is still in use: running both must not
    // migrate (and remove) its keys. Stage 8 switches to "LogViewer".
    app.setApplicationName(QStringLiteral("LogViewerNext"));
    app.setApplicationVersion(QStringLiteral(APP_VERSION));
    app.setWindowIcon(QIcon(QStringLiteral(":/logviewer/icon.png")));

    lv::QSettingsStore settings;
    // Stage 8 replaces this with the OS keychain (QtKeychain).
    lv::SettingsSecretStore secrets(settings);
    lv::QtHttpClient http;
    lv::AppServices services(http, settings, secrets, lv::makeDefaultParseExecutor());

    lv::Language language(settings);
    lv::Language::setInstance(&language);
    language.apply();

    lv::Session session(services);
    lv::Session::setInstance(&session);
    QObject::connect(&language, &lv::Language::codeChanged, &session, &lv::Session::retranslate);

    QQmlApplicationEngine engine;
    language.attachEngine(&engine);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule(LOGVIEWER_UI_MODULE, "Main");

    lv::runLegacyMigration(services, [&](bool) {
        session.environmentsEdited();
        session.start();
    });
    return app.exec();
}
