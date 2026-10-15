#include <QSignalSpy>
#include <QTest>

#include "core/data/LabelDiscovery.h"
#include "support/FakeHttp.h"

using namespace lv;
using namespace lvtest;

Q_DECLARE_METATYPE(lv::DiscoveryResult)
Q_DECLARE_METATYPE(lv::RequestError)

namespace {
Connection conn() { return { QUrl("https://g"), "uid", "u", "p", {} }; }
} // namespace

class TestLabelDiscovery : public QObject {
    Q_OBJECT

private slots:
    void initTestCase()
    {
        qRegisterMetaType<lv::DiscoveryResult>();
        qRegisterMetaType<lv::RequestError>();
    }

    void twoPhases()
    {
        FakeHttpClient http;
        http.script(ok(fixture("grafana/discovery_phase1.json")));
        http.script(ok(fixture("grafana/discovery_phase2.json")));
        LabelDiscovery d(http);
        QSignalSpy done(&d, &LabelDiscovery::finished);
        d.start(conn());
        QVERIFY(d.isRunning());
        QVERIFY(done.wait(1000));
        QVERIFY(!d.isRunning());
        QCOMPARE(http.requests.size(), 2);
        QVERIFY(jsonBody(http.requests.at(1)).value("queries").toArray().first().toObject()
                    .value("expr").toString().contains("stats by (_namespace, _appName)"));
        const auto r = done.first().first().value<DiscoveryResult>();
        QCOMPARE(r.nsLabel, "_namespace");
        QCOMPARE(r.streams.value("prod-core"), (QStringList{ "billing-api", "billing-gw", "unknown", "billing-worker" }));
        QCOMPARE(r.streams.value("prod-data"), QStringList{ "etl" });
    }

    void chosenLabelsSkipPhase1()
    {
        FakeHttpClient http;
        http.script(ok(fixture("grafana/discovery_phase2.json")));
        LabelDiscovery d(http);
        QSignalSpy done(&d, &LabelDiscovery::finished);
        QSignalSpy labels(&d, &LabelDiscovery::labelsFound);
        d.start(conn(), "_namespace", "_appName");
        QVERIFY(done.wait(1000));
        QCOMPARE(http.requests.size(), 1);                   // the pairs only
        QCOMPARE(labels.count(), 1);
        const auto r = done.first().first().value<DiscoveryResult>();
        QCOMPARE(r.nsLabel, "_namespace");
        QCOMPARE(r.streams.value("prod-data"), QStringList{ "etl" });
    }

    void chosenLabelsReportErrors()
    {
        FakeHttpClient http;
        http.script(status(401));
        LabelDiscovery d(http);
        QSignalSpy failed(&d, &LabelDiscovery::failed);
        d.start(conn(), "ns", "app");
        QVERIFY(failed.wait(1000));
        QCOMPARE(failed.first().first().value<RequestError>().kind, RequestError::Kind::Unauthorized);
    }

    void phase2FailureFallsBackToPhase1()
    {
        FakeHttpClient http;
        http.script(ok(fixture("grafana/discovery_phase1.json")));
        http.script(status(500));
        LabelDiscovery d(http);
        QSignalSpy done(&d, &LabelDiscovery::finished);
        QSignalSpy failed(&d, &LabelDiscovery::failed);
        d.start(conn());
        QVERIFY(done.wait(1000));
        QCOMPARE(failed.count(), 0);
        QCOMPARE(done.first().first().value<DiscoveryResult>().streams.value("prod-edge"), QStringList{ "router" });
    }

    void phase1HttpErrorIsClassified()
    {
        FakeHttpClient http;
        http.script(status(401, "invalid credentials"));
        LabelDiscovery d(http);
        QSignalSpy failed(&d, &LabelDiscovery::failed);
        d.start(conn());
        QVERIFY(failed.wait(1000));
        QCOMPARE(failed.first().first().value<RequestError>().kind, RequestError::Kind::Unauthorized);
        QCOMPARE(http.requests.size(), 1);
    }

    void unknownLabelsReportSeenNames()
    {
        FakeHttpClient http;
        http.script(ok(fixture("grafana/discovery_phase1_unknown_labels.json")));
        LabelDiscovery d(http);
        QSignalSpy failed(&d, &LabelDiscovery::failed);
        d.start(conn());
        QVERIFY(failed.wait(1000));
        const auto e = failed.first().first().value<RequestError>();
        QCOMPARE(e.kind, RequestError::Kind::UnknownLabels);
        QCOMPARE(e.detail, "container, host, region");
    }

    void notConfiguredFailsImmediately()
    {
        FakeHttpClient http;
        LabelDiscovery d(http);
        QSignalSpy failed(&d, &LabelDiscovery::failed);
        d.start(Connection{});
        QCOMPARE(failed.count(), 1);
        QCOMPARE(failed.first().first().value<RequestError>().kind, RequestError::Kind::NotConfigured);
        QVERIFY(http.requests.isEmpty());
    }

    void restartSupersedesRunningDiscovery()
    {
        FakeHttpClient http;
        http.script(std::nullopt);                                   // first run hangs
        http.script(ok(fixture("grafana/discovery_phase1.json")));   // second run
        http.script(ok(fixture("grafana/discovery_phase2.json")));
        LabelDiscovery d(http);
        QSignalSpy done(&d, &LabelDiscovery::finished);
        QSignalSpy failed(&d, &LabelDiscovery::failed);
        d.start(conn());
        d.start(conn());
        QVERIFY(http.calls.first().isNull() || http.calls.first()->isDone());   // first was aborted
        QVERIFY(done.wait(1000));
        QCOMPARE(done.count(), 1);
        QCOMPARE(failed.count(), 0);   // the aborted run reports nothing
    }

    void cancelReportsNothing()
    {
        FakeHttpClient http;
        http.script(std::nullopt);
        LabelDiscovery d(http);
        QSignalSpy done(&d, &LabelDiscovery::finished);
        QSignalSpy failed(&d, &LabelDiscovery::failed);
        d.start(conn());
        d.cancel();
        QVERIFY(!d.isRunning());
        QTest::qWait(20);
        QCOMPARE(done.count() + failed.count(), 0);
    }
};

QTEST_GUILESS_MAIN(TestLabelDiscovery)
#include "tst_label_discovery.moc"
