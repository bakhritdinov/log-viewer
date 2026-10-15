// Runs the desktop design against a fake Grafana. `harness` (a context
// property) scripts responses and reports the requests the app made.
#include <QDateTime>
#include <QJsonArray>
#include <QQmlContext>
#include <QQmlEngine>
#include <QtQml/qqmlextensionplugin.h>
#include <QtQuickTest>

#include "app/AppServices.h"
#include "app/Language.h"
#include "app/Session.h"
#include "support/FakeHttp.h"

Q_IMPORT_QML_PLUGIN(LogViewer_AppPlugin)
Q_IMPORT_QML_PLUGIN(LogViewer_UiPlugin)
Q_IMPORT_QML_PLUGIN(LogViewer_DesktopPlugin)

using namespace lv;
using namespace lvtest;

class Harness : public QObject {
    Q_OBJECT
    Q_PROPERTY(int requestCount READ requestCount)

public:
    explicit Harness(bool configured)
    {
        services = std::make_unique<AppServices>(http, kv, secrets, makeInlineParseExecutor());
        if (configured) {
            Environment dev = *services->environments().find("dev");
            dev.url = QUrl("https://dev-grafana");
            dev.datasourceUid = "dev-uid";
            dev.auth = Environment::Auth::None;
            services->environments().upsert(dev);
        }
        language = std::make_unique<Language>(kv);
        Language::setInstance(language.get());
        language->apply();
        session = std::make_unique<Session>(*services);
        Session::setInstance(session.get());
        QObject::connect(language.get(), &Language::codeChanged, session.get(), &Session::retranslate);
    }

    int requestCount() const { return int(http.requests.size()); }

    // Discovery (two phases) and `count` log rows, newest first.
    Q_INVOKABLE void scriptStartup(int count)
    {
        http.script(ok(fixture("grafana/discovery_phase1.json")));
        http.script(ok(fixture("grafana/discovery_phase2.json")));
        scriptLogs(count);
    }
    Q_INVOKABLE void scriptLogs(int count)
    {
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        QList<Row> rows;
        const char* levels[] = { "error", "warn", "info" };
        for (int i = 0; i < count; ++i)
            rows.append({ now - 1000 - qint64(i) * 1000,
                          QStringLiteral("payment %1 failed: upstream timeout after %2 ms").arg(48000 + i).arg(30000 + i),
                          QString::fromLatin1(levels[i % 3]) });
        http.script(ok(logsBody(rows)));
    }
    Q_INVOKABLE void start() { session->start(); }
    Q_INVOKABLE QString lastExpr() const
    {
        if (http.requests.isEmpty()) return {};
        return jsonBody(http.requests.last()).value("queries").toArray().first().toObject().value("expr").toString();
    }

    FakeHttpClient http;
    MemoryStore kv;
    MemorySecretStore secrets;
    std::unique_ptr<AppServices> services;
    std::unique_ptr<Language> language;
    std::unique_ptr<Session> session;
};

class Setup : public QObject {
    Q_OBJECT

public slots:
    void applicationAvailable()
    {
        m_harness = std::make_unique<Harness>(qEnvironmentVariable("LOGVIEWER_TEST_SCENARIO") != u"first_run");
    }
    void qmlEngineAvailable(QQmlEngine* engine)
    {
        m_harness->language->attachEngine(engine);
        engine->rootContext()->setContextProperty("harness", m_harness.get());
    }
    void cleanupTestCase() { m_harness.reset(); }

private:
    std::unique_ptr<Harness> m_harness;
};

QUICK_TEST_MAIN_WITH_SETUP(ui_desktop, Setup)
#include "tst_ui_desktop.moc"
