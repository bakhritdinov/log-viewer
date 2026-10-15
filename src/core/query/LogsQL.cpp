#include "core/query/LogsQL.h"

namespace lv {

QString escapeLogsQL(QStringView value)
{
    QString out = value.toString();
    out.replace(QLatin1Char('\\'), QStringLiteral("\\\\"));
    out.replace(QLatin1Char('"'), QStringLiteral("\\\""));
    return out;
}

QString timeWindowFilter(qint64 windowSeconds, qint64 offsetSeconds)
{
    return QStringLiteral("_time:%1s offset %2s").arg(windowSeconds).arg(offsetSeconds);
}

QString levelFilterExpression(Level level)
{
    const QStringList synonyms = levelSynonyms(level);
    if (synonyms.isEmpty()) return {};
    const QString re = escapeLogsQL(QStringLiteral("(?i)^(%1)$").arg(synonyms.join(QLatin1Char('|'))));
    QStringList parts;
    for (const QString& field : levelFieldNames())
        parts << QStringLiteral("%1:~\"%2\"").arg(field, re);
    return QLatin1Char('(') + parts.join(QStringLiteral(" OR ")) + QLatin1Char(')');
}

QString buildLogsQL(const LogsQLRequest& request)
{
    const StreamSelector& s = request.stream;
    QString out = QStringLiteral("{%1=\"%2\", %3=\"%4\"}")
                      .arg(s.namespaceLabel, escapeLogsQL(s.namespaceValue),
                           s.appLabel, escapeLogsQL(s.appValue));

    if (!request.timeFilter.isEmpty()) out += QLatin1Char(' ') + request.timeFilter;

    const QString level = levelFilterExpression(request.serverLevel);
    if (!level.isEmpty()) out += QLatin1Char(' ') + level;

    for (const QueryTerm& t : request.query.terms()) {
        if (t.kind == QueryTerm::Kind::Word) {
            out += QStringLiteral(" ~\"(?i)%1\"").arg(escapeLogsQL(t.word));
            continue;
        }
        const FieldFilter& f = t.filter;
        out += QLatin1Char(' ');
        if (f.exclude) out += QLatin1Char('-');
        out += f.field + (f.regex ? QStringLiteral(":~\"") : QStringLiteral(":\""))
             + escapeLogsQL(f.value) + QLatin1Char('"');
    }
    return out;
}

} // namespace lv
