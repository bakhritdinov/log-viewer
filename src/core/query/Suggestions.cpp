#include "core/query/Suggestions.h"

#include <algorithm>

namespace lv {

namespace {

struct Split {
    QString head;   // everything before the part being typed, incl. trailing " AND "
    QString part;   // the part being typed, untrimmed
};

Split splitLastPart(QStringView text)
{
    const QString s = text.toString();
    const qsizetype at = s.lastIndexOf(QStringLiteral(" AND "), -1, Qt::CaseInsensitive);
    if (at < 0) return { QString(), s };
    return { s.left(at + 5), s.mid(at + 5) };
}

// Ranks `candidate` against `needle`: 0 = prefix match, 1 = substring, -1 = none.
int matchRank(const QString& candidate, const QString& needle)
{
    if (needle.isEmpty()) return 0;
    if (candidate.startsWith(needle, Qt::CaseInsensitive)) return 0;
    if (candidate.contains(needle, Qt::CaseInsensitive)) return 1;
    return -1;
}

struct Ranked {
    int rank;
    Suggestion s;
};

QList<Suggestion> topN(QList<Ranked> ranked, int limit)
{
    std::sort(ranked.begin(), ranked.end(), [](const Ranked& a, const Ranked& b) {
        if (a.rank != b.rank) return a.rank < b.rank;
        if (a.s.count != b.s.count) return a.s.count > b.s.count;
        return QString::compare(a.s.kind == Suggestion::Kind::Value ? a.s.value : a.s.field,
                                b.s.kind == Suggestion::Kind::Value ? b.s.value : b.s.field) < 0;
    });
    QList<Suggestion> out;
    for (const Ranked& r : ranked) {
        if (out.size() >= limit) break;
        out << r.s;
    }
    return out;
}

} // namespace

QList<Suggestion> suggest(QStringView searchText, const FieldValueCounts& facets, int limit)
{
    const Split split = splitLastPart(searchText);
    const QString part = split.part.trimmed();
    QList<Ranked> ranked;

    const qsizetype colon = part.indexOf(QLatin1Char(':'));
    if (colon > 0) {
        QString field = part.left(colon).trimmed();
        const bool exclude = field.startsWith(QLatin1Char('-'));
        if (exclude) field = field.mid(1);
        const auto values = facets.constFind(field);
        if (values == facets.constEnd()) return {};

        QString typed = part.mid(colon + 1).trimmed();
        if (typed.startsWith(QLatin1Char('~'))) typed = typed.mid(1);
        typed.remove(QLatin1Char('"'));

        for (auto it = values->cbegin(); it != values->cend(); ++it) {
            const int rank = matchRank(it.key(), typed);
            if (rank < 0) continue;
            Suggestion s;
            s.kind = Suggestion::Kind::Value;
            s.field = field;
            s.value = it.key();
            s.count = it.value();
            s.filter = { field, it.key(), false, exclude };
            s.completedText = split.head + s.filter.toText();
            ranked << Ranked{ rank, s };
        }
        return topN(ranked, limit);
    }

    if (part.isEmpty()) return {};
    const QString typed = part.startsWith(QLatin1Char('-')) ? part.mid(1) : part;
    const QString prefix = part.startsWith(QLatin1Char('-')) ? QStringLiteral("-") : QString();
    for (auto it = facets.cbegin(); it != facets.cend(); ++it) {
        const int rank = matchRank(it.key(), typed);
        if (rank < 0) continue;
        Suggestion s;
        s.kind = Suggestion::Kind::Field;
        s.field = it.key();
        s.count = static_cast<int>(it.value().size());
        s.completedText = split.head + prefix + it.key() + QLatin1Char(':');
        ranked << Ranked{ rank, s };
    }
    return topN(ranked, limit);
}

} // namespace lv
