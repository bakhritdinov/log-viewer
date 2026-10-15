// Characterization of the legacy LogModel (src/logs/LogModel.*).
// Expectations describe what the code does today, quirks included; quirks the
// rewrite intends to change are marked "QUIRK" and listed in
// tests/fixtures/characterization/README.md.
#include <QSignalSpy>
#include <QTest>

#include "logs/LogModel.h"

namespace {

const QDateTime kBase = QDateTime::fromString(QStringLiteral("2026-10-15T11:00:00Z"), Qt::ISODate);

LogEntry entry(qint64 offsetMs, const QString& level, const QString& message = QStringLiteral("m"))
{
    LogEntry e;
    e.timestamp = kBase.addMSecs(offsetMs);
    e.message = message;
    e.level = level;
    e.allFields = { { QStringLiteral("level"), level.toLower() } };
    return e;
}

QStringList messages(const LogModel& model)
{
    QStringList out;
    for (int i = 0; i < model.rowCount(); ++i)
        out << model.data(model.index(i), LogModel::MessageRole).toString();
    return out;
}

} // namespace

class TestLegacyLogModel : public QObject {
    Q_OBJECT

private slots:
    void normalizeLevel_data()
    {
        QTest::addColumn<QString>("raw");
        QTest::addColumn<QString>("expected");
        QTest::newRow("error") << "error" << "ERROR";
        QTest::newRow("err") << "ERR" << "ERROR";
        QTest::newRow("fatal") << "fatal" << "ERROR";
        QTest::newRow("crit") << "crit" << "ERROR";
        QTest::newRow("critical") << "Critical" << "ERROR";
        QTest::newRow("panic") << "panic" << "ERROR";
        QTest::newRow("warn") << "warn" << "WARN";
        QTest::newRow("warning") << "WARNING" << "WARN";
        QTest::newRow("info") << "info" << "INFO";
        QTest::newRow("notice") << "notice" << "INFO";
        QTest::newRow("information") << "information" << "INFO";
        QTest::newRow("debug") << "debug" << "DEBUG";
        QTest::newRow("dbg") << "dbg" << "DEBUG";
        QTest::newRow("trace") << "trace" << "TRACE";
        QTest::newRow("padded") << "  info  " << "INFO";
        QTest::newRow("unknown") << "verbose" << "";
        QTest::newRow("empty") << "" << "";
    }
    void normalizeLevel()
    {
        QFETCH(QString, raw);
        QFETCH(QString, expected);
        QCOMPARE(LogModel::normalizeLevel(raw), expected);
    }

    void extractLevel_data()
    {
        QTest::addColumn<QVariantMap>("fields");
        QTest::addColumn<QString>("expected");
        QTest::newRow("level") << QVariantMap{ { "level", "warn" } } << "WARN";
        QTest::newRow("severity") << QVariantMap{ { "severity", "ERROR" } } << "ERROR";
        QTest::newRow("lvl") << QVariantMap{ { "lvl", "dbg" } } << "DEBUG";
        QTest::newRow("loglevel") << QVariantMap{ { "loglevel", "info" } } << "INFO";
        QTest::newRow("log_level") << QVariantMap{ { "log_level", "trace" } } << "TRACE";
        // First key that normalizes wins, in the fixed key order.
        QTest::newRow("level beats severity") << QVariantMap{ { "level", "info" }, { "severity", "error" } } << "INFO";
        QTest::newRow("unknown level falls through") << QVariantMap{ { "level", "verbose" }, { "severity", "error" } } << "ERROR";
        QTest::newRow("none") << QVariantMap{ { "msg", "x" } } << "";
    }
    void extractLevel()
    {
        QFETCH(QVariantMap, fields);
        QFETCH(QString, expected);
        QCOMPARE(LogModel::extractLevel(fields), expected);
    }

    void formatValue_data()
    {
        QTest::addColumn<QVariant>("value");
        QTest::addColumn<QString>("expected");
        QTest::newRow("invalid") << QVariant() << "";
        QTest::newRow("string") << QVariant(QStringLiteral("abc")) << "abc";
        QTest::newRow("int") << QVariant(48213) << "48213";
        QTest::newRow("longlong") << QVariant(qint64(1234567890123)) << "1234567890123";
        QTest::newRow("bool true") << QVariant(true) << "true";
        QTest::newRow("bool false") << QVariant(false) << "false";
        // QUIRK: doubles lose their fraction.
        QTest::newRow("double rounds") << QVariant(3.7) << "4";
        QTest::newRow("datetime") << QVariant(kBase.toLocalTime()) << kBase.toLocalTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
    }
    void formatValue()
    {
        QFETCH(QVariant, value);
        QFETCH(QString, expected);
        LogModel model;
        QCOMPARE(model.formatValue(value), expected);
    }

    void entriesAreSortedNewestFirst()
    {
        LogModel model;
        model.setEntries({ entry(0, "INFO", "a"), entry(2000, "INFO", "c"), entry(1000, "INFO", "b") });
        QCOMPARE(messages(model), (QStringList{ "c", "b", "a" }));
        QCOMPARE(model.oldestTimestamp(), kBase.toMSecsSinceEpoch());
    }

    void appendMergesAndResorts()
    {
        LogModel model;
        model.setEntries({ entry(3000, "INFO", "d"), entry(2000, "INFO", "c") });
        model.appendEntries({ entry(1000, "INFO", "b"), entry(2500, "INFO", "x") });
        QCOMPARE(messages(model), (QStringList{ "d", "x", "c", "b" }));
        QCOMPARE(model.fullCount(), 4);
    }

    void appendKeepsDuplicates()
    {
        // QUIRK: overlapping batches are not de-duplicated.
        LogModel model;
        model.setEntries({ entry(1000, "INFO", "same") });
        model.appendEntries({ entry(1000, "INFO", "same") });
        QCOMPARE(model.fullCount(), 2);
    }

    void emptyModel()
    {
        LogModel model;
        QCOMPARE(model.rowCount(), 0);
        QCOMPARE(model.totalCount(), 0);
        QCOMPARE(model.oldestTimestamp(), 0);
        QVERIFY(model.aggregateByLevel(60000).isEmpty());
    }

    void pagingSlicesNewestFirst()
    {
        LogModel model;
        QList<LogEntry> list;
        for (int i = 0; i < 250; ++i) list << entry(i * 1000, "INFO", QString::number(i));
        model.setEntries(list);
        model.setPage(0, 100);
        QCOMPARE(model.rowCount(), 100);
        QCOMPARE(messages(model).first(), "249");
        model.setPage(2, 100);
        QCOMPARE(model.rowCount(), 50);
        QCOMPARE(messages(model).first(), "49");
        QCOMPARE(model.totalCount(), 250);
    }

    void pagePastEndResetsToFirst()
    {
        // QUIRK: an out-of-range page silently shows page 0.
        LogModel model;
        QList<LogEntry> list;
        for (int i = 0; i < 150; ++i) list << entry(i * 1000, "INFO", QString::number(i));
        model.setEntries(list);
        model.setPage(5, 100);
        QCOMPARE(messages(model).first(), "149");
    }

    void pageSizeZeroShowsAll()
    {
        LogModel model;
        model.setEntries({ entry(0, "INFO"), entry(1, "INFO"), entry(2, "INFO") });
        model.setPage(0, 0);
        QCOMPARE(model.rowCount(), 3);
    }

    void timeLevelFilter()
    {
        LogModel model;
        model.setEntries({ entry(0, "ERROR", "e0"), entry(30000, "INFO", "i30"),
                           entry(60000, "ERROR", "e60"), entry(90000, "ERROR", "e90") });
        const qint64 from = kBase.toMSecsSinceEpoch();
        // Window is [from, to): the entry exactly at `to` is excluded.
        model.applyTimeLevelFilter(from, from + 60000, QStringLiteral("ERROR"));
        QCOMPARE(messages(model), (QStringList{ "e0" }));
        QCOMPARE(model.totalCount(), 1);
        QCOMPARE(model.fullCount(), 4);
        QVERIFY(model.hasTimeLevelFilter());

        model.applyTimeLevelFilter(from, from + 60000, QString());
        QCOMPARE(messages(model), (QStringList{ "i30", "e0" }));

        model.clearTimeLevelFilter();
        QCOMPARE(model.totalCount(), 4);
        QVERIFY(!model.hasTimeLevelFilter());
    }

    void levelOnlyFilter()
    {
        LogModel model;
        model.setEntries({ entry(0, "ERROR", "e0"), entry(1000, "INFO", "i1"), entry(2000, "ERROR", "e2") });
        model.applyLevelFilter(QStringLiteral("ERROR"));
        QCOMPARE(messages(model), (QStringList{ "e2", "e0" }));
        QCOMPARE(model.filterLevel(), "ERROR");
        model.applyLevelFilter(QString());
        QVERIFY(!model.hasTimeLevelFilter());
        QCOMPARE(model.totalCount(), 3);
    }

    void aggregateByLevelAlignsBuckets()
    {
        LogModel model;
        // kBase is minute-aligned; entries at +10s, +20s (bucket 0), +70s (bucket 1), +200s (bucket 3).
        model.setEntries({ entry(10000, "ERROR"), entry(20000, "WARN"), entry(70000, "INFO"),
                           entry(200000, "VERBOSE") });
        const QVariantList rows = model.aggregateByLevel(60000);
        QCOMPARE(rows.size(), 4);
        const QVariantMap b0 = rows[0].toMap();
        QCOMPARE(b0.value("tMs").toLongLong(), kBase.toMSecsSinceEpoch());
        QCOMPARE(b0.value("ERROR").toInt(), 1);
        QCOMPARE(b0.value("WARN").toInt(), 1);
        QCOMPARE(rows[1].toMap().value("INFO").toInt(), 1);
        QCOMPARE(rows[2].toMap().value("INFO").toInt(), 0);
        // Unknown levels are counted as EMPTY.
        QCOMPARE(rows[3].toMap().value("EMPTY").toInt(), 1);
    }

    void aggregateIgnoresFilter()
    {
        // The histogram always shows the full loaded set, even while filtered.
        LogModel model;
        model.setEntries({ entry(0, "ERROR"), entry(1000, "INFO") });
        model.applyLevelFilter(QStringLiteral("ERROR"));
        const QVariantMap b0 = model.aggregateByLevel(60000).first().toMap();
        QCOMPARE(b0.value("INFO").toInt(), 1);
    }

    void aggregateRejectsNonPositiveBucket()
    {
        LogModel model;
        model.setEntries({ entry(0, "INFO") });
        QVERIFY(model.aggregateByLevel(0).isEmpty());
        QVERIFY(model.aggregateByLevel(-5).isEmpty());
    }

    void clearResets()
    {
        LogModel model;
        model.setEntries({ entry(0, "INFO") });
        QSignalSpy total(&model, &LogModel::totalCountChanged);
        model.clear();
        QCOMPARE(model.rowCount(), 0);
        QCOMPARE(model.fullCount(), 0);
        QVERIFY(total.count() >= 1);
    }

    void roles()
    {
        LogModel model;
        model.setEntries({ entry(1234, "INFO", "hello") });
        const QModelIndex i = model.index(0);
        QCOMPARE(model.data(i, LogModel::MessageRole).toString(), "hello");
        QCOMPARE(model.data(i, LogModel::RawTimestampRole).toLongLong(), kBase.toMSecsSinceEpoch() + 1234);
        QCOMPARE(model.data(i, LogModel::TimestampRole).toString(),
                 kBase.addMSecs(1234).toString("yyyy-MM-dd HH:mm:ss.zzz"));
        QCOMPARE(model.roleNames().value(LogModel::FieldsRole), QByteArray("fields"));
    }
};

QTEST_GUILESS_MAIN(TestLegacyLogModel)
#include "tst_legacy_logmodel.moc"
