#include <QDateTime>
#include <QTest>

#include "core/query/LogsQL.h"
#include "core/query/Query.h"

using namespace lv;

namespace {
QueryTerm word(const QString& w) { return { QueryTerm::Kind::Word, w, {} }; }
QueryTerm filter(FieldFilter f) { return { QueryTerm::Kind::Filter, {}, std::move(f) }; }
} // namespace

Q_DECLARE_METATYPE(lv::FieldFilter)
Q_DECLARE_METATYPE(lv::QueryTerm)

class TestQuery : public QObject {
    Q_OBJECT

private slots:
    void parseTerm_data()
    {
        QTest::addColumn<QString>("part");
        QTest::addColumn<QueryTerm>("expected");
        QTest::newRow("word") << "timeout" << word("timeout");
        QTest::newRow("word trimmed") << "  timeout " << word("timeout");
        QTest::newRow("empty") << "  " << word("");
        QTest::newRow("star") << "*" << word("");
        QTest::newRow("plain filter") << "service:billing-api" << filter({ "service", "billing-api" });
        QTest::newRow("quoted") << "service:\"billing api\"" << filter({ "service", "billing api" });
        // Intended change #3: escaped quotes inside a quoted value survive.
        QTest::newRow("escaped quote") << "msg:\"say \\\"hi\\\"\"" << filter({ "msg", "say \"hi\"" });
        QTest::newRow("escaped backslash") << "path:\"C:\\\\tmp\"" << filter({ "path", "C:\\tmp" });
        QTest::newRow("regex") << "status:~5.." << filter({ "status", "5..", true });
        QTest::newRow("regex quoted") << "status:~\"5..\"" << filter({ "status", "5..", true });
        QTest::newRow("lone tilde is a value") << "op:~" << filter({ "op", "~" });
        QTest::newRow("exclude") << "-level:debug" << filter({ "level", "debug", false, true });
        QTest::newRow("exclude regex") << "-pod:~canary.*" << filter({ "pod", "canary.*", true, true });
        QTest::newRow("value with colons") << "url:http://h:8/x" << filter({ "url", "http://h:8/x" });
        QTest::newRow("leading colon is a word") << ":x" << word(":x");
        QTest::newRow("lone dash key is a word") << "-:x" << word("-:x");
    }
    void parseTerm()
    {
        QFETCH(QString, part);
        QFETCH(QueryTerm, expected);
        QCOMPARE(Query::parseTerm(part), expected);
    }

    void parseSplitsOnAnd()
    {
        const Query q = Query::parse(u"timeout and level:error AND * AND  AND -pod:x");
        QCOMPARE(q.terms().size(), 3);
        QCOMPARE(q.words(), QStringList{ "timeout" });
        QCOMPARE(q.filters().size(), 2);
        QVERIFY(q.filters().at(1).exclude);
        QVERIFY(Query::parse(u"").isEmpty());
        QVERIFY(Query::parse(u"*").isEmpty());
        // "AND" glued into a word is not a separator.
        QCOMPARE(Query::parse(u"BRAND").words(), QStringList{ "BRAND" });
    }

    void filterTextRoundTrip_data()
    {
        QTest::addColumn<FieldFilter>("f");
        QTest::newRow("plain") << FieldFilter{ "service", "billing-api" };
        QTest::newRow("regex") << FieldFilter{ "status", "5..", true };
        QTest::newRow("exclude") << FieldFilter{ "level", "debug", false, true };
        QTest::newRow("quotes and backslashes") << FieldFilter{ "msg", "a \"b\" \\c" };
        QTest::newRow("value with AND") << FieldFilter{ "msg", "x AND y" };
    }
    void filterTextRoundTrip()
    {
        QFETCH(FieldFilter, f);
        const QString text = f.toText();
        // A filter whose value contains " AND " cannot survive splitting; that
        // limitation of the text syntax is accepted (the UI uses chips).
        if (f.value.contains(QStringLiteral(" AND "))) {
            QVERIFY(Query::parse(text).terms().size() > 1);
            return;
        }
        QCOMPARE(Query::parseTerm(text), filter(f));
    }

    void toggleKeepsOtherParts()
    {
        const FieldFilter lvl{ "level", "error" };
        QCOMPARE(toggleFilterInText(u"a and b", lvl), QStringLiteral("a and b AND level:\"error\""));
        QCOMPARE(toggleFilterInText(u"a and level:error and b", lvl), QStringLiteral("a AND b"));
        // Include and exclude of the same value are different filters.
        const FieldFilter notLvl{ "level", "error", false, true };
        QCOMPARE(toggleFilterInText(u"level:\"error\"", notLvl),
                 QStringLiteral("level:\"error\" AND -level:\"error\""));
        QCOMPARE(toggleFilterInText(u"x AND -level:error", notLvl), QStringLiteral("x"));
    }

    void toggleIgnoresIncompleteFilter()
    {
        QCOMPARE(toggleFilterInText(u" timeout ", FieldFilter{ "", "x" }), QStringLiteral(" timeout "));
        QCOMPARE(toggleFilterInText(u"timeout", FieldFilter{ "level", "" }), QStringLiteral("timeout"));
    }

    void formatFieldValue_data()
    {
        QTest::addColumn<QVariant>("value");
        QTest::addColumn<QString>("expected");
        QTest::newRow("invalid") << QVariant() << "";
        QTest::newRow("string") << QVariant("abc") << "abc";
        QTest::newRow("int") << QVariant(48213) << "48213";
        QTest::newRow("longlong") << QVariant(qint64(1234567890123)) << "1234567890123";
        QTest::newRow("whole double") << QVariant(48213.0) << "48213";
        // Intended change #7: fractions are kept.
        QTest::newRow("fraction") << QVariant(3.7) << "3.7";
        QTest::newRow("small fraction") << QVariant(0.001) << "0.001";
        QTest::newRow("bool") << QVariant(true) << "true";
        QTest::newRow("datetime") << QVariant(QDateTime(QDate(2026, 10, 15), QTime(9, 0, 1, 5)))
                                  << "2026-10-15 09:00:01.005";
    }
    void formatFieldValue()
    {
        QFETCH(QVariant, value);
        QFETCH(QString, expected);
        QCOMPARE(lv::formatFieldValue(value), expected);
    }

    void buildExcludeAndRegex()
    {
        LogsQLRequest r;
        r.stream = { "ns", "a", "app", "b" };
        r.query = Query::parse(u"-pod:~canary.* AND msg:\"say \\\"hi\\\"\"");
        QCOMPARE(buildLogsQL(r), QStringLiteral("{ns=\"a\", app=\"b\"} -pod:~\"canary.*\" msg:\"say \\\"hi\\\"\""));
    }

    void timeWindowFilter()
    {
        QCOMPARE(lv::timeWindowFilter(3600, 1834), QStringLiteral("_time:3600s offset 1834s"));
    }
};

QTEST_GUILESS_MAIN(TestQuery)
#include "tst_query.moc"
