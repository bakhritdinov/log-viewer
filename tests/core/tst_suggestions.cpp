#include <QTest>

#include "core/query/Suggestions.h"

using namespace lv;

namespace {

FieldValueCounts facets()
{
    return {
        { "service", { { "billing-api", 3881 }, { "billing-gw", 1119 }, { "ledger-billing-sync", 12 } } },
        { "server_id", { { "a", 1 }, { "b", 1 } } },
        { "trace_id", { { "4f1c", 3 } } },
        { "level", { { "error", 1204 }, { "warn", 2017 } } },
    };
}

QStringList fields(const QList<Suggestion>& s)
{
    QStringList out;
    for (const Suggestion& x : s) out << x.field;
    return out;
}

QStringList values(const QList<Suggestion>& s)
{
    QStringList out;
    for (const Suggestion& x : s) out << x.value;
    return out;
}

} // namespace

class TestSuggestions : public QObject {
    Q_OBJECT

private slots:
    void fieldsByPrefixThenDistinctCount()
    {
        const auto s = suggest(u"serv", facets());
        QCOMPARE(fields(s), (QStringList{ "service", "server_id" }));
        QCOMPARE(s.first().kind, Suggestion::Kind::Field);
        QCOMPARE(s.first().count, 3);
        QCOMPARE(s.first().completedText, QStringLiteral("service:"));
    }

    void fieldSubstringRanksAfterPrefix()
    {
        QCOMPARE(fields(suggest(u"id", facets())), (QStringList{ "server_id", "trace_id" }));
    }

    void completesOnlyTheLastPart()
    {
        const auto s = suggest(u"timeout and lev", facets());
        QCOMPARE(s.size(), 1);
        QCOMPARE(s.first().completedText, QStringLiteral("timeout and level:"));
    }

    void valuesAfterColon()
    {
        const auto s = suggest(u"timeout AND service:bi", facets());
        QCOMPARE(values(s), (QStringList{ "billing-api", "billing-gw", "ledger-billing-sync" }));
        QCOMPARE(s.first().kind, Suggestion::Kind::Value);
        QCOMPARE(s.first().count, 3881);
        QCOMPARE(s.first().filter, (FieldFilter{ "service", "billing-api" }));
        QCOMPARE(s.first().completedText, QStringLiteral("timeout AND service:\"billing-api\""));
    }

    void valuesIgnoreQuotesAndTilde()
    {
        QCOMPARE(values(suggest(u"service:\"billing-g", facets())), QStringList{ "billing-gw" });
        QCOMPARE(values(suggest(u"service:~gw", facets())), QStringList{ "billing-gw" });
    }

    void excludePrefixCarriesThrough()
    {
        const auto f = suggest(u"-lev", facets());
        QCOMPARE(f.first().completedText, QStringLiteral("-level:"));
        const auto v = suggest(u"-level:err", facets());
        QCOMPARE(v.size(), 1);
        QVERIFY(v.first().filter.exclude);
        QCOMPARE(v.first().completedText, QStringLiteral("-level:\"error\""));
    }

    void emptyColonListsAllValuesByCount()
    {
        QCOMPARE(values(suggest(u"level:", facets())), (QStringList{ "warn", "error" }));
    }

    void nothingToSuggest()
    {
        QVERIFY(suggest(u"", facets()).isEmpty());
        QVERIFY(suggest(u"timeout AND ", facets()).isEmpty());
        QVERIFY(suggest(u"zzz", facets()).isEmpty());
        QVERIFY(suggest(u"unknown_field:x", facets()).isEmpty());
        QVERIFY(suggest(u"serv", {}).isEmpty());
    }

    void respectsLimit()
    {
        QCOMPARE(suggest(u"service:", facets(), 2).size(), 2);
    }
};

QTEST_GUILESS_MAIN(TestSuggestions)
#include "tst_suggestions.moc"
