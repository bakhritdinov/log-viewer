#pragma once

#include <QDateTime>
#include <QString>

#include "core/domain/Level.h"
#include "core/query/Query.h"

namespace lv {

// The log stream being searched: one namespace/app pair under the label names
// discovered for the datasource (e.g. `_namespace` / `_appName`).
struct StreamSelector {
    QString namespaceLabel;
    QString namespaceValue;
    QString appLabel;
    QString appValue;

    bool operator==(const StreamSelector& other) const = default;
};

struct LogsQLRequest {
    StreamSelector stream;
    Query query;
    // Time filter, see timeRangeFilter() / timeSinceFilter(); empty to omit.
    QString timeFilter;
    // Level pushed into the query itself ("load more errors"); Unknown = none.
    Level serverLevel = Level::Unknown;
};

// Escapes a LogsQL string literal body (backslash and double quote).
QString escapeLogsQL(QStringView value);

// `_time:[from, to]` with millisecond UTC bounds (both inclusive). Used by the
// loader instead of the legacy relative offset filter, so a window stays fixed
// while it is walked back batch by batch.
QString timeRangeFilter(const QDateTime& from, const QDateTime& to);
// `_time:>=from` — new entries since `from` (live tail).
QString timeSinceFilter(const QDateTime& from);

// `(level:~"(?i)^(err|error|…)$" OR severity:~"…" OR …)` across every field that
// may carry the level; empty for Level::Unknown.
QString levelFilterExpression(Level level);

// Full query: `{ns="…", app="…"} <time filter> <level> <terms…>`.
QString buildLogsQL(const LogsQLRequest& request);

} // namespace lv
