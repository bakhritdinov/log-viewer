#include <QTest>

#include "core/domain/TimeRange.h"

using namespace lv;

class TestTimeRange : public QObject {
    Q_OBJECT

private slots:
    void keyRoundTrip_data()
    {
        QTest::addColumn<QString>("key");
        QTest::addColumn<qint64>("seconds");
        QTest::newRow("90s") << "90s" << qint64(90);
        QTest::newRow("5m") << "5m" << qint64(300);
        QTest::newRow("1h") << "1h" << qint64(3600);
        QTest::newRow("12h") << "12h" << qint64(43200);
        QTest::newRow("7d") << "7d" << qint64(604800);
    }
    void keyRoundTrip()
    {
        QFETCH(QString, key);
        QFETCH(qint64, seconds);
        const TimeRange r = TimeRange::fromKey(key);
        QCOMPARE(r.kind(), TimeRange::Kind::Relative);
        QCOMPARE(r.relativeSeconds(), seconds);
        QCOMPARE(r.key(), key);
    }

    void normalizesKeys()
    {
        QCOMPARE(TimeRange::fromKey(u"60m").key(), QStringLiteral("1h"));
        QCOMPARE(TimeRange::relative(120).key(), QStringLiteral("2m"));
        QCOMPARE(TimeRange::relative(0).key(), QStringLiteral("1h"));   // invalid → default
        QCOMPARE(TimeRange::fromKey(u"1w").key(), QStringLiteral("1h"));
        QCOMPARE(TimeRange::fromKey(u"").key(), QStringLiteral("1h"));
        QCOMPARE(TimeRange(), TimeRange::fromKey(u"1h"));
    }

    void relativeResolves()
    {
        const QDateTime now = QDateTime::fromString("2026-10-15T12:00:00Z", Qt::ISODate);
        const auto w = TimeRange::fromKey(u"15m").resolve(now);
        QCOMPARE(w.to, now);
        QCOMPARE(w.from, now.addSecs(-900));
    }

    void todayAndYesterdayUseLocalMidnight()
    {
        const QDateTime now(QDate(2026, 10, 15), QTime(9, 30));   // local time
        const auto today = TimeRange::today().resolve(now);
        QCOMPARE(today.from, QDateTime(QDate(2026, 10, 15), QTime(0, 0)));
        QCOMPARE(today.to, now);
        QCOMPARE(TimeRange::today().key(), QStringLiteral("today"));

        const auto yesterday = TimeRange::yesterday().resolve(now);
        QCOMPARE(yesterday.from, QDateTime(QDate(2026, 10, 14), QTime(0, 0)));
        QCOMPARE(yesterday.to, QDateTime(QDate(2026, 10, 15), QTime(0, 0)));
        QCOMPARE(TimeRange::fromKey(u"yesterday"), TimeRange::yesterday());
    }

    void absoluteValidation()
    {
        const QDateTime a = QDateTime::fromString("2026-10-15T09:00:00Z", Qt::ISODate);
        const QDateTime b = a.addSecs(3 * 3600);
        const auto ok = TimeRange::absolute(a, b);
        QVERIFY(ok.has_value());
        QCOMPARE(ok->kind(), TimeRange::Kind::Absolute);
        QCOMPARE(ok->key(), QString());
        QCOMPARE(ok->resolve(QDateTime::currentDateTimeUtc()).seconds(), qint64(10800));

        QVERIFY(!TimeRange::absolute(b, a).has_value());          // reversed
        QVERIFY(!TimeRange::absolute(a, a).has_value());          // empty
        QVERIFY(!TimeRange::absolute(QDateTime(), b).has_value()); // missing bound
    }

    void parseBound()
    {
        QCOMPARE(TimeRange::parseBound(u"2026-10-15T09:00:00Z"),
                 QDateTime(QDate(2026, 10, 15), QTime(9, 0), QTimeZone::UTC));
        QCOMPARE(TimeRange::parseBound(u"2026-10-15T09:00:00.250Z").time().msec(), 250);
        QCOMPARE(TimeRange::parseBound(u" 2026-10-15 09:30 "), QDateTime(QDate(2026, 10, 15), QTime(9, 30)));
        QCOMPARE(TimeRange::parseBound(u"2026-10-15 09:30:15"), QDateTime(QDate(2026, 10, 15), QTime(9, 30, 15)));
        QVERIFY(!TimeRange::parseBound(u"yesterday-ish").isValid());
    }
};

QTEST_GUILESS_MAIN(TestTimeRange)
#include "tst_timerange.moc"
