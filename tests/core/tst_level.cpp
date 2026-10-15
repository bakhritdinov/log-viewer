#include <QTest>

#include "core/domain/Level.h"

using namespace lv;

Q_DECLARE_METATYPE(lv::Level)

class TestLevel : public QObject {
    Q_OBJECT

private slots:
    void fromString_data()
    {
        QTest::addColumn<QString>("raw");
        QTest::addColumn<Level>("expected");
        for (const char* s : { "err", "ERROR", "Fatal", "crit", "critical", "panic" })
            QTest::newRow(s) << QString::fromLatin1(s) << Level::Error;
        for (const char* s : { "warn", "WARNING" })
            QTest::newRow(s) << QString::fromLatin1(s) << Level::Warn;
        for (const char* s : { "info", "Notice", "information" })
            QTest::newRow(s) << QString::fromLatin1(s) << Level::Info;
        for (const char* s : { "debug", "DBG" })
            QTest::newRow(s) << QString::fromLatin1(s) << Level::Debug;
        QTest::newRow("trace") << "trace" << Level::Trace;
        QTest::newRow("padded") << "  warn \t" << Level::Warn;
        QTest::newRow("unknown") << "verbose" << Level::Unknown;
        QTest::newRow("empty") << "" << Level::Unknown;
    }
    void fromString()
    {
        QFETCH(QString, raw);
        QFETCH(Level, expected);
        QCOMPARE(levelFromString(raw), expected);
    }

    void nameRoundTrip()
    {
        for (Level l : { Level::Trace, Level::Debug, Level::Info, Level::Warn, Level::Error }) {
            QVERIFY(!levelName(l).isEmpty());
            QCOMPARE(levelFromName(levelName(l)), l);
            // Every synonym normalizes back to the same bucket.
            for (const QString& s : levelSynonyms(l)) QCOMPARE(levelFromString(s), l);
        }
        QCOMPARE(levelName(Level::Unknown), QString());
        QCOMPARE(levelFromName(u"error"), Level::Unknown);   // names are exact
        QCOMPARE(levelFromName(u"FATAL"), Level::Unknown);
    }

    void fromFields()
    {
        QCOMPARE(levelFromFields({ { "severity", "ERROR" } }), Level::Error);
        QCOMPARE(levelFromFields({ { "level", "info" }, { "severity", "error" } }), Level::Info);
        QCOMPARE(levelFromFields({ { "level", "verbose" }, { "lvl", "dbg" } }), Level::Debug);
        QCOMPARE(levelFromFields({ { "msg", "x" } }), Level::Unknown);
        QCOMPARE(levelFieldNames().first(), QStringLiteral("level"));
    }
};

QTEST_GUILESS_MAIN(TestLevel)
#include "tst_level.moc"
