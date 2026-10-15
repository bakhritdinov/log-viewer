// The new histogram must bucket exactly like the legacy LogModel::aggregateByLevel.
#include <QRandomGenerator>
#include <QTest>

#include "core/features/Analysis.h"
#include "logs/LogModel.h"

class TestHistogramVsLegacy : public QObject {
    Q_OBJECT

private slots:
    void sameBucketsOnRandomData_data()
    {
        QTest::addColumn<quint32>("seed");
        QTest::addColumn<qint64>("bucketMs");
        for (quint32 seed : { 1u, 7u, 42u, 1234u })
            for (qint64 bucket : { 60000LL, 300000LL, 3600000LL })
                QTest::newRow(qPrintable(QStringLiteral("seed %1 bucket %2").arg(seed).arg(bucket))) << seed << bucket;
    }
    void sameBucketsOnRandomData()
    {
        QFETCH(quint32, seed);
        QFETCH(qint64, bucketMs);
        QRandomGenerator rng(seed);
        static const QStringList rawLevels = { "error", "warn", "info", "debug", "trace", "verbose", "" };
        const QDateTime t0 = QDateTime::fromString("2026-10-15T08:00:00Z", Qt::ISODate);

        QList<LogEntry> legacy;
        lv::LogEntries fresh;
        for (int i = 0; i < 2000; ++i) {
            const QDateTime ts = t0.addMSecs(qint64(rng.bounded(4 * 3600)) * 1000 + rng.bounded(1000));
            const QString raw = rawLevels.at(int(rng.bounded(rawLevels.size())));
            const QVariantMap fields{ { "level", raw } };
            LogEntry l;
            l.timestamp = ts;
            l.message = QString::number(i);
            l.allFields = fields;
            l.level = LogModel::extractLevel(fields);
            legacy << l;
            fresh << lv::LogEntry{ ts, QString::number(i), fields, lv::levelFromFields(fields) };
        }

        LogModel model;
        model.setEntries(legacy);
        const QVariantList old = model.aggregateByLevel(bucketMs);
        const QList<lv::HistogramBucket> now = lv::aggregateHistogram(fresh, bucketMs);
        QCOMPARE(now.size(), old.size());
        static const char* keys[] = { "ERROR", "WARN", "INFO", "DEBUG", "TRACE", "EMPTY" };
        for (qsizetype i = 0; i < now.size(); ++i) {
            const QVariantMap row = old.at(i).toMap();
            QCOMPARE(now.at(i).startMs, row.value("tMs").toLongLong());
            for (int k = 0; k < 6; ++k) QCOMPARE(now.at(i).counts[k], row.value(keys[k]).toInt());
        }
    }
};

QTEST_GUILESS_MAIN(TestHistogramVsLegacy)
#include "tst_histogram_vs_legacy.moc"
