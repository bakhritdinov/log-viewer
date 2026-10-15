#pragma once

#include <QDateTime>
#include <QList>
#include <QString>
#include <QVariantMap>

#include "core/domain/Level.h"

namespace lv {

// One log line as returned by the datasource.
struct LogEntry {
    QDateTime timestamp;
    QString message;
    // Stream labels and structured fields, flattened into one map.
    QVariantMap fields;
    Level level = Level::Unknown;

    qint64 timeMs() const { return timestamp.toMSecsSinceEpoch(); }
    bool operator==(const LogEntry& other) const = default;
};

using LogEntries = QList<LogEntry>;

} // namespace lv
