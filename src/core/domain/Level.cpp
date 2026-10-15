#include "core/domain/Level.h"

namespace lv {

namespace {

struct LevelSpec {
    Level level;
    QLatin1StringView name;
    QStringList synonyms;
};

const QList<LevelSpec>& specs()
{
    // Must stay in sync with the server-side filter: every synonym listed here is
    // also what levelFromString() accepts, so client and server agree on buckets.
    static const QList<LevelSpec> all = {
        { Level::Error, QLatin1StringView("ERROR"), { "err", "error", "fatal", "crit", "critical", "panic" } },
        { Level::Warn,  QLatin1StringView("WARN"),  { "warn", "warning" } },
        { Level::Info,  QLatin1StringView("INFO"),  { "info", "notice", "information" } },
        { Level::Debug, QLatin1StringView("DEBUG"), { "debug", "dbg" } },
        { Level::Trace, QLatin1StringView("TRACE"), { "trace" } },
    };
    return all;
}

} // namespace

Level levelFromString(QStringView raw)
{
    const QString l = raw.trimmed().toString().toLower();
    if (l.isEmpty()) return Level::Unknown;
    for (const LevelSpec& s : specs()) {
        if (s.synonyms.contains(l)) return s.level;
    }
    return Level::Unknown;
}

Level levelFromName(QStringView name)
{
    for (const LevelSpec& s : specs()) {
        if (name == s.name) return s.level;
    }
    return Level::Unknown;
}

QString levelName(Level level)
{
    for (const LevelSpec& s : specs()) {
        if (s.level == level) return s.name;
    }
    return {};
}

QStringList levelSynonyms(Level level)
{
    for (const LevelSpec& s : specs()) {
        if (s.level == level) return s.synonyms;
    }
    return {};
}

const QStringList& levelFieldNames()
{
    static const QStringList names = { "level", "severity", "lvl", "loglevel", "log_level" };
    return names;
}

Level levelFromFields(const QVariantMap& fields)
{
    for (const QString& key : levelFieldNames()) {
        const Level l = levelFromString(fields.value(key).toString());
        if (l != Level::Unknown) return l;
    }
    return Level::Unknown;
}

} // namespace lv
