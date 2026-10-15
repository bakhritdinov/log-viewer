#include <QSignalSpy>
#include <QTest>

#include "core/features/ChainedLoader.h"
#include "support/FakeHttp.h"

using namespace lv;
using namespace lvtest;

Q_DECLARE_METATYPE(lv::RequestError)

namespace {

const QDateTime kNow = QDateTime::fromString("2026-10-15T12:00:00Z", Qt::ISODate);
const qint64 kNowMs = kNow.toMSecsSinceEpoch();

SearchSpec spec()
{
    SearchSpec s;
    s.connection = { QUrl("https://g"), "uid", "u", "p", {} };
    s.stream = { "_namespace", "ns", "_appName", "app" };
    s.query = Query::parse(u"timeout");
    return s;
}

QString exprOf(const HttpRequest& r)
{
    return jsonBody(r).value("queries").toArray().first().toObject().value("expr").toString();
}

struct Fixture {
    FakeHttpClient http;
    std::unique_ptr<ParseExecutor> parser = makeInlineParseExecutor();
    LogStore store;
    ChainedLoader loader{ http, *parser, store, {}, [] { return kNow; } };
    QSignalSpy finished{ &loader, &ChainedLoader::finished };
    QSignalSpy failed{ &loader, &ChainedLoader::failed };
};

} // namespace

class TestChainedLoader : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() { qRegisterMetaType<lv::RequestError>(); }

    void shortBatchFinishes()
    {
        Fixture f;
        f.http.script(ok(logsBody(kNowMs - 1000, 3)));
        f.loader.start(spec(), TimeRange::fromKey(u"1h"));
        QVERIFY(f.loader.isLoading());
        QVERIFY(f.finished.wait(1000));
        QCOMPARE(f.finished.first().first().toBool(), false);
        QVERIFY(!f.loader.isLoading());
        QCOMPARE(f.store.size(), 3);
        QCOMPARE(f.http.requests.size(), 1);
        const HttpRequest& r = f.http.requests.first();
        QCOMPARE(exprOf(r), QStringLiteral(
            "{_namespace=\"ns\", _appName=\"app\"} _time:[2026-10-15T11:00:00.000Z, 2026-10-15T12:00:00.000Z] ~\"(?i)timeout\""));
        QCOMPARE(jsonBody(r).value("from").toString(), QString::number(kNowMs - 3600000));
        QCOMPARE(jsonBody(r).value("to").toString(), QString::number(kNowMs));
    }

    void walksBackFromOldestOfEachBatch()
    {
        Fixture f;
        f.http.script(ok(logsBody(kNowMs, kBatchLimit, 10, "a")));            // oldest: now - 9990 ms
        f.http.script(ok(logsBody(kNowMs - 9990, kBatchLimit, 10, "b")));     // overlaps one ms, new texts
        f.http.script(ok(logsBody(kNowMs - 20000, 10, 10, "c")));
        f.loader.start(spec(), TimeRange::fromKey(u"1h"));
        QVERIFY(f.finished.wait(2000));
        QCOMPARE(f.http.requests.size(), 3);
        QVERIFY(exprOf(f.http.requests[1]).contains("2026-10-15T11:59:50.010Z]"));
        QCOMPARE(jsonBody(f.http.requests[1]).value("to").toString(), QString::number(kNowMs - 9990));
        QCOMPARE(f.store.size(), 2 * kBatchLimit + 10);
        QCOMPARE(f.finished.first().first().toBool(), false);
    }

    void stopsAtSoftCapAndLoadsMore()
    {
        Fixture f;
        for (int i = 0; i < 5; ++i)
            f.http.script(ok(logsBody(kNowMs - i * 20000, kBatchLimit, 10, QStringLiteral("p%1-").arg(i))));
        f.loader.start(spec(), TimeRange::fromKey(u"1h"));
        QVERIFY(f.finished.wait(3000));
        QCOMPARE(f.store.size(), ChainedLoader::kStep);
        QCOMPARE(f.finished.first().first().toBool(), true);
        QVERIFY(f.loader.hasMore());
        QCOMPARE(f.http.requests.size(), 5);

        f.http.script(ok(logsBody(kNowMs - 100000, 7)));
        f.loader.loadMore();
        QVERIFY(f.finished.wait(1000));
        QCOMPARE(f.http.requests.size(), 6);
        QCOMPARE(f.store.size(), ChainedLoader::kStep + 7);
        QVERIFY(!f.loader.hasMore());
    }

    void loadMoreWithoutMoreIsANoOp()
    {
        Fixture f;
        f.http.script(ok(logsBody(kNowMs, 2)));
        f.loader.start(spec(), TimeRange::fromKey(u"1h"));
        QVERIFY(f.finished.wait(1000));
        f.loader.loadMore();
        QCOMPARE(f.http.requests.size(), 1);
        QVERIFY(!f.loader.isLoading());
    }

    void allDuplicateBatchStops()
    {
        Fixture f;
        const QByteArray full = logsBody(kNowMs, kBatchLimit, 0, "same");   // all at the same ms
        f.http.script(ok(full));
        f.http.script(ok(full));
        f.loader.start(spec(), TimeRange::fromKey(u"1h"));
        QVERIFY(f.finished.wait(2000));
        QCOMPARE(f.http.requests.size(), 2);   // second batch brought nothing new
        QCOMPARE(f.finished.first().first().toBool(), false);
    }

    void emptyBatchStops()
    {
        Fixture f;
        f.http.script(ok(fixture("grafana/logs_empty.json")));
        f.loader.start(spec(), TimeRange::fromKey(u"1h"));
        QVERIFY(f.finished.wait(1000));
        QCOMPARE(f.store.size(), 0);
    }

    void cursorReachingWindowStartStops()
    {
        Fixture f;
        // A full batch whose oldest entry sits exactly on the window start.
        f.http.script(ok(logsBody(kNowMs - 3600000 + (kBatchLimit - 1) * 10, kBatchLimit, 10)));
        f.loader.start(spec(), TimeRange::fromKey(u"1h"));
        QVERIFY(f.finished.wait(1000));
        QCOMPARE(f.http.requests.size(), 1);
    }

    void httpErrorFails()
    {
        Fixture f;
        f.http.script(status(401));
        f.loader.start(spec(), TimeRange::fromKey(u"1h"));
        QVERIFY(f.failed.wait(1000));
        QCOMPARE(f.failed.first().first().value<RequestError>().kind, RequestError::Kind::Unauthorized);
        QVERIFY(!f.loader.isLoading());
        QCOMPARE(f.finished.count(), 0);
    }

    void datasourceErrorFails()
    {
        Fixture f;
        f.http.script(ok(fixture("grafana/logs_datasource_error.json")));
        f.loader.start(spec(), TimeRange::fromKey(u"1h"));
        QVERIFY(f.failed.wait(1000));
        QCOMPARE(f.failed.first().first().value<RequestError>().kind, RequestError::Kind::BadQuery);
    }

    void restartDropsStaleResponse()
    {
        Fixture f;
        f.http.script(std::nullopt);                          // first load hangs
        f.http.script(ok(logsBody(kNowMs, 2, 10, "new")));
        f.loader.start(spec(), TimeRange::fromKey(u"1h"));
        f.loader.start(spec(), TimeRange::fromKey(u"15m"));
        QVERIFY(f.finished.wait(1000));
        f.http.complete(0, ok(logsBody(kNowMs, 5, 10, "stale")));   // already aborted: ignored
        QTest::qWait(10);
        QCOMPARE(f.store.size(), 2);
        QCOMPARE(f.finished.count(), 1);
        QCOMPARE(f.failed.count(), 0);
    }

    void stopKeepsLoadedEntries()
    {
        Fixture f;
        f.http.script(ok(logsBody(kNowMs, kBatchLimit, 10, "a")));
        f.http.script(std::nullopt);
        QSignalSpy batches(&f.loader, &ChainedLoader::batchAdded);
        f.loader.start(spec(), TimeRange::fromKey(u"1h"));
        QVERIFY(batches.wait(1000));
        f.loader.stop();
        QVERIFY(!f.loader.isLoading());
        QCOMPARE(f.store.size(), kBatchLimit);
        QTest::qWait(10);
        QCOMPARE(f.failed.count(), 0);
    }

    void serverLevelGoesIntoQuery()
    {
        Fixture f;
        f.http.script(ok(logsBody(kNowMs, 1)));
        SearchSpec s = spec();
        s.serverLevel = Level::Error;
        f.loader.start(s, TimeRange::fromKey(u"1h"));
        QVERIFY(f.finished.wait(1000));
        QVERIFY(exprOf(f.http.requests.first()).contains("(level:~\"(?i)^(err|error|"));
    }

    void notConfigured()
    {
        Fixture f;
        f.loader.start(SearchSpec{}, TimeRange());
        QCOMPARE(f.failed.count(), 1);
        QCOMPARE(f.failed.first().first().value<RequestError>().kind, RequestError::Kind::NotConfigured);
        QVERIFY(f.http.requests.isEmpty());
    }

    void absoluteRangeUsesItsOwnBounds()
    {
        // Legacy bug: a past custom range intersected "last N seconds from now".
        Fixture f;
        f.http.script(ok(logsBody(kNowMs - 86400000, 1)));
        const auto range = TimeRange::absolute(kNow.addDays(-2), kNow.addDays(-1));
        f.loader.start(spec(), *range);
        QVERIFY(f.finished.wait(1000));
        QVERIFY(exprOf(f.http.requests.first()).contains("_time:[2026-10-13T12:00:00.000Z, 2026-10-14T12:00:00.000Z]"));
    }
};

QTEST_GUILESS_MAIN(TestChainedLoader)
#include "tst_chained_loader.moc"
