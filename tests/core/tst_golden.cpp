// The new query core against the legacy behaviour captured in
// tests/fixtures/characterization (see its README). Every golden case must
// match, except the intended changes listed there, which are asserted here with
// their new expected output.
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTest>

#include "core/domain/TimeRange.h"
#include "core/query/LogsQL.h"
#include "core/query/Query.h"

using namespace lv;

namespace {

QJsonArray loadCases(const QString& file)
{
    QFile f(QStringLiteral(LOGVIEWER_FIXTURES_DIR "/characterization/") + file);
    if (!f.open(QIODevice::ReadOnly)) qFatal("cannot open %s", qPrintable(f.fileName()));
    return QJsonDocument::fromJson(f.readAll()).object().value("cases").toArray();
}

QString selector(const QString& ns, const QString& app)
{
    return QStringLiteral("{_namespace=\"%1\", _appName=\"%2\"} _time:3600s offset 0s").arg(ns, app);
}

} // namespace

class TestGolden : public QObject {
    Q_OBJECT

private slots:
    void logsql_data()
    {
        // Intended change #1: label values are escaped.
        // Intended change #2: empty parts are skipped.
        const QHash<QString, QString> intended = {
            { "namespace with quote", selector("we\\\"ird", "a") },
            { "empty middle part", selector("prod-core", "billing-api") + " ~\"(?i)timeout\" ~\"(?i)retry\"" },
            { "trailing AND", selector("prod-core", "billing-api") + " ~\"(?i)timeout\"" },
        };
        // Intended change #14: ERROR also covers alert / emerg / emergency / severe.
        const auto widenErrorLevel = [](QString expr) {
            return expr.replace(QStringLiteral("|panic)$"), QStringLiteral("|panic|alert|emerg|emergency|severe)$"));
        };

        QTest::addColumn<QJsonObject>("input");
        QTest::addColumn<QString>("expected");
        for (const QJsonValue& v : loadCases("logsql.json")) {
            const QJsonObject c = v.toObject();
            const QString name = c.value("name").toString();
            const QString expected = intended.value(name, widenErrorLevel(c.value("expected").toString()));
            QTest::newRow(qPrintable(name)) << c.value("input").toObject() << expected;
        }
    }
    void logsql()
    {
        QFETCH(QJsonObject, input);
        QFETCH(QString, expected);
        LogsQLRequest r;
        r.stream = { input.value("nsLabel").toString(), input.value("namespace").toString(),
                     input.value("appLabel").toString(), input.value("app").toString() };
        r.query = Query::parse(input.value("query").toString());
        r.timeFilter = input.value("timeFilter").toString();
        if (input.value("levelServerSide").toBool())
            r.serverLevel = levelFromName(input.value("activeLevel").toString());
        QCOMPARE(buildLogsQL(r), expected);
    }

    void toggleFilter_data()
    {
        // Intended change #4: an unquoted spelling of the same filter is recognized.
        const QHash<QString, QString> intended = { { "unquoted existing is not matched", "" } };

        QTest::addColumn<QString>("searchText");
        QTest::addColumn<QString>("key");
        QTest::addColumn<QVariant>("value");
        QTest::addColumn<QString>("expected");
        for (const QJsonValue& v : loadCases("toggle_filter.json")) {
            const QJsonObject c = v.toObject();
            const QJsonObject in = c.value("input").toObject();
            const QString name = c.value("name").toString();
            QTest::newRow(qPrintable(name))
                << in.value("searchText").toString() << in.value("key").toString()
                << in.value("value").toVariant()
                << intended.value(name, c.value("expected").toString());
        }
    }
    void toggleFilter()
    {
        QFETCH(QString, searchText);
        QFETCH(QString, key);
        QFETCH(QVariant, value);
        QFETCH(QString, expected);
        const FieldFilter f{ key, formatFieldValue(value) };
        QCOMPARE(toggleFilterInText(searchText, f), expected);
    }

    void searchTerms_data()
    {
        QTest::addColumn<QString>("searchText");
        QTest::addColumn<QStringList>("expected");
        for (const QJsonValue& v : loadCases("search_terms.json")) {
            const QJsonObject c = v.toObject();
            const QString text = c.value("input").toObject().value("searchText").toString();
            QStringList expected;
            for (const QJsonValue& t : c.value("expected").toArray()) expected << t.toString();
            QTest::newRow(qPrintable(text.isEmpty() ? QStringLiteral("<empty>") : text)) << text << expected;
        }
    }
    void searchTerms()
    {
        QFETCH(QString, searchText);
        QFETCH(QStringList, expected);
        QCOMPARE(Query::parse(searchText).words(), expected);
    }

    void timeRange_data()
    {
        QTest::addColumn<QString>("key");
        QTest::addColumn<QString>("from");
        QTest::addColumn<QString>("to");
        QTest::addColumn<int>("expected");
        int i = 0;
        for (const QJsonValue& v : loadCases("time_range.json")) {
            const QJsonObject c = v.toObject();
            const QJsonObject in = c.value("input").toObject();
            QTest::newRow(qPrintable(QStringLiteral("%1 %2").arg(i++).arg(in.value("timeRange").toString())))
                << in.value("timeRange").toString() << in.value("customFrom").toString()
                << in.value("customTo").toString() << c.value("expected").toInt();
        }
    }
    void timeRange()
    {
        QFETCH(QString, key);
        QFETCH(QString, from);
        QFETCH(QString, to);
        QFETCH(int, expected);
        const QDateTime now = QDateTime::fromString("2026-10-15T12:00:00Z", Qt::ISODate);
        if (key != QLatin1String("Custom")) {
            QCOMPARE(TimeRange::fromKey(key).resolve(now).seconds(), qint64(expected));
            return;
        }
        const auto r = TimeRange::absolute(TimeRange::parseBound(from), TimeRange::parseBound(to));
        // Intended change #6: reversed or incomplete bounds are rejected instead
        // of silently becoming 24h (the legacy fallback, expected == 86400).
        if (expected == 86400) {
            QVERIFY(!r.has_value());
        } else {
            QVERIFY(r.has_value());
            QCOMPARE(r->resolve(now).seconds(), qint64(expected));
        }
    }
};

QTEST_GUILESS_MAIN(TestGolden)
#include "tst_golden.moc"
