#include "core/features/Focus.h"

namespace lv {

namespace {
TimeRange around(const LogEntry& anchor, int seconds)
{
    const auto r = TimeRange::absolute(anchor.timestamp.addSecs(-seconds), anchor.timestamp.addSecs(seconds));
    return r.value_or(TimeRange{});
}
} // namespace

QString traceIdOf(const LogEntry& entry)
{
    for (const char* key : { "trace_id", "traceId" }) {
        const QString v = formatFieldValue(entry.fields.value(QLatin1StringView(key)));
        if (!v.isEmpty()) return v;
    }
    return {};
}

FocusRequest contextRequest(const SearchSpec& base, const LogEntry& anchor, int seconds)
{
    SearchSpec spec = base;
    spec.query = Query();
    spec.serverLevel = Level::Unknown;
    return { spec, around(anchor, seconds) };
}

FocusRequest traceRequest(const SearchSpec& base, const LogEntry& anchor, int seconds)
{
    SearchSpec spec = base;
    spec.serverLevel = Level::Unknown;
    const QString id = traceIdOf(anchor);
    spec.query = id.isEmpty() ? Query() : Query::parse(FieldFilter{ QStringLiteral("trace_id"), id }.toText());
    return { spec, around(anchor, seconds) };
}

} // namespace lv
