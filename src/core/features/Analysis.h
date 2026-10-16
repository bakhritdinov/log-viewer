#pragma once

#include <QDateTime>
#include <QList>
#include <QString>
#include <QStringList>
#include <array>

#include "core/domain/LogEntry.h"
#include "core/query/Suggestions.h"

namespace lv {

// ── Histogram ───────────────────────────────────────────────────────────────

struct HistogramBucket {
    qint64 startMs = 0;
    // Counts indexed by histogramLevelIndex(): ERROR, WARN, INFO, DEBUG, TRACE, other.
    std::array<int, 6> counts{};

    int total() const;
    bool operator==(const HistogramBucket& other) const = default;
};

// Index of `level` in HistogramBucket::counts (Unknown → 5).
int histogramLevelIndex(Level level);

// Buckets of `bucketMs` from the oldest to the newest entry, aligned to
// multiples of bucketMs; empty for no entries or a non-positive bucket.
QList<HistogramBucket> aggregateHistogram(const LogEntries& entries, qint64 bucketMs);

// Readable bucket step for a range: the smallest of 1m, 5m, 15m, 30m, 1h, 6h,
// 1d giving at most ~60 bars.
qint64 autoBucketMs(qint64 rangeSeconds);

// ── Facets ──────────────────────────────────────────────────────────────────

// field → value → occurrences over the entries (values via formatFieldValue;
// empty values skipped). A field with free text (a multi-line value or one over
// 200 characters) is left out: it is read in the entry, not filtered by.
FieldValueCounts computeFacets(const LogEntries& entries);

// ── Patterns ────────────────────────────────────────────────────────────────

// A group of messages that differ only in variable parts (numbers, ids, …).
struct MessagePattern {
    QString templateText;            // variable parts replaced by "*"
    Level level = Level::Unknown;
    int count = 0;
    QDateTime firstSeen;
    QDateTime lastSeen;
    // Up to a few distinct values seen for each "*", in template order.
    QList<QStringList> examples;
    // Occurrences over time (oldest → newest bucket) for a sparkline.
    QList<int> trend;
};

struct PatternOptions {
    int trendBuckets = 16;
    int examplesPerSlot = 3;
};

// The message with its variable parts replaced by "*" (consecutive ones merged),
// and the replaced values in order.
struct Templated {
    QString templateText;
    QStringList values;
};
Templated templateMessage(const QString& message);

// Groups entries by (template, level), most frequent first.
QList<MessagePattern> extractPatterns(const LogEntries& entries, PatternOptions options = {});

} // namespace lv
