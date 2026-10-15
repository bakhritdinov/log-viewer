// Pure presentation helpers added for the designs: search highlighting,
// source picker matches, pattern ordering and the period-picker date helpers.
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
    return p;
}
}

class TestPresenters : public QObject {
    Q_OBJECT

private slots:
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
    }

    void patternRowsSplitTemplates()
    {
        const auto rows = patternRows({ pattern("took * ms for *", Level::Info, 1, 0) });
        QCOMPARE(rows[0]["templateParts"].toStringList(), QStringList({ "took ", " ms for ", "" }));
    }

    void histogramAxisSpreadsLabels()
    {
        QList<QVariantMap> rows;
        for (int i = 0; i < 9; ++i) rows << QVariantMap{ { "timeText", QString::number(i) } };
        QCOMPARE(histogramAxis(rows, 5), QStringList({ "0", "2", "4", "6", "8" }));
        QCOMPARE(histogramAxis(rows.mid(0, 2), 5), QStringList({ "0", "1" }));
        QCOMPARE(histogramAxis(rows.mid(0, 1), 5), QStringList({ "0" }));
        QVERIFY(histogramAxis({}, 5).isEmpty());
    }

    void utcOffsets()
    {
        QCOMPARE(utcOffsetLabel(5 * 3600), "UTC+5");
        QCOMPARE(utcOffsetLabel(0), "UTC+0");
        QCOMPARE(utcOffsetLabel(-(3 * 3600 + 30 * 60)), QString("UTC−3:30"));
    }

    void jsonIsColoured()
    {
        const QString out = jsonStyled("{\n    \"a<b\": \"x & y\",\n    \"n\": -1.5e3,\n    \"ok\": true\n}", "K", "S", "N");
        QVERIFY(out.contains("<font color=\"K\">&quot;a&lt;b&quot;</font>"));               // key, escaped
        QVERIFY(out.contains("<font color=\"S\">&quot;x&nbsp;&amp;&nbsp;y&quot;</font>"));   // string value
        QVERIFY(out.contains("<font color=\"N\">-1.5e3</font>"));
        QVERIFY(out.contains("<font color=\"N\">true</font>"));
        QVERIFY(out.contains("<br>&nbsp;&nbsp;&nbsp;&nbsp;"));                         // indentation kept
        QVERIFY(!out.contains('\n'));
        // An escaped quote does not end the string.
        QVERIFY(jsonStyled("\"a\\\"b\"", "K", "S", "N").contains("<font color=\"S\">&quot;a\\&quot;b&quot;</font>"));
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
