#include "app/Presenters.h"

#include <QCoreApplication>
#include <QLocale>
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

QList<QVariantMap> chipRows(const QString& searchText)
{
    QList<QVariantMap> rows;
    const Query query = Query::parse(searchText);   // keep alive: terms() returns a reference
    for (const QueryTerm& t : query.terms()) {
        if (t.kind == QueryTerm::Kind::Word) {
            rows << QVariantMap{ { "text", t.word }, { "kind", "word" }, { "field", QString() },
                                 { "value", t.word }, { "exclude", false }, { "regex", false } };
        } else {
            const FieldFilter& f = t.filter;
            rows << QVariantMap{ { "text", f.toText() }, { "kind", "filter" }, { "field", f.field },
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
    return { "startMs", "timeText", "error", "warn", "info", "debug", "trace", "other", "total" };
}

QList<QVariantMap> histogramRows(const QList<HistogramBucket>& buckets, qint64 bucketMs)
{
    const QString format = bucketMs >= 86400000 ? QStringLiteral("dd MMM") : QStringLiteral("HH:mm");
    QList<QVariantMap> rows;
    rows.reserve(buckets.size());
    for (const HistogramBucket& b : buckets) {
        rows << QVariantMap{ { "startMs", b.startMs }, { "timeText", localTime(b.startMs, format) },
                             { "error", b.counts[0] }, { "warn", b.counts[1] }, { "info", b.counts[2] },
                             { "debug", b.counts[3] }, { "trace", b.counts[4] }, { "other", b.counts[5] },
                             { "total", b.total() } };
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
    return { "templateText", "level", "count", "share", "firstSeen", "lastSeen", "examples", "trend", "trendMax" };
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
        rows << QVariantMap{ { "templateText", p.templateText }, { "level", levelName(p.level) },
                             { "count", p.count }, { "share", maxCount ? double(p.count) / maxCount : 0.0 },
                             { "firstSeen", p.firstSeen.toLocalTime().toString(QStringLiteral("HH:mm:ss")) },
                             { "lastSeen", p.lastSeen.toLocalTime().toString(QStringLiteral("HH:mm:ss")) },
                             { "examples", examples }, { "trend", trend }, { "trendMax", trendMax } };
    }
    return rows;
}

// ── Environments / saved queries ────────────────────────────────────────────

QByteArrayList environmentRoles() { return { "id", "name", "color", "configured", "current" }; }

QList<QVariantMap> environmentRows(const QList<Environment>& envs, const QString& currentId)
{
    QList<QVariantMap> rows;
    for (const Environment& e : envs) {
        rows << QVariantMap{ { "id", e.id }, { "name", e.name }, { "color", e.color },
                             { "configured", e.isConfigured() }, { "current", e.id == currentId } };
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
        const QString search = q.searchText.isEmpty() ? QStringLiteral("*") : q.searchText;
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
    if (s % 86400 == 0) return QCoreApplication::translate("Presenters", "Last %n day(s)", nullptr, int(s / 86400));
    if (s % 3600 == 0) return QCoreApplication::translate("Presenters", "Last %n hour(s)", nullptr, int(s / 3600));
    if (s % 60 == 0) return QCoreApplication::translate("Presenters", "Last %n minute(s)", nullptr, int(s / 60));
    return QCoreApplication::translate("Presenters", "Last %n second(s)", nullptr, int(s));
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
