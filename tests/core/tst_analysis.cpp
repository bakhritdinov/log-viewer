#include <QTest>

#include "core/features/Analysis.h"

using namespace lv;

namespace {
const QDateTime kT0 = QDateTime::fromString("2026-10-15T11:00:00Z", Qt::ISODate);

LogEntry entry(qint64 offsetMs, const QString& msg, Level level = Level::Info, QVariantMap fields = {})
{
    return { kT0.addMSecs(offsetMs), msg, std::move(fields), level };
}
} // namespace

class TestAnalysis : public QObject {
    Q_OBJECT

private slots:
    void histogramBuckets()
    {
        const LogEntries list = { entry(10000, "a", Level::Error), entry(20000, "b", Level::Warn),
                                  entry(70000, "c"), entry(200000, "d", Level::Unknown) };
        const auto b = aggregateHistogram(list, 60000);
        QCOMPARE(b.size(), 4);
        QCOMPARE(b[0].startMs, kT0.toMSecsSinceEpoch());
        QCOMPARE(b[0].counts[histogramLevelIndex(Level::Error)], 1);
        QCOMPARE(b[0].counts[histogramLevelIndex(Level::Warn)], 1);
        QCOMPARE(b[1].counts[histogramLevelIndex(Level::Info)], 1);
        QCOMPARE(b[2].total(), 0);
        QCOMPARE(b[3].counts[5], 1);   // unknown level
        QVERIFY(aggregateHistogram({}, 60000).isEmpty());
        QVERIFY(aggregateHistogram(list, 0).isEmpty());
    }

    void autoBucket_data()
    {
        QTest::addColumn<qint64>("rangeSeconds");
        QTest::addColumn<qint64>("expected");
        QTest::newRow("none") << qint64(0) << qint64(60000);
        QTest::newRow("1m") << qint64(60) << qint64(1000);
        QTest::newRow("5m") << qint64(300) << qint64(5000);
        QTest::newRow("15m") << qint64(900) << qint64(15000);
        QTest::newRow("30m") << qint64(1800) << qint64(30000);
        QTest::newRow("1h") << qint64(3600) << qint64(60000);
        QTest::newRow("3h") << qint64(10800) << qint64(300000);
        QTest::newRow("6h") << qint64(21600) << qint64(900000);
        QTest::newRow("24h") << qint64(86400) << qint64(1800000);
        QTest::newRow("2d") << qint64(172800) << qint64(3600000);
        QTest::newRow("7d") << qint64(604800) << qint64(21600000);
        QTest::newRow("90d") << qint64(7776000) << qint64(86400000);
    }
    void autoBucket()
    {
        QFETCH(qint64, rangeSeconds);
        QFETCH(qint64, expected);
        QCOMPARE(autoBucketMs(rangeSeconds), expected);
    }

    void facets()
    {
        const LogEntries list = {
            entry(0, "a", Level::Info, { { "service", "api" }, { "order_id", 48213 }, { "empty", "" }, { "message", "x" } }),
            entry(1, "b", Level::Info, { { "service", "api" }, { "ratio", 0.5 } }),
            entry(2, "c", Level::Info, { { "service", "gw" } }),
        };
        const FieldValueCounts f = computeFacets(list);
        QCOMPARE(f.value("service").value("api"), 2);
        QCOMPARE(f.value("service").value("gw"), 1);
        QCOMPARE(f.value("order_id").value("48213"), 1);
        QCOMPARE(f.value("ratio").value("0.5"), 1);
        QVERIFY(!f.contains("empty"));
        QVERIFY(!f.contains("message"));
    }
    // Feedback: fields holding free text (multi-line, very long) are not offered as filters.
    void facetsLeaveOutFreeText()
    {
        const LogEntries list{
            entry(0, "a", Level::Error, { { "service", "api" }, { "error_detail", "short" }, { "body", "ok" } }),
            entry(1, "b", Level::Error, { { "service", "api" }, { "error_detail", "line one\nline two" },
                                          { "body", QString(201, QLatin1Char('x')) } }),
            entry(2, "c", Level::Error, { { "service", "gw" }, { "error_detail", "short" }, { "body", "ok" } }),
        };
        const FieldValueCounts f = computeFacets(list);
        QCOMPARE(f.value("service").value("api"), 2);
        QVERIFY(!f.contains("error_detail"));
        QVERIFY(!f.contains("body"));
    }
    // One long URL among many short ones does not hide the field; the long value
    // itself is not offered.
    void facetsKeepAFieldWithARareLongValue()
    {
        LogEntries list;
        for (int i = 0; i < 20; ++i)
            list << entry(i, "m", Level::Info, { { "url", "/api/orders" } });
        const QString longUrl = "/api/search?q=" + QString(300, QLatin1Char('x'));
        list << entry(20, "m", Level::Info, { { "url", longUrl } });
        const FieldValueCounts f = computeFacets(list);
        QCOMPARE(f.value("url").value("/api/orders"), 20);
        QVERIFY(!f.value("url").contains(longUrl));
    }

    void templateMessage_data()
    {
        QTest::addColumn<QString>("message");
        QTest::addColumn<QString>("expected");
        QTest::addColumn<QStringList>("values");
        QTest::newRow("numbers") << "payment failed after 30004 ms, order_id=48213"
                                 << "payment failed after * ms, order_id=*" << QStringList{ "30004", "48213" };
        QTest::newRow("decimal") << "took 12.5s" << "took *s" << QStringList{ "12.5" };
        QTest::newRow("uuid") << "user 3f2b8c1e-9a4d-4e2b-8f61-0c9d2e7a5b13 logged in"
                              << "user * logged in" << QStringList{ "3f2b8c1e-9a4d-4e2b-8f61-0c9d2e7a5b13" };
        QTest::newRow("timestamp") << "since 2026-10-15T11:58:42.318Z ok" << "since * ok"
                                   << QStringList{ "2026-10-15T11:58:42.318Z" };
        QTest::newRow("ip and port") << "connect 10.0.12.7:5432 refused" << "connect * refused" << QStringList{ "10.0.12.7:5432" };
        QTest::newRow("hex id") << "trace 4f1c9a7e2bd03 done" << "trace * done" << QStringList{ "4f1c9a7e2bd03" };
        QTest::newRow("word with digits stays") << "POST /v1/charge 200" << "POST /v1/charge *" << QStringList{ "200" };
        QTest::newRow("hex-looking word stays") << "deadbeef failed" << "deadbeef failed" << QStringList{};
        QTest::newRow("no variables") << "health check ok" << "health check ok" << QStringList{};
    }
    void templateMessage()
    {
        QFETCH(QString, message);
        QFETCH(QString, expected);
        QFETCH(QStringList, values);
        const Templated t = lv::templateMessage(message);
        QCOMPARE(t.templateText, expected);
        QCOMPARE(t.values, values);
    }

    void patternsGroupAndRank()
    {
        LogEntries list;
        for (int i = 0; i < 5; ++i) list << entry(i * 1000, QStringLiteral("timeout after %1 ms").arg(30000 + i), Level::Error);
        for (int i = 0; i < 3; ++i) list << entry(i * 1000, QStringLiteral("GET /x %1").arg(200 + i));
        list << entry(9000, "timeout after 1 ms", Level::Warn);   // same text, other level: own group
        const auto p = extractPatterns(list, { 4, 3 });
        QCOMPARE(p.size(), 3);
        QCOMPARE(p[0].templateText, "timeout after * ms");
        QCOMPARE(p[0].level, Level::Error);
        QCOMPARE(p[0].count, 5);
        QCOMPARE(p[0].examples.size(), 1);
        QCOMPARE(p[0].examples[0], (QStringList{ "30000", "30001", "30002" }));   // capped at 3
        QCOMPARE(p[0].firstSeen, kT0);
        QCOMPARE(p[0].lastSeen, kT0.addSecs(4));
        QCOMPARE(p[0].trend.size(), 4);
        int trendTotal = 0;
        for (int c : p[0].trend) trendTotal += c;
        QCOMPARE(trendTotal, 5);
        QCOMPARE(p[1].count, 3);
        QCOMPARE(p[2].level, Level::Warn);
        QVERIFY(extractPatterns({}).isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestAnalysis)
#include "tst_analysis.moc"
