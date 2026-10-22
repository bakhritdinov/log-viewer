// Pure presentation helpers added for the designs: search highlighting,
// source picker matches, pattern ordering and the period-picker date helpers.
#include <QDateTime>
#include <QTest>

#include "app/Presenters.h"

using namespace lv;
using namespace lv::presenters;

namespace {
MessagePattern pattern(const QString& text, Level level, int count, qint64 firstMs)
{
    MessagePattern p;
    p.templateText = text;
    p.level = level;
    p.count = count;
    p.firstSeen = QDateTime::fromMSecsSinceEpoch(firstMs);
    p.lastSeen = QDateTime::fromMSecsSinceEpoch(firstMs + count * 10);
    return p;
}
}

class TestPresenters : public QObject {
    Q_OBJECT

private slots:
    // Feedback (broker-api): messages starting with a line break and deep
    // indentation showed as an empty row with "+5 lines".
    // Feedback: a multi-line search spread over the recent searches.
    void oneLineJoinsLines()
    {
        QCOMPARE(oneLine("level:error"), QString("level:error"));
        QCOMPARE(oneLine("msg:\"failed:\n{\n  \\\"code\\\" : 1\r\n}\"\n"),
                 QString("msg:\"failed: ↵ { ↵ \\\"code\\\" : 1 ↵ }\""));
    }
    void listMessageDropsLeadingBlanksAndIndentation()
    {
        QCOMPARE(listMessage("plain message"), QString("plain message"));
        QCOMPARE(listMessage("line one\nline two"), QString("line one\nline two"));
        QCOMPARE(listMessage("\n\n        Message sent to topic\n          partition: 3\n        offset: 42\n   \n"),
                 QString("Message sent to topic\n  partition: 3\noffset: 42"));
        QCOMPARE(listMessage("\r\n\t\tA\r\n\t\t\tB\r\n"), QString("A\n\tB"));
        QCOMPARE(listMessage("    first line indented\nsecond"), QString("first line indented\nsecond"));
        QCOMPARE(listMessage("a\n\n  b"), QString("a\n\n  b"));
        QCOMPARE(listMessage("   \n  \t "), QString());
        QCOMPARE(listMessage(""), QString());
    }
    // Feedback: the table showed only the first line of a multi-line message.
    void oneLineMessageKeepsEveryLine()
    {
        const QString msg = listMessage("RESPONSE\nStatus code = [200]\nBody = [{\n  \"pinfl\" : 1\n}]\n");
        QCOMPARE(oneLine(msg), QString("RESPONSE ↵ Status code = [200] ↵ Body = [{ ↵ \"pinfl\" : 1 ↵ }]"));
        QCOMPARE(moreLines(msg), 4);
        QCOMPARE(moreLines(listMessage("one line")), 0);
    }

    void highlightEscapesAndMarksEveryMatch()
    {
        QCOMPARE(highlightStyled("a <b> Timeout & timeout", { "timeout" }, "#e3b341"),
                 "a &lt;b&gt; <b><font color=\"#e3b341\">Timeout</font></b> &amp; "
                 "<b><font color=\"#e3b341\">timeout</font></b>");
        QCOMPARE(highlightStyled("plain", {}, "#fff"), "plain");
        QCOMPARE(highlightStyled("<x>", { "" }, "#fff"), "&lt;x&gt;");
    }

    void highlightMergesOverlaps()
    {
        // "time" and "timeout" overlap: the text is emitted once.
        const QString out = highlightStyled("timeout!", { "time", "timeout" }, "c");
        QCOMPARE(out, "<b><font color=\"c\">time</font></b><b><font color=\"c\">out</font></b>!");
    }

    void sourceMatchesByNamespaceOrApp()
    {
        const QMap<QString, QStringList> apps{ { "prod-core", { "billing-api", "payments" } },
                                               { "prod-edge", { "gateway" } } };
        QVariantList rows = sourceMatches(apps, "");
        QCOMPARE(rows.size(), 2);
        QCOMPARE(rows[0].toMap()["apps"].toList().size(), 2);
        QCOMPARE(rows[0].toMap()["appCount"].toInt(), 2);

        rows = sourceMatches(apps, "BILL");
        QCOMPARE(rows.size(), 1);
        const QVariantMap ns = rows[0].toMap();
        QCOMPARE(ns["name"].toString(), "prod-core");
        QCOMPARE(ns["hit"].toString(), "");          // matched through an app
        const QVariantMap app = ns["apps"].toList()[0].toMap();
        QCOMPARE(app["pre"].toString(), "");
        QCOMPARE(app["hit"].toString(), "bill");
        QCOMPARE(app["post"].toString(), "ing-api");
        QCOMPARE(ns["appCount"].toInt(), 2);         // the namespace still has two

        rows = sourceMatches(apps, "edge");
        QCOMPARE(rows.size(), 1);
        QCOMPARE(rows[0].toMap()["hit"].toString(), "edge");
        QCOMPARE(rows[0].toMap()["apps"].toList().size(), 1);   // all apps of a matching namespace

        QVERIFY(sourceMatches(apps, "nothing").isEmpty());
    }

    void sortPatternsOrders()
    {
        QList<MessagePattern> p{ pattern("info", Level::Info, 50, 3000),
                                 pattern("error", Level::Error, 10, 2000),
                                 pattern("unknown", Level::Unknown, 99, 1000),
                                 pattern("error2", Level::Error, 30, 4000) };
        sortPatterns(p, "count");
        QCOMPARE(p[0].templateText, "unknown");
        QCOMPARE(p[3].templateText, "error");
        sortPatterns(p, "first");
        QCOMPARE(p[0].templateText, "unknown");
        QCOMPARE(p[3].templateText, "error2");
        sortPatterns(p, "level");
        QCOMPARE(p[0].templateText, "error2");
        QCOMPARE(p[1].templateText, "error");
        QCOMPARE(p[2].templateText, "info");
        QCOMPARE(p[3].templateText, "unknown");
        sortPatterns(p, "last");                            // most recent first
        QCOMPARE(p[0].templateText, "error2");             // 4300
        QCOMPARE(p[1].templateText, "info");               // 3500
        QCOMPARE(p[2].templateText, "error");
        QCOMPARE(p[3].templateText, "unknown");
    }

    void patternRowsSplitTemplates()
    {
        const auto rows = patternRows({ pattern("took * ms for *", Level::Info, 1, 0) });
        QCOMPARE(rows[0]["templateParts"].toStringList(), QStringList({ "took ", " ms for ", "" }));
    }

    void multiLineTemplatesShowTheirFirstLine()
    {
        const auto rows = patternRows({ pattern("ERROR: * duplicate\nDETAIL: Key (*)\n  at *", Level::Error, 2, 0) });
        QCOMPARE(rows[0]["firstLineParts"].toStringList(), QStringList({ "ERROR: ", " duplicate" }));
        QCOMPARE(rows[0]["moreLines"].toInt(), 2);
        QCOMPARE(patternRows({ pattern("one line *", Level::Warn, 2, 0) })[0]["moreLines"].toInt(), 0);
        const auto crlf = patternRows({ pattern("ERROR: *\r\n  at *", Level::Error, 2, 0) });
        QCOMPARE(crlf[0]["firstLineParts"].toStringList(), QStringList({ "ERROR: ", "" }));
        QCOMPARE(crlf[0]["moreLines"].toInt(), 1);
    }


    void histogramAxisSpreadsLabels()
    {
        // Evenly spaced times over the span, not every n-th bucket.
        const qint64 from = QDateTime(QDate(2026, 10, 15), QTime(20, 7)).toMSecsSinceEpoch();
        QCOMPARE(histogramAxis(from, from + 4 * 3600000, 5), QStringList({ "20:07", "21:07", "22:07", "23:07", "00:07" }));
        // A short span shows seconds.
        QCOMPARE(histogramAxis(from, from + 300000, 5), QStringList({ "20:07:00", "20:08:15", "20:09:30", "20:10:45", "20:12:00" }));
        QCOMPARE(histogramAxis(from, from, 5), QStringList({ "20:07:00" }));
        QVERIFY(histogramAxis(from, from - 1, 5).isEmpty());
    }

    void utcOffsets()
    {
        QCOMPARE(utcOffsetLabel(5 * 3600), "UTC+5");
        QCOMPARE(utcOffsetLabel(0), "UTC+0");
        QCOMPARE(utcOffsetLabel(-(3 * 3600 + 30 * 60)), QString("UTC−3:30"));
    }

    void jsonIsColoured()
    {
        const JsonColors colors { "K", "S", "N", "B", "Z", "P" };
        const QString out = jsonStyled("{\n    \"a<b\": \"x & y\",\n    \"n\": -1.5e3,\n    \"ok\": true,\n    \"no\": null\n}", colors);
        QVERIFY(out.contains("<font color=\"K\">&quot;a&lt;b&quot;</font>"));               // key, escaped
        QVERIFY(out.contains("<font color=\"S\">&quot;x&nbsp;&amp;&nbsp;y&quot;</font>"));   // string value
        QVERIFY(out.contains("<font color=\"N\">-1.5e3</font>"));
        QVERIFY(out.contains("<font color=\"B\">true</font>"));
        QVERIFY(out.contains("<font color=\"Z\">null</font>"));
        QVERIFY(out.contains("<font color=\"P\">{</font>"));
        QVERIFY(out.contains("<font color=\"P\">,</font>"));
        QVERIFY(out.contains("<br>&nbsp;&nbsp;&nbsp;&nbsp;"));                         // indentation kept
        QVERIFY(!out.contains('\n'));
        // An escaped quote does not end the string.
        QVERIFY(jsonStyled("\"a\\\"b\"", colors).contains("<font color=\"S\">&quot;a\\&quot;b&quot;</font>"));
        // No colours: plain text.
        QCOMPARE(jsonStyled("[1]", {}), QString("[1]"));
    }

    void calendarBounds()
    {
        const QDate day(2026, 10, 3);
        QCOMPARE(boundOnDay("2026-10-15 09:30", day, false), "2026-10-03 09:30");
        QCOMPARE(boundOnDay("", day, false), "2026-10-03 00:00");
        QCOMPARE(boundOnDay("garbage", day, true), "2026-10-03 23:59");
        QCOMPARE(boundDate("2026-10-15 09:30", day), QDate(2026, 10, 15));
        QCOMPARE(boundDate("", day), day);
    }
};

QTEST_GUILESS_MAIN(TestPresenters)
#include "tst_presenters.moc"
