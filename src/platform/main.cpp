// Entry point of the rewritten app: builds the real services (network,
// settings, secrets), the view-model singletons and loads the design that was
// selected at build time (LOGVIEWER_UI_MODULE).
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QtQml/qqmlextensionplugin.h>

#include "app/AppServices.h"
#include "app/Language.h"
#include "app/Preferences.h"
#include "app/Session.h"
#include "app/UpdateService.h"
#include "WebShell.h"
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
    // The settings of LogViewer 2.x: 3.x takes its environments and passwords
    // once (runLegacyMigration) and leaves 2.x's own keys in place.
    app.setApplicationName(QStringLiteral("LogViewer"));
    app.setApplicationVersion(QStringLiteral(APP_VERSION));
    app.setWindowIcon(QIcon(QStringLiteral(":/logviewer/icon.png")));

#ifdef LOGVIEWER_UI_PHONE
    lv::Preferences::setDefaults(lv::Preferences::Defaults::phone());
#endif
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
    auto* window = engine.rootObjects().isEmpty() ? nullptr : qobject_cast<QQuickWindow*>(engine.rootObjects().constFirst());
#ifdef Q_OS_WASM
    // In the browser the window is the whole page (its size follows the tab).
    if (window) window->showFullScreen();
#endif
    lv::webshell::attach(window, session);

    // The update check at start-up (throttled inside; off in Settings → Version).
    if (auto* updates = engine.singletonInstance<lv::UpdateService*>("LogViewer.App", "Updates"); updates && updates->autoCheck())
        updates->checkForUpdates();

    lv::runLegacyMigration(services, [&](bool) {
        session.environmentsEdited();
        // Opened from a share link (the browser page's address): that view.
        if (!lv::webshell::openInitialLink(session)) session.start();
    });
    return app.exec();
}
