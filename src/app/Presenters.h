#pragma once

#include <QList>
#include <QString>
#include <QVariantMap>

#include "core/features/Analysis.h"
#include "core/query/Query.h"
#include "core/query/Suggestions.h"
#include "core/storage/Environments.h"
#include "core/storage/UserData.h"

// Pure functions turning core data into the rows the list models expose. Each
// list's role names are declared next to its builder so the two stay in sync.

namespace lv::presenters {

// ── Filter chips: one per search term ──
// roles: text, kind ("word"|"filter"), field, value, exclude, regex
QByteArrayList chipRoles();
QList<QVariantMap> chipRows(const QString& searchText);

// ── Search suggestions ──
// roles: kind ("field"|"value"), field, value, count, completedText, exclude
QByteArrayList suggestionRoles();
QList<QVariantMap> suggestionRows(const QList<Suggestion>& suggestions);

// ── Histogram buckets ──
// roles: startMs, timeText, error, warn, info, debug, trace, other, total, important (error + warn)
QByteArrayList histogramRoles();
QList<QVariantMap> histogramRows(const QList<HistogramBucket>& buckets, qint64 bucketMs);
// Totals per level over all buckets: {ERROR: n, WARN: n, INFO: n, DEBUG: n, TRACE: n, OTHER: n}
QVariantMap levelTotals(const QList<HistogramBucket>& buckets);

// ── Facets (fields sidebar / "other fields" chips) ──
// roles: field, distinct, total, expanded, values (list of {value, count, share, active, excluded})
QByteArrayList facetRoles();
// `filterText` narrows like the legacy sidebar: plain text matches fields or
// values; "key:value" narrows both. Values are sorted by count, at most 50.
QList<QVariantMap> facetRows(const FieldValueCounts& facets, const QString& filterText,
                             const QSet<QString>& expanded, const QList<FieldFilter>& activeFilters);

// ── Message patterns ──
// roles: templateText, level, count, share, firstSeen, lastSeen, examples, trend, trendMax
// roles: templateText, templateParts (literal/variable alternating, variables at odd
//        indexes), level, count, share, firstSeen, lastSeen, examples, trend, trendMax
QByteArrayList patternRoles();
QList<QVariantMap> patternRows(const QList<MessagePattern>& patterns);
// Orders patterns: "count" (most frequent first), "first" (earliest first
// seen first) or "level" (most severe first, then by count).
void sortPatterns(QList<MessagePattern>& patterns, const QString& order);

// ── Environments ──
// roles: id, name, color, configured, current
QByteArrayList environmentRoles();
QList<QVariantMap> environmentRows(const QList<Environment>& envs, const QString& currentId);

// ── Saved queries ──
// roles: id, name, environmentId, environmentName, environmentColor, namespaceName, app,
//        searchText, rangeKey, summary
QByteArrayList savedQueryRoles();
QList<QVariantMap> savedQueryRows(const QList<SavedQuery>& queries, const QList<Environment>& envs);

// Human label for a time range ("Last 1 hour", "Today", "15 Oct 09:00 → 12:00").
QString timeRangeLabel(const TimeRange& range);
// Short label for chips/mobile ("1 h", "15 min", "Today").
QString timeRangeShortLabel(const TimeRange& range);

// ── Source picker ──
// Namespaces matching `query` (case-insensitive) by their own name or by one
// of their apps. Each row: name, pre/hit/post (the name split around the
// match), appCount, apps: [{ name, pre, hit, post }] — all apps when the
// namespace itself matches, otherwise only the matching ones.
QVariantList sourceMatches(const QMap<QString, QStringList>& appsByNamespace, const QString& query);

// ── Time helpers for the period pickers ──
// Up to `count` evenly spaced bucket labels for the histogram axis.
QStringList histogramAxis(qint64 fromMs, qint64 toMs, int count);
// "UTC+5", "UTC−3:30" for the given offset from UTC in seconds.
QString utcOffsetLabel(int offsetSeconds);
// The date of a "yyyy-MM-dd HH:mm" bound; invalid text gives `fallback`.
QDate boundDate(const QString& boundText, const QDate& fallback);
// `boundText` moved to `day`, keeping its time; invalid text gets 00:00, or
// 23:59 for the end of a period.
QString boundOnDay(const QString& boundText, const QDate& day, bool endOfPeriod);

// ── JSON colouring ──
// `json` (any indented JSON text) as rich text for a read-only TextEdit: keys,
// strings, numbers, true/false, null and brackets/commas each in their colour
// (an empty colour leaves that kind plain); indentation and line breaks kept;
// everything HTML-escaped.
struct JsonColors
{
    QString key, string, number, boolean, null, punctuation;
};
QString jsonStyled(const QString& json, const JsonColors& colors);

// ── Highlighting ──
// `text` as Qt StyledText with every case-insensitive occurrence of `terms`
// wrapped in bold `color`; everything else HTML-escaped.
QString highlightStyled(const QString& text, const QStringList& terms, const QString& color);

} // namespace lv::presenters
