#include "app/Presenters.h"

#include <QCoreApplication>
#include <QLocale>
#include <QRegularExpression>
#include <algorithm>

namespace lv::presenters {

namespace {


QString localTime(qint64 ms, const QString& format)
{
    return QLocale().toString(QDateTime::fromMSecsSinceEpoch(ms).toLocalTime(), format);
}

} // namespace

// ── Chips ───────────────────────────────────────────────────────────────────

QByteArrayList chipRoles() { return { "text", "kind", "field", "value", "exclude", "regex" }; }

QString oneLineQuery(const QString& text)
{
    if (!text.contains(u'\n') && !text.contains(u'\r')) return text;
    static const QRegularExpression lineBreak(QStringLiteral("\\s*[\\r\\n]\\s*"));
    return text.trimmed().replace(lineBreak, QStringLiteral(" ↵ "));
}

QList<QVariantMap> chipRows(const QString& searchText)
{
    QList<QVariantMap> rows;
    const Query query = Query::parse(searchText);   // keep alive: terms() returns a reference
    for (const QueryTerm& t : query.terms()) {
        if (t.kind == QueryTerm::Kind::Word) {
            rows << QVariantMap{ { "text", oneLineQuery(t.word) }, { "kind", "word" }, { "field", QString() },
                                 { "value", t.word }, { "exclude", false }, { "regex", false } };
        } else {
            const FieldFilter& f = t.filter;
            rows << QVariantMap{ { "text", oneLineQuery(f.toText()) }, { "kind", "filter" }, { "field", f.field },
                                 { "value", f.value }, { "exclude", f.exclude }, { "regex", f.regex } };
        }
    }
    return rows;
}

// ── Suggestions ─────────────────────────────────────────────────────────────

QByteArrayList suggestionRoles() { return { "kind", "field", "value", "count", "completedText", "exclude" }; }

QList<QVariantMap> suggestionRows(const QList<Suggestion>& suggestions)
{
    QList<QVariantMap> rows;
    for (const Suggestion& s : suggestions) {
        rows << QVariantMap{ { "kind", s.kind == Suggestion::Kind::Field ? "field" : "value" },
                             { "field", s.field }, { "value", s.value }, { "count", s.count },
                             { "completedText", s.completedText }, { "exclude", s.filter.exclude } };
    }
    return rows;
}

// ── Histogram ───────────────────────────────────────────────────────────────

QByteArrayList histogramRoles()
{
    return { "startMs", "timeText", "error", "warn", "info", "debug", "trace", "other", "total", "important" };
}

QList<QVariantMap> histogramRows(const QList<HistogramBucket>& buckets, qint64 bucketMs)
{
    const QString format = bucketMs >= 86400000 ? QStringLiteral("dd MMM")
                         : bucketMs < 60000     ? QStringLiteral("HH:mm:ss")
                                                : QStringLiteral("HH:mm");
    QList<QVariantMap> rows;
    rows.reserve(buckets.size());
    for (const HistogramBucket& b : buckets) {
        rows << QVariantMap{ { "startMs", b.startMs }, { "timeText", localTime(b.startMs, format) },
                             { "error", b.counts[0] }, { "warn", b.counts[1] }, { "info", b.counts[2] },
                             { "debug", b.counts[3] }, { "trace", b.counts[4] }, { "other", b.counts[5] },
                             { "total", b.total() }, { "important", b.counts[0] + b.counts[1] } };
    }
    return rows;
}

QVariantMap levelTotals(const QList<HistogramBucket>& buckets)
{
    std::array<int, 6> sum{};
    for (const HistogramBucket& b : buckets)
        for (int i = 0; i < 6; ++i) sum[i] += b.counts[i];
    return { { "ERROR", sum[0] }, { "WARN", sum[1] }, { "INFO", sum[2] },
             { "DEBUG", sum[3] }, { "TRACE", sum[4] }, { "OTHER", sum[5] } };
}

// ── Facets ──────────────────────────────────────────────────────────────────

QByteArrayList facetRoles() { return { "field", "distinct", "total", "expanded", "values" }; }

QList<QVariantMap> facetRows(const FieldValueCounts& facets, const QString& filterText,
                             const QSet<QString>& expanded, const QList<FieldFilter>& activeFilters)
{
    const QString filter = filterText.trimmed().toLower();
    QString keyFilter = filter;
    QString valueFilter;
    bool twoD = false;
    if (const qsizetype colon = filter.indexOf(u':'); colon >= 0) {
        twoD = true;
        keyFilter = filter.left(colon).trimmed();
        valueFilter = filter.mid(colon + 1).trimmed();
    }

    QStringList fields = facets.keys();
    fields.sort(Qt::CaseInsensitive);
    QList<QVariantMap> rows;
    for (const QString& field : fields) {
        const QHash<QString, int>& counts = facets.value(field);
        const bool fieldMatches = keyFilter.isEmpty() || field.toLower().contains(keyFilter);
        QList<QPair<QString, int>> values;
        int total = 0;
        for (auto it = counts.cbegin(); it != counts.cend(); ++it) {
            total += it.value();
            const QString v = it.key().toLower();
            bool keep;
            if (twoD) keep = fieldMatches && (valueFilter.isEmpty() || v.contains(valueFilter));
            else keep = filter.isEmpty() || fieldMatches || v.contains(filter);
            if (keep) values.append({ it.key(), it.value() });
        }
        if (twoD ? (!fieldMatches || values.isEmpty()) : (!fieldMatches && values.isEmpty())) continue;
        std::sort(values.begin(), values.end(), [](const auto& a, const auto& b) {
            return a.second != b.second ? a.second > b.second : a.first < b.first;
        });
        if (values.size() > 50) values.resize(50);

        QVariantList valueRows;
        for (const auto& [value, count] : values) {
            const bool active = activeFilters.contains(FieldFilter{ field, value, false, false });
            const bool excluded = activeFilters.contains(FieldFilter{ field, value, false, true });
            valueRows << QVariantMap{ { "value", value }, { "count", count },
                                      { "share", total > 0 ? double(count) / total : 0.0 },
                                      { "active", active }, { "excluded", excluded } };
        }
        // A value search opens the fields where it found something.
        const bool open = expanded.contains(field) || (!filter.isEmpty() && !(fieldMatches && !twoD));
        rows << QVariantMap{ { "field", field }, { "distinct", int(counts.size()) }, { "total", total },
                             { "expanded", open }, { "values", valueRows } };
    }
    return rows;
}

// ── Patterns ────────────────────────────────────────────────────────────────

QByteArrayList patternRoles()
{
    return { "templateText", "templateParts", "firstLineParts", "moreLines", "level", "count", "share", "firstSeen", "lastSeen", "examples", "trend", "trendMax" };
}

QList<QVariantMap> patternRows(const QList<MessagePattern>& patterns)
{
    int maxCount = 0;
    for (const MessagePattern& p : patterns) maxCount = std::max(maxCount, p.count);
    QList<QVariantMap> rows;
    for (const MessagePattern& p : patterns) {
        QVariantList examples;
        for (const QStringList& slot : p.examples) examples << slot;
        QVariantList trend;
        int trendMax = 0;
        for (int c : p.trend) {
            trend << c;
            trendMax = std::max(trendMax, c);
        }
        // One-line views show the first line and how many more there are.
        const QStringList lines = p.templateText.split(QLatin1Char('\n'));
        rows << QVariantMap{ { "templateText", p.templateText }, { "templateParts", p.templateText.split(QLatin1Char('*')) },
                             { "firstLineParts", lines.first().split(QLatin1Char('*')) },
                             { "moreLines", int(lines.size()) - 1 },
                             { "level", levelName(p.level) },
                             { "count", p.count }, { "share", maxCount ? double(p.count) / maxCount : 0.0 },
                             { "firstSeen", p.firstSeen.toLocalTime().toString(QStringLiteral("HH:mm:ss")) },
                             { "lastSeen", p.lastSeen.toLocalTime().toString(QStringLiteral("HH:mm:ss")) },
                             { "examples", examples }, { "trend", trend }, { "trendMax", trendMax } };
    }
    return rows;
}

void sortPatterns(QList<MessagePattern>& patterns, const QString& order)
{
    auto byCount = [](const MessagePattern& a, const MessagePattern& b) { return a.count > b.count; };
    if (order == u"first") {
        std::stable_sort(patterns.begin(), patterns.end(),
                         [](const MessagePattern& a, const MessagePattern& b) { return a.firstSeen < b.firstSeen; });
    } else if (order == u"last") {
        std::stable_sort(patterns.begin(), patterns.end(),
                         [](const MessagePattern& a, const MessagePattern& b) { return a.lastSeen > b.lastSeen; });
    } else if (order == u"level") {
        // Level runs Unknown < Trace < … < Error: higher first, Unknown last.
        std::stable_sort(patterns.begin(), patterns.end(), [&](const MessagePattern& a, const MessagePattern& b) {
            if (a.level != b.level) return int(a.level) > int(b.level);
            return byCount(a, b);
        });
    } else {
        std::stable_sort(patterns.begin(), patterns.end(), byCount);
    }
}

// ── Source picker ───────────────────────────────────────────────────────────

namespace {

QVariantMap splitMatch(const QString& name, const QString& query)
{
    const qsizetype at = query.isEmpty() ? -1 : name.indexOf(query, 0, Qt::CaseInsensitive);
    if (at < 0) return { { "name", name }, { "pre", name }, { "hit", QString() }, { "post", QString() } };
    return { { "name", name }, { "pre", name.left(at) }, { "hit", name.mid(at, query.size()) },
             { "post", name.mid(at + query.size()) } };
}

} // namespace

QVariantList sourceMatches(const QMap<QString, QStringList>& appsByNamespace, const QString& rawQuery)
{
    const QString query = rawQuery.trimmed();
    QVariantList rows;
    for (auto it = appsByNamespace.cbegin(); it != appsByNamespace.cend(); ++it) {
        const bool nsMatches = it.key().contains(query, Qt::CaseInsensitive);
        QVariantList apps;
        for (const QString& app : it.value())
            if (nsMatches || app.contains(query, Qt::CaseInsensitive)) apps << splitMatch(app, query);
        if (!nsMatches && apps.isEmpty()) continue;
        QVariantMap row = splitMatch(it.key(), nsMatches ? query : QString());
        row.insert("appCount", int(it.value().size()));
        row.insert("apps", apps);
        rows << row;
    }
    return rows;
}

// ── Time helpers ────────────────────────────────────────────────────────────

QStringList histogramAxis(qint64 fromMs, qint64 toMs, int count)
{
    QStringList out;
    if (count <= 0 || toMs < fromMs) return out;
    const qint64 span = toMs - fromMs;
    const QString format = span >= 2 * 86400000LL ? QStringLiteral("dd MMM")
                         : span <= 600000         ? QStringLiteral("HH:mm:ss")
                                                  : QStringLiteral("HH:mm");
    if (span == 0) count = 1;
    for (int i = 0; i < count; ++i)
        out << localTime(count == 1 ? fromMs : fromMs + span * i / (count - 1), format);
    return out;
}

QString utcOffsetLabel(int offsetSeconds)
{
    const int minutes = std::abs(offsetSeconds) / 60;
    QString out = QStringLiteral("UTC%1%2").arg(offsetSeconds < 0 ? QStringLiteral("\u2212") : QStringLiteral("+")).arg(minutes / 60);
    if (minutes % 60) out += QStringLiteral(":%1").arg(minutes % 60, 2, 10, QLatin1Char('0'));
    return out;
}

QDate boundDate(const QString& boundText, const QDate& fallback)
{
    const QDateTime t = TimeRange::parseBound(boundText);
    return t.isValid() ? t.toLocalTime().date() : fallback;
}

QString boundOnDay(const QString& boundText, const QDate& day, bool endOfPeriod)
{
    const QDateTime t = TimeRange::parseBound(boundText);
    const QTime time = t.isValid() ? t.toLocalTime().time() : (endOfPeriod ? QTime(23, 59) : QTime(0, 0));
    return QDateTime(day, time).toString(QStringLiteral("yyyy-MM-dd HH:mm"));
}

// ── JSON colouring ──────────────────────────────────────────────────────────

QString jsonStyled(const QString& json, const JsonColors& colors)
{
    const auto colored = [](const QString& color, const QString& text) {
        const QString escaped = text.toHtmlEscaped().replace(u' ', QStringLiteral("&nbsp;"));
        return color.isEmpty() ? escaped : QStringLiteral("<font color=\"%1\">%2</font>").arg(color, escaped);
    };
    QString out;
    const qsizetype n = json.size();
    for (qsizetype i = 0; i < n;) {
        const QChar c = json.at(i);
        if (c == u'"') {
            qsizetype j = i + 1;
            while (j < n && json.at(j) != u'"') j += json.at(j) == u'\\' ? 2 : 1;
            j = std::min(j + 1, n);
            qsizetype k = j;
            while (k < n && json.at(k) == u' ') ++k;
            const bool isKey = k < n && json.at(k) == u':';
            out += colored(isKey ? colors.key : colors.string, json.mid(i, j - i));
            i = j;
        } else if (c == u'-' || c.isDigit()) {
            qsizetype j = i + 1;
            while (j < n && (json.at(j).isDigit() || QStringView(u".eE+-").contains(json.at(j)))) ++j;
            out += colored(colors.number, json.mid(i, j - i));
            i = j;
        } else if (c.isLetter()) {
            qsizetype j = i;
            while (j < n && json.at(j).isLetter()) ++j;
            const QString word = json.mid(i, j - i);
            out += colored(word == u"null" ? colors.null : colors.boolean, word);
            i = j;
        } else if (c == u'\n') {
            out += QStringLiteral("<br>");
            ++i;
        } else if (c == u' ') {
            out += QStringLiteral("&nbsp;");
            ++i;
        } else if (QStringView(u"{}[],:").contains(c)) {
            qsizetype j = i + 1;
            while (j < n && QStringView(u"{}[],:").contains(json.at(j))) ++j;
            out += colored(colors.punctuation, json.mid(i, j - i));
            i = j;
        } else {
            out += QString(c).toHtmlEscaped();
            ++i;
        }
    }
    return out;
}

// ── Messages in lists ───────────────────────────────────────────────────────

QString listMessage(const QString& message)
{
    const auto isBlank = [](QStringView line) { return line.trimmed().isEmpty(); };
    const auto indentOf = [](QStringView line) {
        qsizetype n = 0;
        while (n < line.size() && (line[n] == u' ' || line[n] == u'\t')) ++n;
        return n;
    };
    // The common case: nothing to tidy.
    if (!message.isEmpty() && !message.front().isSpace() && !message.back().isSpace() && !message.contains(u'\r')
        && !message.contains(QLatin1String("\n ")) && !message.contains(QLatin1String("\n\t")))
        return message;
    QList<QStringView> lines;
    for (QStringView line : QStringView(message).split(u'\n')) {
        if (line.endsWith(u'\r')) line.chop(1);
        lines.append(line);
    }
    while (!lines.isEmpty() && isBlank(lines.front())) lines.removeFirst();
    while (!lines.isEmpty() && isBlank(lines.back())) lines.removeLast();
    if (lines.isEmpty()) return {};
    qsizetype common = -1;
    for (QStringView line : lines)
        if (!isBlank(line)) common = common < 0 ? indentOf(line) : std::min(common, indentOf(line));
    QString out;
    out.reserve(message.size());
    for (qsizetype i = 0; i < lines.size(); ++i) {
        QStringView line = lines.at(i);
        line = isBlank(line) ? QStringView() : line.mid(common);
        if (i == 0) line = line.mid(indentOf(line));
        if (i > 0) out += u'\n';
        out += line;
    }
    return out;
}

// ── Highlighting ────────────────────────────────────────────────────────────

QString highlightStyled(const QString& text, const QStringList& terms, const QString& color)
{
    // Mark the matched ranges first, then escape each piece once.
    QList<std::pair<qsizetype, qsizetype>> ranges;
    for (const QString& term : terms) {
        if (term.isEmpty()) continue;
        for (qsizetype i = text.indexOf(term, 0, Qt::CaseInsensitive); i >= 0;
             i = text.indexOf(term, i + term.size(), Qt::CaseInsensitive))
            ranges.append({ i, i + term.size() });
    }
    std::sort(ranges.begin(), ranges.end());
    QString out;
    qsizetype pos = 0;
    for (auto [from, to] : ranges) {
        if (to <= pos) continue;
        from = std::max(from, pos);
        out += text.mid(pos, from - pos).toHtmlEscaped();
        out += QStringLiteral("<b><font color=\"%1\">%2</font></b>").arg(color, text.mid(from, to - from).toHtmlEscaped());
        pos = to;
    }
    out += text.mid(pos).toHtmlEscaped();
    return out;
}

// ── Environments / saved queries ────────────────────────────────────────────

QByteArrayList environmentRoles() { return { "id", "name", "color", "configured", "current", "host" }; }

QList<QVariantMap> environmentRows(const QList<Environment>& envs, const QString& currentId)
{
    QList<QVariantMap> rows;
    for (const Environment& e : envs) {
        rows << QVariantMap{ { "id", e.id }, { "name", e.name }, { "color", e.color },
                             { "configured", e.isConfigured() }, { "current", e.id == currentId },
                             { "host", e.url.host() } };
    }
    return rows;
}

QByteArrayList savedQueryRoles()
{
    return { "id", "name", "environmentId", "environmentName", "environmentColor", "namespaceName",
             "app", "searchText", "rangeKey", "summary" };
}

QList<QVariantMap> savedQueryRows(const QList<SavedQuery>& queries, const QList<Environment>& envs)
{
    QList<QVariantMap> rows;
    for (const SavedQuery& q : queries) {
        QString envName;
        QString envColor;
        for (const Environment& e : envs) {
            if (e.id != q.environmentId) continue;
            envName = e.name;
            envColor = e.color;
        }
        const QString search = q.searchText.trimmed().isEmpty() || q.searchText.trimmed() == u"*"
            ? QCoreApplication::translate("Presenters", "all entries") : q.searchText;
        rows << QVariantMap{ { "id", q.id }, { "name", q.name }, { "environmentId", q.environmentId },
                             { "environmentName", envName }, { "environmentColor", envColor },
                             { "namespaceName", q.namespaceName }, { "app", q.app },
                             { "searchText", q.searchText }, { "rangeKey", encodeTimeRange(q.range) },
                             { "summary", QStringLiteral("%1 · %2 · %3").arg(q.app, search, timeRangeShortLabel(q.range)) } };
    }
    return rows;
}

// ── Time range labels ───────────────────────────────────────────────────────

QString timeRangeLabel(const TimeRange& range)
{
    switch (range.kind()) {
        case TimeRange::Kind::Today: return QCoreApplication::translate("Presenters", "Today");
        case TimeRange::Kind::Yesterday: return QCoreApplication::translate("Presenters", "Yesterday");
        case TimeRange::Kind::Absolute: {
            const QDateTime from = range.absoluteFrom().toLocalTime();
            const QDateTime to = range.absoluteTo().toLocalTime();
            const QLocale l;
            if (from.date() == to.date())
                return QStringLiteral("%1 %2 → %3").arg(l.toString(from.date(), QStringLiteral("d MMM")),
                                                         from.toString(QStringLiteral("HH:mm")),
                                                         to.toString(QStringLiteral("HH:mm")));
            return QStringLiteral("%1 → %2").arg(l.toString(from, QStringLiteral("d MMM HH:mm")),
                                                 l.toString(to, QStringLiteral("d MMM HH:mm")));
        }
        case TimeRange::Kind::Relative: break;
    }
    const qint64 s = range.relativeSeconds();
    // Named counts: lupdate hangs on "int(s / 86400)" as the plural argument.
    const int days = int(s / 86400), hours = int(s / 3600), minutes = int(s / 60), seconds = int(s);
    if (s % 86400 == 0) return QCoreApplication::translate("Presenters", "Last %n day(s)", nullptr, days);
    if (s % 3600 == 0) return QCoreApplication::translate("Presenters", "Last %n hour(s)", nullptr, hours);
    if (s % 60 == 0) return QCoreApplication::translate("Presenters", "Last %n minute(s)", nullptr, minutes);
    return QCoreApplication::translate("Presenters", "Last %n second(s)", nullptr, seconds);
}

QString timeRangeShortLabel(const TimeRange& range)
{
    switch (range.kind()) {
        case TimeRange::Kind::Today: return QCoreApplication::translate("Presenters", "Today");
        case TimeRange::Kind::Yesterday: return QCoreApplication::translate("Presenters", "Yesterday");
        case TimeRange::Kind::Absolute:
            return QStringLiteral("%1–%2").arg(range.absoluteFrom().toLocalTime().toString(QStringLiteral("HH:mm")),
                                              range.absoluteTo().toLocalTime().toString(QStringLiteral("HH:mm")));
        case TimeRange::Kind::Relative: break;
    }
    const qint64 s = range.relativeSeconds();
    if (s % 86400 == 0) return QCoreApplication::translate("Presenters", "%1 d").arg(s / 86400);
    if (s % 3600 == 0) return QCoreApplication::translate("Presenters", "%1 h").arg(s / 3600);
    if (s % 60 == 0) return QCoreApplication::translate("Presenters", "%1 min").arg(s / 60);
    return QCoreApplication::translate("Presenters", "%1 s").arg(s);
}

} // namespace lv::presenters
