#include "core/query/Query.h"

#include <QDateTime>
#include <QLocale>
#include <cmath>
#include <QRegularExpression>

namespace lv {

namespace {

const QRegularExpression& andSeparator()
{
    static const QRegularExpression re(QStringLiteral(" AND "), QRegularExpression::CaseInsensitiveOption);
    return re;
}

QString quote(const QString& value)
{
    QString out = value;
    out.replace(QLatin1Char('\\'), QStringLiteral("\\\\"));
    out.replace(QLatin1Char('"'), QStringLiteral("\\\""));
    return QLatin1Char('"') + out + QLatin1Char('"');
}

// `"a \"b\""` → `a "b"`. Unquoted text keeps the legacy behaviour of dropping
// stray double quotes.
QString unquote(QStringView raw)
{
    const QStringView v = raw.trimmed();
    if (v.size() >= 2 && v.front() == u'"' && v.back() == u'"') {
        QString out;
        out.reserve(v.size() - 2);
        for (qsizetype i = 1; i < v.size() - 1; ++i) {
            const QChar c = v.at(i);
            if (c == u'\\' && i + 1 < v.size() - 1) {
                out.append(v.at(++i));
            } else {
                out.append(c);
            }
        }
        return out;
    }
    QString out = v.toString();
    out.remove(QLatin1Char('"'));
    return out.trimmed();
}

} // namespace

QString FieldFilter::toText() const
{
    return (exclude ? QStringLiteral("-") : QString()) + field
         + (regex ? QStringLiteral(":~") : QStringLiteral(":")) + quote(value);
}

QueryProblem checkQuery(QStringView text)
{
    for (const QString& raw : splitQueryParts(text)) {
        const QStringView part = QStringView(raw).trimmed();
        if (part.isEmpty() || part == u"*") continue;
        // Quotes: an unescaped " opens and closes a value.
        bool open = false;
        for (qsizetype i = 0; i < part.size(); ++i) {
            if (part.at(i) == u'\\') { ++i; continue; }
            if (part.at(i) == u'"') open = !open;
        }
        const QueryTerm term = Query::parseTerm(part);
        const QString field = term.kind == QueryTerm::Kind::Filter ? term.filter.field : QString();
        if (open) return { QueryProblem::Kind::UnclosedQuote, field };
        if (term.kind != QueryTerm::Kind::Filter) continue;
        const qsizetype colon = part.indexOf(u':');
        const QStringView value = part.sliced(colon + 1).trimmed();
        if (value.isEmpty() || value == u"~" || value == u"\"\"") return { QueryProblem::Kind::EmptyValue, field };
        if (term.filter.regex && !QRegularExpression(term.filter.value).isValid())
            return { QueryProblem::Kind::BadRegex, field };
    }
    return {};
}

QStringList splitQueryParts(QStringView text)
{
    return text.toString().split(andSeparator());
}

QueryTerm Query::parseTerm(QStringView raw)
{
    QueryTerm term;
    const QStringView part = raw.trimmed();
    if (part.isEmpty() || part == u"*") return term;   // empty word = nothing

    const qsizetype colon = part.indexOf(u':');
    QStringView key = colon > 0 ? part.first(colon).trimmed() : QStringView();
    bool exclude = false;
    if (key.startsWith(u'-')) {
        exclude = true;
        key = key.sliced(1).trimmed();
    }
    if (key.isEmpty()) {
        term.word = part.toString();
        return term;
    }

    QStringView value = part.sliced(colon + 1).trimmed();
    bool regex = false;
    if (value.size() > 1 && value.front() == u'~') {
        regex = true;
        value = value.sliced(1);
    }

    term.kind = QueryTerm::Kind::Filter;
    term.filter = { key.toString(), unquote(value), regex, exclude };
    return term;
}

Query Query::parse(QStringView text)
{
    Query q;
    for (const QString& part : splitQueryParts(text)) {
        const QueryTerm t = parseTerm(part);
        if (t.kind == QueryTerm::Kind::Word && t.word.isEmpty()) continue;
        q.m_terms.append(t);
    }
    return q;
}

QStringList Query::words() const
{
    QStringList out;
    for (const QueryTerm& t : m_terms) {
        if (t.kind == QueryTerm::Kind::Word) out << t.word;
    }
    return out;
}

QList<FieldFilter> Query::filters() const
{
    QList<FieldFilter> out;
    for (const QueryTerm& t : m_terms) {
        if (t.kind == QueryTerm::Kind::Filter) out << t.filter;
    }
    return out;
}

QString toggleFilterInText(QStringView text, const FieldFilter& filter)
{
    // A filter without a field or value is not a condition: leave the text as is.
    if (filter.field.isEmpty() || filter.value.isEmpty()) return text.toString();
    const QString trimmed = text.trimmed().toString();
    if (trimmed.isEmpty() || trimmed == QLatin1String("*")) return filter.toText();

    QStringList parts = splitQueryParts(trimmed);
    for (qsizetype i = 0; i < parts.size(); ++i) {
        const QueryTerm t = Query::parseTerm(parts.at(i));
        if (t.kind == QueryTerm::Kind::Filter && t.filter == filter) {
            parts.removeAt(i);
            return parts.join(QStringLiteral(" AND "));
        }
    }
    return trimmed + QStringLiteral(" AND ") + filter.toText();
}

QString removeQueryTerm(QStringView text, int termIndex)
{
    QStringList kept;
    int term = 0;
    for (const QString& part : splitQueryParts(text.trimmed())) {
        const QueryTerm t = Query::parseTerm(part);
        const bool isTerm = !(t.kind == QueryTerm::Kind::Word && t.word.isEmpty());
        if (isTerm && term++ == termIndex) continue;
        if (isTerm) kept << part.trimmed();
    }
    return kept.join(QStringLiteral(" AND "));
}

QString formatFieldValue(const QVariant& value)
{
    if (!value.isValid() || value.isNull()) return {};
    switch (value.typeId()) {
        case QMetaType::QDateTime:
            return value.toDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss.zzz"));
        case QMetaType::Bool:
            return value.toBool() ? QStringLiteral("true") : QStringLiteral("false");
        case QMetaType::Int:
        case QMetaType::UInt:
        case QMetaType::LongLong:
        case QMetaType::ULongLong:
            return QString::number(value.toLongLong());
        case QMetaType::Double:
        case QMetaType::Float: {
            // JSON numbers often arrive as doubles: print whole values without a
            // fraction or exponent (48213.0 → "48213"), others in the shortest
            // form that round-trips (3.7 → "3.7").
            const double d = value.toDouble();
            if (std::isfinite(d) && std::trunc(d) == d && std::fabs(d) < 9007199254740992.0)
                return QString::number(static_cast<qint64>(d));
            return QString::number(d, 'g', QLocale::FloatingPointShortest);
        }
        default:
            return value.toString();
    }
}

} // namespace lv
