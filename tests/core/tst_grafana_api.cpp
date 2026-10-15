#include <QJsonArray>
#include <QTest>

#include "core/data/GrafanaApi.h"
#include "support/FakeHttp.h"

using namespace lv;
using namespace lvtest;

namespace {
Connection conn()
{
    return { QUrl("https://grafana.example"), "ds-uid", "alice", "s3cret", {} };
}
const QDateTime kT0 = QDateTime::fromString("2026-10-15T12:00:00Z", Qt::ISODate);
} // namespace

class TestGrafanaApi : public QObject {
    Q_OBJECT

private slots:
    void authorization()
    {
        Connection c = conn();
        QCOMPARE(c.authorizationHeader(), "Basic " + QByteArray("alice:s3cret").toBase64());
        c.token = "tok";
        QCOMPARE(c.authorizationHeader(), QByteArray("Bearer tok"));   // token wins
        const Connection anonymous{ QUrl("https://g"), "u" };
        QCOMPARE(anonymous.authorizationHeader(), QByteArray());
    }

    void isConfigured()
    {
        QVERIFY(conn().isConfigured());
        QVERIFY(!Connection{}.isConfigured());
        QVERIFY(!(Connection{ QUrl("https://g"), "" }.isConfigured()));
        QVERIFY(!(Connection{ QUrl(), "uid" }.isConfigured()));
    }

    void logsQueryRequestShape()
    {
        const HttpRequest r = logsQueryRequest(conn(), "{a=\"b\"} x", "now-3600s", "now");
        QCOMPARE(r.method, QByteArray("POST"));
        QCOMPARE(r.url, QUrl("https://grafana.example/api/ds/query"));
        QCOMPARE(header(r, "content-type"), QByteArray("application/json"));
        QVERIFY(header(r, "Authorization").startsWith("Basic "));
        const QJsonObject body = jsonBody(r);
        QCOMPARE(body.value("from").toString(), "now-3600s");
        QCOMPARE(body.value("to").toString(), "now");
        const QJsonObject q = body.value("queries").toArray().first().toObject();
        QCOMPARE(q.value("refId").toString(), "A");
        QCOMPARE(q.value("datasource").toObject().value("uid").toString(), "ds-uid");
        QCOMPARE(q.value("expr").toString(), "{a=\"b\"} x");
        QCOMPARE(q.value("queryType").toString(), "range");
        QCOMPARE(q.value("limit").toInt(), 1000);
        QCOMPARE(q.value("maxLines").toInt(), 1000);
    }

    void urlKeepsSubpathAndDropsTrailingSlash()
    {
        Connection c = conn();
        c.baseUrl = QUrl("https://host/grafana/");
        QCOMPARE(logsQueryRequest(c, "x", "now-1h", "now").url, QUrl("https://host/grafana/api/ds/query"));
    }

    void discoveryRequests()
    {
        const QJsonObject p1 = jsonBody(discoveryRequest(conn())).value("queries").toArray().first().toObject();
        QCOMPARE(p1.value("expr").toString(), "{}");
        QCOMPARE(p1.value("limit").toInt(), 10000);
        const QJsonObject p2body = jsonBody(streamPairsRequest(conn(), "_namespace", "_appName"));
        QCOMPARE(p2body.value("from").toString(), "now-24h");
        const QJsonObject p2 = p2body.value("queries").toArray().first().toObject();
        QCOMPARE(p2.value("expr").toString(), "* | stats by (_namespace, _appName) count()");
        QCOMPARE(p2.value("queryType").toString(), "instant");
    }

    void parseBasic()
    {
        const ParsedLogs p = parseLogsResponse(fixture("grafana/logs_basic.json"));
        QVERIFY(p.error.isEmpty());
        QCOMPARE(p.entries.size(), 3);
        const LogEntry& e = p.entries.first();
        QCOMPARE(e.timestamp, kT0);
        QCOMPARE(e.message, "payment failed: upstream timeout after 30004 ms");
        QCOMPARE(e.level, Level::Error);
        QCOMPARE(e.fields.value("pod").toString(), "billing-api-x2k4");
        QCOMPARE(e.fields.value("_appName").toString(), "billing-api");
        QCOMPARE(p.entries.at(1).level, Level::Warn);
        QCOMPARE(p.entries.at(2).level, Level::Info);   // from `severity`
        QCOMPARE(p.entries.at(2).timeMs(), kT0.toMSecsSinceEpoch() - 3000);
    }

    void parseFramesAliasesAndTypes()
    {
        const ParsedLogs p = parseLogsResponse(fixture("grafana/logs_two_frames.json"));
        QCOMPARE(p.entries.size(), 2);
        const LogEntry& b = p.entries.at(1);
        QCOMPARE(b.message, "b");                              // `message` alias
        QCOMPARE(b.timeMs(), kT0.toMSecsSinceEpoch() - 500);   // `ts` alias
        QCOMPARE(b.fields.value("order_id").toLongLong(), 48213);
        QCOMPARE(b.fields.value("retry").toBool(), true);
        QCOMPARE(b.level, Level::Debug);
    }

    void parseEmptyAndErrors()
    {
        QVERIFY(parseLogsResponse(fixture("grafana/logs_empty.json")).entries.isEmpty());
        QVERIFY(parseLogsResponse(fixture("grafana/logs_no_frames.json")).entries.isEmpty());
        QVERIFY(parseLogsResponse(fixture("grafana/logs_empty.json")).error.isEmpty());

        const ParsedLogs err = parseLogsResponse(fixture("grafana/logs_datasource_error.json"));
        QVERIFY(err.entries.isEmpty());
        QVERIFY(err.error.contains("unexpected token"));

        const ParsedLogs bad = parseLogsResponse("<html>gateway</html>");
        QVERIFY(bad.error.startsWith("Malformed response"));
    }

    void entryWithoutTimeIsStampedNow()
    {
        const QDateTime before = QDateTime::currentDateTimeUtc();
        const ParsedLogs p = parseLogsResponse(fixture("grafana/logs_no_time.json"));
        QCOMPARE(p.entries.size(), 1);
        QVERIFY(p.entries.first().timestamp >= before);
    }

    void discoveryPhase1()
    {
        const DiscoveryResult d = parseDiscoveryResponse(fixture("grafana/discovery_phase1.json"));
        QVERIFY(d.found());
        QCOMPARE(d.nsLabel, "_namespace");
        QCOMPARE(d.appLabel, "_appName");
        QCOMPARE(d.streams.value("prod-core"), (QStringList{ "billing-api", "billing-gw", "unknown" }));
        QCOMPARE(d.streams.value("prod-edge"), QStringList{ "router" });
        QVERIFY(!d.streams.contains(""));   // empty namespace skipped
    }

    void discoveryUnknownLabels()
    {
        const DiscoveryResult d = parseDiscoveryResponse(fixture("grafana/discovery_phase1_unknown_labels.json"));
        QVERIFY(!d.found());
        QCOMPARE(d.seenLabels, (QStringList{ "container", "host", "region" }));

        const DiscoveryResult noApp = parseDiscoveryResponse(fixture("grafana/discovery_phase1_no_app.json"));
        QVERIFY(!noApp.found());
        QCOMPARE(noApp.nsLabel, "_namespace");
    }

    void discoveryPhase2Merge()
    {
        StreamMap streams = { { "prod-core", { "billing-api" } } };
        const int added = mergeStreamPairs(fixture("grafana/discovery_phase2.json"), "_namespace", "_appName", streams);
        QCOMPARE(added, 2);
        QCOMPARE(streams.value("prod-core"), (QStringList{ "billing-api", "billing-worker" }));
        QCOMPARE(streams.value("prod-data"), QStringList{ "etl" });
    }

    void labelCandidatesOrder()
    {
        QCOMPARE(namespaceLabelCandidates().first(), "_namespace");
        QCOMPARE(appLabelCandidates().first(), "_appName");
    }
};

QTEST_GUILESS_MAIN(TestGrafanaApi)
#include "tst_grafana_api.moc"
