// Scenario tests of the view-model layer over a scripted fake HTTP client.
#include <QAbstractItemModelTester>
#include <QSignalSpy>
#include <QTest>

#include "app/AppServices.h"
#include "app/FocusSession.h"
#include "app/LiveSession.h"
#include "app/Session.h"
#include "core/storage/Migration.h"
#include "support/FakeHttp.h"

using namespace lv;
using namespace lvtest;

namespace {

const QDateTime kNow = QDateTime::fromString("2026-10-15T12:00:00Z", Qt::ISODate);
const qint64 kNowMs = kNow.toMSecsSinceEpoch();

QString exprOf(const HttpRequest& r)
{
    return jsonBody(r).value("queries").toArray().first().toObject().value("expr").toString();
}

struct Harness {
    FakeHttpClient http;
    MemoryStore kv;
    MemorySecretStore secrets;
    std::unique_ptr<AppServices> services;
    std::unique_ptr<Session> session;

    explicit Harness(bool configure = true, std::unique_ptr<ParseExecutor> executor = makeInlineParseExecutor())
    {
        services = std::make_unique<AppServices>(http, kv, secrets, std::move(executor),
                                                 ClassifyOptions{}, [] { return kNow; });
        if (configure) {
            Environment dev = *services->environments().find("dev");
            dev.url = QUrl("https://dev-grafana");
            dev.datasourceUid = "dev-uid";
            dev.user = "alice";
            services->environments().upsert(dev);
            secrets.write(dev.passwordKey(), "pw", [](bool) {});
            Environment prod = *services->environments().find("prod");
            prod.url = QUrl("https://prod-grafana");
            prod.datasourceUid = "prod-uid";
            prod.auth = Environment::Auth::Token;
            services->environments().upsert(prod);
            secrets.write(prod.tokenKey(), "prod-token", [](bool) {});
        }
        session = std::make_unique<Session>(*services);
    }

    // Discovery (two phases) + one logs response.
    void scriptStartup(const QByteArray& logs)
    {
        http.script(ok(fixture("grafana/discovery_phase1.json")));
        http.script(ok(fixture("grafana/discovery_phase2.json")));
        http.script(ok(logs));
    }

    bool waitIdle(int requests)
    {
        return QTest::qWaitFor([&] {
            return http.requests.size() >= requests && !session->isLoading() && !session->isDiscovering()
                && !session->isAnalyzing();
        }, 2000);
    }

    // Background analysis / filtering finished.
    bool settle()
    {
        return QTest::qWaitFor([&] { return !session->isAnalyzing(); }, 2000);
    }
};

QByteArray mixedLogs()
{
    return logsBody(QList<Row>{
        { kNowMs - 1000, "payment failed: upstream timeout after 30004 ms", "error" },
        { kNowMs - 2000, "retrying charge (attempt 3/3)", "warn" },
        { kNowMs - 70000, "POST /v1/charge 200 (812 ms)", "info" },
        { kNowMs - 71000, "payment failed: upstream timeout after 30001 ms", "error" },
    });
}

} // namespace

class TestSession : public QObject {
    Q_OBJECT

private slots:
    void notConfiguredShowsSetup()
    {
        Harness h(false);
        h.session->start();
        QVERIFY(h.session->needsSetup());
        QCOMPARE(h.session->error().kind, ErrorInfo::Kind::NotConfigured);
        QCOMPARE(h.session->error().primaryAction, ErrorInfo::Action::OpenSettings);
        QVERIFY(h.http.requests.isEmpty());
    }

    void startupDiscoversSelectsAndSearches()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        QSignalSpy source(h.session.get(), &Session::sourceChanged);
        h.session->start();
        QVERIFY(h.waitIdle(3));
        QCOMPARE(h.session->namespaces(), (QStringList{ "prod-core", "prod-data", "prod-edge" }));
        QCOMPARE(h.session->namespaceName(), "prod-core");
        QCOMPARE(h.session->app(), "billing-api");
        QCOMPARE(h.session->apps(), (QStringList{ "billing-api", "billing-gw", "billing-worker", "unknown" }));
        QVERIFY(source.count() >= 1);
        // Basic auth from the stored password.
        QCOMPARE(header(h.http.requests.first(), "Authorization"), "Basic " + QByteArray("alice:pw").toBase64());
        QVERIFY(exprOf(h.http.requests.at(2)).startsWith("{_namespace=\"prod-core\", _appName=\"billing-api\"} _time:["));
        QCOMPARE(h.session->logs()->rowCount(), 4);
        QCOMPARE(h.session->logs()->data(h.session->logs()->index(0), LogListModel::LevelRole).toString(), "ERROR");
        QCOMPARE(h.session->levelTotals().value("ERROR").toInt(), 2);
        QVERIFY(h.session->histogram()->count() >= 2);
        QVERIFY(h.session->fieldCount() > 0);
        QVERIFY(!h.session->error().isActive());
        QVERIFY(h.session->namespaceLabel() == "_namespace");
    }

    void restoresRememberedSource()
    {
        Harness h;
        h.services->selection().setSelection("dev", { "prod-edge", "router" });
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        QCOMPARE(h.session->namespaceName(), "prod-edge");
        QCOMPARE(h.session->app(), "router");
    }

    void filtersFromChipsAndValues()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));

        h.http.script(ok(mixedLogs()));
        h.session->toggleFilter("level", "error");
        QVERIFY(h.waitIdle(4));
        QCOMPARE(h.session->searchText(), "level:\"error\"");
        QCOMPARE(h.session->chips()->count(), 1);
        QVERIFY(exprOf(h.http.requests.at(3)).endsWith(" level:\"error\""));

        h.http.script(ok(mixedLogs()));
        h.session->toggleFilter("pod", "canary", true);
        QVERIFY(h.waitIdle(5));
        QCOMPARE(h.session->chips()->get(1).value("exclude").toBool(), true);
        QVERIFY(exprOf(h.http.requests.at(4)).endsWith(" -pod:\"canary\""));

        h.http.script(ok(mixedLogs()));
        h.session->removeChip(0);
        QVERIFY(h.waitIdle(6));
        QCOMPARE(h.session->searchText(), "-pod:\"canary\"");
        QCOMPARE(h.session->history().first(), "-pod:\"canary\"");
    }

    void suggestionsCompleteFieldsAndValues()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        h.session->setSearchText("lev");
        QCOMPARE(h.session->suggestions()->get(0).value("completedText").toString(), "level:");
        h.session->applySuggestion(0);
        QCOMPARE(h.session->searchText(), "level:");
        QCOMPARE(h.http.requests.size(), 3);   // completing a field does not search
        h.session->setSearchText("level:err");
        QCOMPARE(h.session->suggestions()->get(0).value("value").toString(), "error");
        h.http.script(ok(mixedLogs()));
        h.session->applySuggestion(0, true);
        QCOMPARE(h.session->searchText(), "-level:\"error\"");
        QVERIFY(h.waitIdle(4));
    }

    void histogramFilterAndLevelPromotion()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));

        // Click the ERROR segment of the newest bucket: client-side only.
        const int newest = h.session->histogram()->count() - 1;
        h.session->applyBucketFilter(newest, "ERROR");
        QVERIFY(h.settle());
        QVERIFY(h.session->histogramFilterActive());
        QCOMPARE(h.session->logs()->rowCount(), 1);
        QCOMPARE(h.http.requests.size(), 3);
        QVERIFY(!h.session->levelServerSide());

        // "Load more" with a level picked: the level goes into the query.
        h.http.script(ok(logsBody(QList<Row>{ { kNowMs - 5000, "x", "error" } })));
        h.session->loadMore();
        QVERIFY(h.waitIdle(4));
        QVERIFY(h.session->levelServerSide());
        QVERIFY(exprOf(h.http.requests.at(3)).contains("(level:~\"(?i)^(err|error|"));

        // Clearing a server-side level reloads all levels.
        h.http.script(ok(mixedLogs()));
        h.session->clearHistogramFilter();
        QVERIFY(h.waitIdle(5));
        QVERIFY(!exprOf(h.http.requests.at(4)).contains("level:~"));
        QCOMPARE(h.session->logs()->rowCount(), 4);
    }

    void levelFilterFromLegend()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        h.session->applyLevelFilter("WARN");
        QVERIFY(h.settle());
        QCOMPARE(h.session->logs()->rowCount(), 1);
        QCOMPARE(h.session->activeLevel(), "WARN");
        h.session->clearHistogramFilter();
        QCOMPARE(h.session->logs()->rowCount(), 4);
        QCOMPARE(h.http.requests.size(), 3);   // client-side only
    }

    void requestErrorBecomesErrorInfo()
    {
        Harness h;
        h.http.script(ok(fixture("grafana/discovery_phase1.json")));
        h.http.script(ok(fixture("grafana/discovery_phase2.json")));
        h.http.script(status(401, "invalid username or password"));
        QSignalSpy err(h.session.get(), &Session::errorChanged);
        h.session->start();
        QTRY_COMPARE_WITH_TIMEOUT(h.session->error().kind, ErrorInfo::Kind::Unauthorized, 2000);
        QCOMPARE(h.session->error().primaryAction, ErrorInfo::Action::OpenSettings);
        QVERIFY(h.session->error().message.contains("DEV"));
        QCOMPARE(h.session->error().detail, "invalid username or password");
        // Retry clears the error and searches again.
        h.http.script(ok(mixedLogs()));
        h.session->retry();
        QVERIFY(h.waitIdle(4));
        QVERIFY(!h.session->error().isActive());
    }

    void switchEnvironmentUsesItsCredentials()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        h.scriptStartup(mixedLogs());
        QSignalSpy env(h.session.get(), &Session::environmentChanged);
        h.session->switchEnvironment("prod");
        QVERIFY(h.waitIdle(6));
        QCOMPARE(env.count(), 1);
        QCOMPARE(h.session->environmentName(), "PROD");
        QCOMPARE(h.http.requests.at(3).url, QUrl("https://prod-grafana/api/ds/query"));
        QCOMPARE(header(h.http.requests.at(3), "Authorization"), QByteArray("Bearer prod-token"));
        QCOMPARE(h.session->environments()->get(1).value("current").toBool(), true);
    }

    void timeRanges()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        h.http.script(ok(mixedLogs()));
        h.session->setPreset("15m");
        QVERIFY(h.waitIdle(4));
        QCOMPARE(h.session->timeRangeKey(), "15m");
        QVERIFY(exprOf(h.http.requests.at(3)).contains("_time:[2026-10-15T11:45:00.000Z, 2026-10-15T12:00:00.000Z]"));
        QVERIFY(!h.session->setAbsoluteRange("2026-10-15 12:00", "2026-10-15 09:00"));
        QVERIFY(!h.session->rangeError().isEmpty());
        QCOMPARE(h.http.requests.size(), 4);
        h.http.script(ok(mixedLogs()));
        QVERIFY(h.session->setAbsoluteRange("2026-10-15T09:00:00Z", "2026-10-15T10:00:00Z"));
        QVERIFY(h.waitIdle(5));
        QVERIFY(h.session->timeRangeAbsolute());
        QVERIFY(h.session->rangeError().isEmpty());
        QCOMPARE(h.services->selection().timeRange().kind(), TimeRange::Kind::Absolute);   // remembered
    }

    void selectionAndDetails()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        h.session->selectRow(0);
        QCOMPARE(h.session->selectedEntry().level, "ERROR");
        QVERIFY(h.session->selectedEntry().valid);
        h.session->selectNext();
        QCOMPARE(h.session->selectedRow(), 1);
        h.session->selectPrevious();
        h.session->selectPrevious();
        QCOMPARE(h.session->selectedRow(), 0);
        h.session->clearSelection();
        QVERIFY(!h.session->selectedEntry().valid);
    }

    void savedQueryRoundTrip()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        h.session->setSearchText("timeout");
        h.session->saveCurrentQuery("Таймауты");
        QCOMPARE(h.session->savedQueries()->count(), 1);
        QCOMPARE(h.session->savedQueries()->get(0).value("environmentName").toString(), "DEV");
        const QString id = h.session->savedQueries()->get(0).value("id").toString();

        h.session->setSearchText("other");
        h.http.script(ok(mixedLogs()));
        h.session->runSavedQuery(id);
        QVERIFY(h.waitIdle(4));
        QCOMPARE(h.session->searchText(), "timeout");
        QVERIFY(exprOf(h.http.requests.at(3)).endsWith(" ~\"(?i)timeout\""));
        h.session->removeSavedQuery(id);
        QCOMPARE(h.session->savedQueries()->count(), 0);
    }

    void shareLinkOpensSameView()
    {
        Harness a;
        a.scriptStartup(mixedLogs());
        a.session->start();
        QVERIFY(a.waitIdle(3));
        a.http.script(ok(mixedLogs()));
        a.session->selectSource("prod-edge", "router");
        QVERIFY(a.waitIdle(4));
        a.session->setSearchText("timeout");
        a.session->selectRow(0);
        const QString link = a.session->shareLink(true, true);
        QVERIFY(link.startsWith("logviewer://open?"));

        Harness b;
        b.scriptStartup(mixedLogs());
        QVERIFY(b.session->openLink(link));
        QVERIFY(b.waitIdle(3));
        QVERIFY(b.session->openedFromLink());
        QCOMPARE(b.session->namespaceName(), "prod-edge");
        QCOMPARE(b.session->app(), "router");
        QCOMPARE(b.session->searchText(), "timeout");
        QVERIFY(b.session->timeRangeAbsolute());
        QCOMPARE(b.session->selectedRow(), 0);     // anchor highlighted
        b.session->dismissLinkBanner();
        QVERIFY(!b.session->openedFromLink());

        QSignalSpy missing(b.session.get(), &Session::linkEnvironmentMissing);
        QVERIFY(!b.session->openLink("logviewer://open?v=1&env=QA&ns=a&app=b&range=1h"));
        QCOMPARE(missing.count(), 1);
        QVERIFY(!b.session->openLink("https://example.com/"));
    }

    void focusContextAndTrace()
    {
        Harness h;
        h.scriptStartup(logsBody(QList<Row>{ { kNowMs - 1000, "anchor", "error" } }));
        h.session->setSearchText("timeout");
        h.session->start();
        QVERIFY(h.waitIdle(3));

        FocusSession* f = h.session->focus();
        h.http.script(ok(logsBody(QList<Row>{ { kNowMs, "after", "info" }, { kNowMs - 1000, "anchor", "error" },
                                              { kNowMs - 2000, "before", "info" } })));
        f->openContext(h.session->logs(), 0, 60);
        QVERIFY(f->isActive());
        QTRY_COMPARE_WITH_TIMEOUT(f->logs()->rowCount(), 3, 2000);
        QCOMPARE(f->anchorRow(), 1);
        const QString expr = exprOf(h.http.requests.at(3));
        QVERIFY(expr.contains("_time:[2026-10-15T11:58:59.000Z, 2026-10-15T12:00:59.000Z]"));
        QVERIFY(!expr.contains("timeout"));   // search terms dropped in context
        QVERIFY(!f->canShowTrace());           // the fixture rows carry no trace id
        QCOMPARE(h.session->logs()->rowCount(), 1);   // main search untouched
        f->close();
        QVERIFY(!f->isActive());
    }

    void liveTailCollectsAndPauses()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        LiveSession* live = h.session->live();
        live->setIntervalMs(5);
        h.http.script(ok(logsBody(QList<Row>{ { kNowMs + 1000, "new 1" } })));
        h.http.script(std::nullopt);   // the second poll is answered by hand below
        live->start();
        QTRY_COMPARE_WITH_TIMEOUT(live->bufferCount(), 1, 2000);
        QTRY_COMPARE_WITH_TIMEOUT(h.http.requests.size(), 5, 2000);
        live->setPaused(true);
        h.http.complete(4, ok(logsBody(QList<Row>{ { kNowMs + 2000, "new 2" } })));
        QTRY_COMPARE_WITH_TIMEOUT(live->bufferCount(), 2, 2000);
        QCOMPARE(live->pending(), 1);
        QCOMPARE(live->logs()->rowCount(), 1);   // the visible rows stay put while paused
        live->resume();
        QCOMPARE(live->pending(), 0);
        QCOMPARE(live->logs()->rowCount(), 2);
        live->stop();
        QVERIFY(!live->isRunning());
    }

    void patternsHideOneOffsAndFilterInTheBackground()
    {
        Harness h;
        h.scriptStartup(logsBody(QList<Row>{ { kNowMs - 1000, "took 5 ms", "error" }, { kNowMs - 2000, "took 7 ms", "critical" },
                                             { kNowMs - 3000, "took 9 ms", "fatal" }, { kNowMs - 4000, "unique event", "warn" },
                                             { kNowMs - 5000, "took 3 ms", "info" } }));
        h.session->start();
        QVERIFY(h.waitIdle(3));
        h.session->setPatternsEnabled(true);
        QVERIFY(h.settle());
        QCOMPARE(h.session->patterns()->count(), 1);
        QCOMPARE(h.session->hiddenSinglePatterns(), 1);
        QCOMPARE(h.session->patterns()->get(0).value("count").toInt(), 3);

        h.session->showPattern(0, false);
        QVERIFY(h.session->isAnalyzing());           // computed off the UI thread
        QVERIFY(h.settle());
        QCOMPARE(h.session->logs()->rowCount(), 3);  // the INFO "took 3 ms" is not part of it
        QCOMPARE(h.session->histogramFilterLabel(), "Pattern: took * ms");
        h.session->clearHistogramFilter();
        h.session->showPattern(0, true);
        QVERIFY(h.settle());
        QCOMPARE(h.session->logs()->rowCount(), 2);   // the WARN one and the INFO one stay
        QCOMPARE(h.http.requests.size(), 3);         // all client-side
    }

    void aNewerFilterWinsOverAPendingOne()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        h.session->applyLevelFilter("WARN");
        h.session->applyLevelFilter("ERROR");        // before the first one is applied
        QVERIFY(h.settle());
        QCOMPARE(h.session->activeLevel(), "ERROR");
        QCOMPARE(h.session->logs()->rowCount(), 2);
    }

    // The list is updated as soon as a batch is in; histogram and fields are
    // computed afterwards in the background (they never hold the list back).
    void listUpdatesBeforeBackgroundAnalysis()
    {
        Harness h;
        QStringList order;
        connect(h.session->logs(), &LogListModel::slicingChanged, [&] { if (!order.contains("list")) order << "list"; });
        connect(h.session.get(), &Session::histogramChanged, [&] { if (!order.contains("histogram")) order << "histogram"; });
        connect(h.session.get(), &Session::facetsChanged, [&] { if (!order.contains("fields")) order << "fields"; });
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        QCOMPARE(order.value(0), "list");
        QVERIFY(order.contains("histogram"));
        QVERIFY(order.contains("fields"));
    }

    // A histogram/level filter leaves the list as it is until the filtered view
    // has been computed in the background.
    void filterDoesNotBlockTheList()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        h.session->applyLevelFilter("ERROR");
        QVERIFY(h.session->isAnalyzing());
        QCOMPARE(h.session->logs()->rowCount(), 4);   // unchanged for now
        QVERIFY(h.settle());
        QCOMPARE(h.session->logs()->rowCount(), 2);
    }

    // Same, on real worker threads.
    void threadedAnalysisAndFiltering()
    {
        Harness h(true, makeThreadedParseExecutor());
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        QCOMPARE(h.session->levelTotals().value("ERROR").toInt(), 2);
        QVERIFY(h.session->fieldCount() > 0);
        h.session->applyLevelFilter("WARN");
        QVERIFY(h.settle());
        QCOMPARE(h.session->logs()->rowCount(), 1);
        h.session->setPatternsEnabled(true);
        QVERIFY(h.settle());
        QCOMPARE(h.session->patterns()->count() + h.session->hiddenSinglePatterns(), 1);
    }

    // As in 2.8: the chart is scaled to WARN + ERROR; INFO/DEBUG do not count.
    void histogramShowsWarnAndAbove()
    {
        Harness h;
        h.scriptStartup(logsBody(QList<Row>{ { kNowMs - 1000, "a", "info" }, { kNowMs - 1100, "b", "info" },
                                             { kNowMs - 1200, "c", "info" }, { kNowMs - 1300, "d", "warn" },
                                             { kNowMs - 1400, "e", "error" } }));
        h.session->start();
        QVERIFY(h.waitIdle(3));
        QCOMPARE(h.session->histogramMax(), 2);
        int important = 0;
        for (int i = 0; i < h.session->histogram()->count(); ++i)
            important += h.session->histogram()->get(i).value("important").toInt();
        QCOMPARE(important, 2);
    }

    // Feedback: the level filter needs no chip — picking the active level again
    // turns it off, picking another level switches.
    void pickingTheActiveLevelAgainClearsIt()
    {
        Harness h;
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        h.session->applyLevelFilter("ERROR");
        QVERIFY(h.settle());
        QCOMPARE(h.session->logs()->rowCount(), 2);
        QVERIFY(!h.session->histogramRangeOrPatternFilter());
        h.session->applyLevelFilter("WARN");
        QVERIFY(h.settle());
        QCOMPARE(h.session->activeLevel(), "WARN");
        h.session->applyLevelFilter("WARN");
        QVERIFY(h.settle());
        QVERIFY(!h.session->histogramFilterActive());
        QCOMPARE(h.session->logs()->rowCount(), 4);
        h.session->applyBucketFilter(0);
        QVERIFY(h.settle());
        QVERIFY(h.session->histogramRangeOrPatternFilter());
    }

    void modelsHonourTheModelContract()
    {
        Harness h;
        QAbstractItemModelTester t1(h.session->logs(), QAbstractItemModelTester::FailureReportingMode::QtTest);
        QAbstractItemModelTester t2(h.session->histogram(), QAbstractItemModelTester::FailureReportingMode::QtTest);
        QAbstractItemModelTester t3(h.session->facets(), QAbstractItemModelTester::FailureReportingMode::QtTest);
        QAbstractItemModelTester t4(h.session->chips(), QAbstractItemModelTester::FailureReportingMode::QtTest);
        h.scriptStartup(mixedLogs());
        h.session->start();
        QVERIFY(h.waitIdle(3));
        h.session->setSearchText("a AND b");
        h.session->applyBucketFilter(0);
        QVERIFY(h.settle());
        h.session->logs()->goToPage(3);
        h.session->setFacetFilterText("level:err");
        h.session->setPatternsEnabled(true);
        QVERIFY(h.settle());
        // Patterns are built over the WARN/ERROR entries of the filtered view;
        // every message there is unique.
        int problems = 0;
        for (int row = 0; row < h.session->logs()->rowCount(); ++row) {
            const QString level = h.session->logs()->data(h.session->logs()->index(row), LogListModel::LevelRole).toString();
            problems += level == "WARN" || level == "ERROR";
        }
        QCOMPARE(h.session->patterns()->count() + h.session->hiddenSinglePatterns(), problems);
    }

    void legacyMigrationMovesSecrets()
    {
        FakeHttpClient http;
        MemoryStore kv;
        kv.setValue("currentEnv", "PROD");
        kv.setValue("PROD/url", "https://prod-grafana");
        kv.setValue("PROD/uid", "prod-uid");
        kv.setValue("PROD/user", "bob");
        kv.setValue("PROD/pass", "secret");
        kv.setValue("PROD/ecotone/password", "db");
        MemorySecretStore secrets;
        AppServices services(http, kv, secrets, makeInlineParseExecutor());
        bool done = false;
        runLegacyMigration(services, [&](bool ok) { done = ok; });
        QVERIFY(done);
        QCOMPARE(secrets.values().value("env/prod/password"), "secret");
        QVERIFY(!kv.contains("PROD/pass"));
        QVERIFY(!kv.contains("PROD/ecotone/password"));
        QCOMPARE(services.environments().current().id, "prod");
        QCOMPARE(services.environments().current().user, "bob");
        QCOMPARE(kv.value(kSchemaKey).toInt(), kSettingsSchemaVersion);
    }
};

QTEST_GUILESS_MAIN(TestSession)
#include "tst_session.moc"
