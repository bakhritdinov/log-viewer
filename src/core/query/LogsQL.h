#pragma once

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
    // Window filter, see timeWindowFilter(); empty to omit.
    QString timeFilter;
    // Level pushed into the query itself ("load more errors"); Unknown = none.
    Level serverLevel = Level::Unknown;
};

// Escapes a LogsQL string literal body (backslash and double quote).
QString escapeLogsQL(QStringView value);

// `_time:<window>s offset <offset>s` — the chained loader walks back in time by
// raising the offset while keeping the window size.
QString timeWindowFilter(qint64 windowSeconds, qint64 offsetSeconds);

// `(level:~"(?i)^(err|error|…)$" OR severity:~"…" OR …)` across every field that
// may carry the level; empty for Level::Unknown.
QString levelFilterExpression(Level level);

// Full query: `{ns="…", app="…"} <time filter> <level> <terms…>`.
QString buildLogsQL(const LogsQLRequest& request);

} // namespace lv
