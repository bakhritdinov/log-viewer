#include <QSignalSpy>
#include <QTest>

#include "core/features/Focus.h"
#include "core/features/LiveTail.h"
#include "support/FakeHttp.h"

using namespace lv;
using namespace lvtest;

Q_DECLARE_METATYPE(lv::RequestError)
Q_DECLARE_METATYPE(lv::LogEntries)

namespace {

const QDateTime kNow = QDateTime::fromString("2026-10-15T12:00:00Z", Qt::ISODate);
const qint64 kNowMs = kNow.toMSecsSinceEpoch();

SearchSpec spec()
{
    SearchSpec s;
    s.connection = { QUrl("https://g"), "uid", "u", "p", {} };
    s.stream = { "_namespace", "ns", "_appName", "app" };
    return s;
}

QString exprOf(const HttpRequest& r)
{
    return jsonBody(r).value("queries").toArray().first().toObject().value("expr").toString();
}

LogEntry entry(qint64 offsetMs, const QString& msg, QVariantMap fields = {})
{
    return { kNow.addMSecs(offsetMs), msg, std::move(fields), Level::Info };
}

} // namespace

class TestLiveTail : public QObject {
    Q_OBJECT

private slots:
    void initTestCase()
    {
        qRegisterMetaType<lv::RequestError>();
        qRegisterMetaType<lv::LogEntries>();
    }

    void pollsSinceCursorAndAdvances()
    {
        FakeHttpClient http;
        auto parser = makeInlineParseExecutor();
        LiveTail tail(http, *parser, {}, [] { return kNow; });
        tail.setIntervalMs(5);
        QSignalSpy arrived(&tail, &LiveTail::entriesArrived);
        http.script(ok(logsBody(kNowMs + 2000, 3)));
        http.script(ok(logsBody({})));
        http.script(std::nullopt);
        tail.start(spec(), kNow);
        QVERIFY(arrived.wait(1000));
        QCOMPARE(arrived.first().first().value<LogEntries>().size(), 3);
        QTRY_COMPARE_WITH_TIMEOUT(http.requests.size(), 3, 1000);
        QVERIFY(exprOf(http.requests[0]).contains("_time:>=2026-10-15T12:00:00.000Z"));
        QVERIFY(exprOf(http.requests[1]).contains("_time:>=2026-10-15T12:00:02.000Z"));   // newest seen
        tail.stop();
    }

    void fullBatchPollsImmediately()
    {
        FakeHttpClient http;
        auto parser = makeInlineParseExecutor();
        LiveTail tail(http, *parser, {}, [] { return kNow; });
        tail.setIntervalMs(60000);   // only a burst can trigger the second poll quickly
        http.script(ok(logsBody(kNowMs + 20000, kBatchLimit)));
        http.script(std::nullopt);
        tail.start(spec(), kNow);
        QTRY_COMPARE_WITH_TIMEOUT(http.requests.size(), 2, 1000);
        tail.stop();
    }

    void failureBacksOffAndRecovers()
    {
        FakeHttpClient http;
        auto parser = makeInlineParseExecutor();
        LiveTail tail(http, *parser, {}, [] { return kNow; });
        tail.setIntervalMs(5);
        QSignalSpy failed(&tail, &LiveTail::failed);
        QSignalSpy recovered(&tail, &LiveTail::recovered);
        http.script(status(502));
        http.script(status(502));
        http.script(ok(logsBody({})));
        http.script(std::nullopt);
        tail.start(spec(), kNow);
        QVERIFY(failed.wait(1000));
        QVERIFY(tail.isFailing());
        QCOMPARE(tail.currentDelayMs(), 10);
        QVERIFY(recovered.wait(1000));
        QCOMPARE(failed.count(), 1);   // reported once per outage
        QVERIFY(!tail.isFailing());
        QCOMPARE(failed.first().first().value<RequestError>().kind, RequestError::Kind::Server);
        tail.stop();
    }

    // One dropped connection is retried at once and never shown.
    void aSingleBlipIsNotReported()
    {
        FakeHttpClient http;
        auto parser = makeInlineParseExecutor();
        LiveTail tail(http, *parser, {}, [] { return kNow; });
        tail.setIntervalMs(5);
        QSignalSpy failed(&tail, &LiveTail::failed);
        http.script(failure(HttpResponse::Failure::RemoteClosed));
        http.script(ok(logsBody({})));
        http.script(std::nullopt);
        tail.start(spec(), kNow);
        QTRY_COMPARE(http.requests.size(), 3);
        QCOMPARE(failed.count(), 0);
        QVERIFY(!tail.isFailing());
        tail.stop();
    }

    void stopHaltsPolling()
    {
        FakeHttpClient http;
        auto parser = makeInlineParseExecutor();
        LiveTail tail(http, *parser, {}, [] { return kNow; });
        tail.setIntervalMs(5);
        http.script(ok(logsBody({})));
        tail.start(spec(), kNow);
        tail.stop();
        QVERIFY(!tail.isRunning());
        QTest::qWait(30);
        QCOMPARE(http.requests.size(), 1);
    }

    void bufferPauseCountsPending()
    {
        TailBuffer b(3);
        QCOMPARE(b.add({ entry(0, "a"), entry(1, "b") }), 2);
        b.setPaused(true);
        b.add({ entry(2, "c"), entry(1, "b") });
        QCOMPARE(b.pending(), 1);
        b.add({ entry(3, "d") });
        QCOMPARE(b.pending(), 2);
        QCOMPARE(b.store().size(), 3);                     // capacity kept
        QCOMPARE(b.store().all().first().message, "d");
        b.setPaused(false);
        QCOMPARE(b.pending(), 0);
    }

    void focusRequests()
    {
        SearchSpec base = spec();
        base.query = Query::parse(u"timeout AND level:error");
        base.serverLevel = Level::Error;
        const LogEntry anchor = entry(0, "x", { { "trace_id", "4f1c" } });

        const FocusRequest ctx = contextRequest(base, anchor, 60);
        QVERIFY(ctx.spec.query.isEmpty());
        QCOMPARE(ctx.spec.serverLevel, Level::Unknown);
        QCOMPARE(ctx.spec.stream, base.stream);
        QCOMPARE(ctx.range.resolve(kNow).from, kNow.addSecs(-60));
        QCOMPARE(ctx.range.resolve(kNow).to, kNow.addSecs(60));

        const FocusRequest tr = traceRequest(base, anchor);
        QCOMPARE(tr.spec.query.filters(), (QList<FieldFilter>{ { "trace_id", "4f1c" } }));
        QCOMPARE(tr.range.resolve(kNow).seconds(), qint64(600));

        QCOMPARE(traceIdOf(entry(0, "y", { { "traceId", "abc" } })), "abc");
        QCOMPARE(traceIdOf(entry(0, "z")), QString());
    }
};

QTEST_GUILESS_MAIN(TestLiveTail)
#include "tst_live_tail.moc"
