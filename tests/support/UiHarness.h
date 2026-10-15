#pragma once
// A design under test against a fake Grafana. `harness` (a context property)
// scripts responses and reports the requests the app made; Setup creates it
// before QML loads (QUICK_TEST_MAIN_WITH_SETUP). Shared by the desktop and
// mobile scenario tests.
#include <QDateTime>
#include <QJsonArray>
#include <QQmlContext>
#include <QQmlEngine>

#include "app/AppServices.h"
#include "app/Language.h"
#include "app/Session.h"
#include "support/FakeHttp.h"

namespace lvtest {

using namespace lv;

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
    Q_INVOKABLE void scriptLogs(int count) { http.script(ok(logsBody(rows(count)))); }
    // An HTTP error for the next request. A request with nothing scripted stays
    // pending (loading) until completeLast().
    Q_INVOKABLE void scriptStatus(int code, const QString& body = {}) { http.script(status(code, body.toUtf8())); }
    Q_INVOKABLE void completeLast(int count) { http.complete(http.calls.size() - 1, ok(logsBody(rows(count)))); }
    Q_INVOKABLE void start() { session->start(); }
    Q_INVOKABLE QString lastExpr() const
    {
        if (http.requests.isEmpty()) return {};
        return jsonBody(http.requests.last()).value("queries").toArray().first().toObject().value("expr").toString();
    }

    static QList<Row> rows(int count)
    {
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        QList<Row> out;
        const char* levels[] = { "error", "warn", "info" };
        for (int i = 0; i < count; ++i)
            out.append({ now - 1000 - qint64(i) * 1000,
                         QStringLiteral("payment %1 failed: upstream timeout after %2 ms").arg(48000 + i).arg(30000 + i),
                         QString::fromLatin1(levels[i % 3]) });
        return out;
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

} // namespace lvtest
