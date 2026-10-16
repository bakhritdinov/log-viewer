#include "core/features/Analysis.h"

#include <QHash>
#include <QRegularExpression>
#include <QSet>
#include <algorithm>

#include "core/query/Query.h"

namespace lv {

// ── Histogram ───────────────────────────────────────────────────────────────

int HistogramBucket::total() const
{
    int n = 0;
    for (int c : counts) n += c;
    return n;
}

int histogramLevelIndex(Level level)
{
    switch (level) {
        case Level::Error: return 0;
        case Level::Warn: return 1;
        case Level::Info: return 2;
        case Level::Debug: return 3;
        case Level::Trace: return 4;
        case Level::Unknown: break;
    }
    return 5;
}

QList<HistogramBucket> aggregateHistogram(const LogEntries& entries, qint64 bucketMs)
{
    QList<HistogramBucket> out;
    if (entries.isEmpty() || bucketMs <= 0) return out;

    qint64 minMs = entries.first().timeMs();
    qint64 maxMs = minMs;
    for (const LogEntry& e : entries) {
        minMs = std::min(minMs, e.timeMs());
        maxMs = std::max(maxMs, e.timeMs());
    }
    const qint64 alignedFrom = (minMs / bucketMs) * bucketMs;
    const qsizetype n = qsizetype((maxMs - alignedFrom) / bucketMs) + 1;
    out.resize(n);
    for (qsizetype i = 0; i < n; ++i) out[i].startMs = alignedFrom + i * bucketMs;
    for (const LogEntry& e : entries) {
        const qsizetype idx = std::clamp<qsizetype>((e.timeMs() - alignedFrom) / bucketMs, 0, n - 1);
        ++out[idx].counts[histogramLevelIndex(e.level)];
    }
    return out;
}

qint64 autoBucketMs(qint64 rangeSeconds)
{
    static constexpr qint64 steps[] = { 1000, 5000, 10000, 15000, 30000, 60000, 300000, 900000, 1800000, 3600000, 21600000, 86400000 };
    if (rangeSeconds <= 0) return 60000;
    const double ideal = double(rangeSeconds) * 1000.0 / 60.0;
    for (qint64 s : steps)
        if (s >= ideal) return s;
    return steps[std::size(steps) - 1];
}

// ── Facets ──────────────────────────────────────────────────────────────────

FieldValueCounts computeFacets(const LogEntries& entries)
{
    // Free text (stack traces, exception bodies, request dumps) is read in the
    // entry, not filtered by: such a field is left out whole.
    constexpr qsizetype filterableLength = 200;
    FieldValueCounts out;
    QSet<QString> freeText;
    for (const LogEntry& e : entries) {
        for (auto it = e.fields.cbegin(); it != e.fields.cend(); ++it) {
            const QString& k = it.key();
            if (k == u"Line" || k == u"message" || k == u"Time" || k == u"ts") continue;
            if (freeText.contains(k)) continue;
            const QString v = formatFieldValue(it.value());
            if (v.isEmpty()) continue;
            if (v.size() > filterableLength || v.contains(QLatin1Char('\n'))) {
                freeText.insert(k);
                out.remove(k);
                continue;
            }
            ++out[k][v];
        }
    }
    return out;
}

// ── Patterns ────────────────────────────────────────────────────────────────

Templated templateMessage(const QString& message)
{
    // Order matters: longer, more specific shapes first so a UUID is one "*",
    // not several numbers.
    static const QRegularExpression variable(QStringLiteral(
        "\\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\\b"   // UUID
        "|\\b\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}:\\d{2}(?:[.,]\\d+)?(?:Z|[+-]\\d{2}:?\\d{2})?"   // timestamp
        "|\\b\\d{1,3}(?:\\.\\d{1,3}){3}(?::\\d+)?\\b"                                         // IPv4[:port]
        "|\\b(?=[0-9a-fA-F]*\\d)(?=[0-9a-fA-F]*[a-fA-F])[0-9a-fA-F]{8,}\\b"                   // hex id: ≥8, digit and letter
        "|-?\\b\\d+(?:\\.\\d+)?(?!\\d)"));                                                   // number, unit may follow (12.5s)
    Templated t;
    qsizetype last = 0;
    QRegularExpressionMatchIterator it = variable.globalMatch(message);
    while (it.hasNext()) {
        const QRegularExpressionMatch m = it.next();
        const QStringView between = QStringView(message).mid(last, m.capturedStart() - last);
        if (!t.values.isEmpty() && between.isEmpty() && last > 0) {
            // Adjacent variables with no text between collapse into one "*".
            t.values.last() += m.captured();
        } else {
            t.templateText += between;
            t.templateText += QLatin1Char('*');
            t.values << m.captured();
        }
        last = m.capturedEnd();
    }
    t.templateText += QStringView(message).mid(last);
    return t;
}

QList<MessagePattern> extractPatterns(const LogEntries& entries, PatternOptions options)
{
    if (entries.isEmpty()) return {};
    qint64 minMs = entries.first().timeMs();
    qint64 maxMs = minMs;
    for (const LogEntry& e : entries) {
        minMs = std::min(minMs, e.timeMs());
        maxMs = std::max(maxMs, e.timeMs());
    }
    const int buckets = std::max(1, options.trendBuckets);
    const qint64 span = std::max<qint64>(1, maxMs - minMs + 1);

    QHash<QString, MessagePattern> groups;
    QList<QString> order;   // first appearance, for a stable tie-break
    for (const LogEntry& e : entries) {
        const Templated t = templateMessage(e.message);
        const QString key = QString::number(int(e.level)) + QLatin1Char('\x1f') + t.templateText;
        auto it = groups.find(key);
        if (it == groups.end()) {
            MessagePattern p;
            p.templateText = t.templateText;
            p.level = e.level;
            p.firstSeen = e.timestamp;
            p.lastSeen = e.timestamp;
            p.examples.resize(t.values.size());
            p.trend.resize(buckets);
            it = groups.insert(key, p);
            order << key;
        }
        MessagePattern& p = *it;
        ++p.count;
        p.firstSeen = std::min(p.firstSeen, e.timestamp);
        p.lastSeen = std::max(p.lastSeen, e.timestamp);
        for (qsizetype i = 0; i < t.values.size() && i < p.examples.size(); ++i) {
            QStringList& ex = p.examples[i];
            if (ex.size() < options.examplesPerSlot && !ex.contains(t.values.at(i))) ex << t.values.at(i);
        }
        const int bucket = int(std::clamp<qint64>((e.timeMs() - minMs) * buckets / span, 0, buckets - 1));
        ++p.trend[bucket];
    }

    QList<MessagePattern> out;
    out.reserve(order.size());
    for (const QString& k : order) out << groups.value(k);
    std::stable_sort(out.begin(), out.end(),
                     [](const MessagePattern& a, const MessagePattern& b) { return a.count > b.count; });
    return out;
}

} // namespace lv
