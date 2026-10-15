#pragma once

#include <QString>
#include <QStringList>
#include <QStringView>
#include <QVariantMap>

namespace lv {

// Normalized log level. Free-form values from log fields ("err", "Warning",
// "notice"…) collapse into these buckets.
enum class Level { Unknown, Trace, Debug, Info, Warn, Error };

// Free-form level text → bucket, case- and whitespace-insensitive, synonyms included.
Level levelFromString(QStringView raw);

// Exact canonical name ("ERROR", "WARN", …) → level; anything else is Unknown.
Level levelFromName(QStringView name);

// Canonical upper-case name; empty for Unknown.
QString levelName(Level level);

// Lower-case spellings that normalize to `level` (used for server-side filtering).
QStringList levelSynonyms(Level level);

// Field names that may carry the level, in priority order.
const QStringList& levelFieldNames();

// First field (in levelFieldNames() order) whose value normalizes to a known level.
Level levelFromFields(const QVariantMap& fields);

} // namespace lv
