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
#include "app/DeviceBridge.h"
#include "app/Language.h"
#include "app/Session.h"
#include "support/FakeHttp.h"

namespace lvtest {

using namespace lv;

class Harness : public QObject {
    Q_OBJECT
    Q_PROPERTY(int requestCount READ requestCount)
    Q_PROPERTY(QString lastShared MEMBER lastShared)
    Q_PROPERTY(QString lastSaved MEMBER lastSaved)
    Q_PROPERTY(int fileRequests MEMBER fileRequests)

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
    // A device with a share sheet and files (the browser's, say), recording
    // what the app asked of it; deliverFile() answers openFile().
    Q_INVOKABLE void plugDevice()
    {
        session->device()->setShareHandler([this](const QString& title, const QString& url) { lastShared = title + "|" + url; });
        session->device()->setFileHandlers([this](const QString& name, const QString& content) { lastSaved = name + "|" + content; },
                                           [this] { ++fileRequests; });
    }
    Q_INVOKABLE void deliverFile(const QString& content) { session->device()->deliverFile(content); }
    Q_INVOKABLE QString lastExpr() const
    {
        if (http.requests.isEmpty()) return {};
        return jsonBody(http.requests.last()).value("queries").toArray().first().toObject().value("expr").toString();
    }

    // The same entries every time (the first answer's clock): a later answer,
    // e.g. the context around an entry, holds that very entry again.
    QList<Row> rows(int count)
    {
        if (baseMs == 0) baseMs = QDateTime::currentMSecsSinceEpoch();
        const qint64 now = baseMs;
        QList<Row> out;
        const char* levels[] = { "error", "warn", "info" };
        for (int i = 0; i < count; ++i)
            out.append({ now - 1000 - qint64(i) * 1000,
                         QStringLiteral("payment %1 failed: upstream timeout after %2 ms").arg(48000 + i).arg(30000 + i),
                         QString::fromLatin1(levels[i % 3]) });
        return out;
    }

    // Entries shaped like a busy production service: ~15 fields each, JSON
    // messages, multi-line stack traces, a dozen distinct message shapes.
    Q_INVOKABLE void scriptRealisticLogs(int count) { http.script(ok(labeledLogsBody(realisticRows(count)))); }
    // Entries newer than the first answer's: `count` of them ending `aheadMs` after it.
    Q_INVOKABLE void scriptRealisticNewer(int count, int aheadMs) { rows(0); http.script(ok(labeledLogsBody(realisticRows(count, baseMs + aheadMs)))); }
    // The next `count` entries after the first `skip` (a "load more" answer).
    Q_INVOKABLE void scriptRealisticOlder(int count, int skip) { rows(0); http.script(ok(labeledLogsBody(realisticRows(count, baseMs - 1000 - qint64(skip) * 200, skip)))); }
    Q_INVOKABLE void completeLastRealistic(int count) { http.complete(http.calls.size() - 1, ok(labeledLogsBody(realisticRows(count)))); }

    QList<LabeledRow> realisticRows(int count, qint64 newestMs = 0, int first = 0)
    {
        if (baseMs == 0) baseMs = QDateTime::currentMSecsSinceEpoch();
        if (newestMs == 0) newestMs = baseMs - 1000;
        static const char* methods[] = { "GET", "POST", "PUT", "DELETE" };
        static const char* paths[] = { "/v1/charge", "/v1/refund", "/v1/customers/{id}", "/v1/invoices", "/health" };
        static const char* pods[] = { "billing-api-7d9f8-x2k4", "billing-api-7d9f8-m81q", "billing-api-7d9f8-p0zz" };
        QList<LabeledRow> out;
        out.reserve(count);
        for (int n = 0; n < count; ++n) {
            const int i = first + n;
            const int kind = (i * 7) % 12;
            const char* level = kind == 0 ? "error" : kind < 3 ? "warn" : kind < 11 ? "info" : "debug";
            const QString trace = QStringLiteral("%1").arg(quint64(0x9e3779b97f4a7c15ULL * quint64(i / 3 + 1)), 16, 16, QLatin1Char('0'));
            QJsonObject labels{
                { "_namespace", "prod-core" }, { "_appName", "billing-api" }, { "level", level },
                { "pod", pods[i % 3] }, { "container", "app" }, { "node", QStringLiteral("ip-10-0-%1-%2").arg(i % 4).arg(i % 250) },
                { "trace_id", trace }, { "span_id", trace.left(8) },
                { "method", methods[i % 4] }, { "path", paths[i % 5] }, { "status", QString::number(kind == 0 ? 502 : 200) },
                { "duration_ms", QString::number(5 + (i * 37) % 4000) }, { "customer_id", QStringLiteral("cus_%1").arg(100000 + i % 977) },
                { "region", i % 2 ? "eu-west-1" : "us-east-1" }, { "version", "3.14.2" },
            };
            QString message;
            switch (kind) {
            case 0:
                message = QStringLiteral("payment %1 failed: upstream timeout after %2 ms\n"
                                         "java.net.SocketTimeoutException: Read timed out\n"
                                         "\tat java.base/sun.nio.ch.NioSocketImpl.timedRead(NioSocketImpl.java:288)\n"
                                         "\tat com.example.billing.gateway.Client.charge(Client.java:%3)\n"
                                         "\tat com.example.billing.ChargeService.run(ChargeService.java:118)\n"
                                         "\tat com.example.billing.Worker.lambda$start$0(Worker.java:52)\n"
                                         "\tat java.base/java.lang.Thread.run(Thread.java:1583)")
                              .arg(48000 + i).arg(30000 + i % 500).arg(200 + i % 40);
                break;
            case 1: case 2:
                message = QStringLiteral("retrying charge %1 (attempt %2/3), backoff %3 ms").arg(48000 + i).arg(1 + i % 3).arg(250 * (1 + i % 3));
                break;
            case 3: case 4: case 5:
                message = QStringLiteral("{\"msg\":\"request handled\",\"method\":\"%1\",\"path\":\"%2\",\"status\":200,"
                                         "\"duration_ms\":%3,\"customer\":{\"id\":\"cus_%4\",\"plan\":\"pro\",\"country\":\"UZ\"},"
                                         "\"headers\":{\"user-agent\":\"okhttp/4.12.0\",\"x-request-id\":\"%5\"},\"bytes\":%6}")
                              .arg(methods[i % 4]).arg(paths[i % 5]).arg(5 + (i * 37) % 4000).arg(100000 + i % 977).arg(trace).arg(512 + i % 9000);
                break;
            case 6: case 7:
                message = QStringLiteral("%1 %2 %3 (%4 ms)").arg(methods[i % 4]).arg(paths[i % 5]).arg(200).arg(5 + (i * 37) % 4000);
                break;
            case 8:
                message = QStringLiteral("cache miss for customer cus_%1, loading from db").arg(100000 + i % 977);
                break;
            case 9: case 10:
                message = QStringLiteral("invoice inv_%1 created for cus_%2: amount=%3.%4 UZS items=%5")
                              .arg(700000 + i).arg(100000 + i % 977).arg(10000 + i % 90000).arg(i % 100, 2, 10, QLatin1Char('0')).arg(1 + i % 7);
                break;
            default:
                message = QStringLiteral("pool stats: active=%1 idle=%2 waiting=%3").arg(i % 20).arg(20 - i % 20).arg(i % 3);
            }
            out.append({ newestMs - qint64(n) * 200, labels, message });
        }
        return out;
    }

    qint64 baseMs = 0;
    QString lastShared;
    QString lastSaved;
    int fileRequests = 0;
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
