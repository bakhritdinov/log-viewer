#pragma once

#include <QDateTime>
#include <QString>
#include <QStringView>
#include <optional>

namespace lv {

// The period a search covers. Relative ranges ("last 1 hour", "today") are
// resolved against a caller-supplied `now`, so the type itself is pure.
class TimeRange {
public:
    enum class Kind { Relative, Today, Yesterday, Absolute };

    struct Window {
        QDateTime from;
        QDateTime to;
        qint64 seconds() const { return from.secsTo(to); }
    };

    // Last `seconds` up to now. Non-positive values fall back to one hour.
    static TimeRange relative(qint64 seconds);
    // Preset key as stored in settings and links: "90s", "15m", "1h", "7d",
    // "today", "yesterday". Unrecognized keys fall back to "1h".
    static TimeRange fromKey(QStringView key);
    static TimeRange today();
    static TimeRange yesterday();
    // Fixed period; nullopt unless both bounds are valid and from < to.
    static std::optional<TimeRange> absolute(const QDateTime& from, const QDateTime& to);
    // Parses a bound typed by the user or produced by the calendar:
    // ISO 8601 ("2026-10-15T09:00:00Z") or local "yyyy-MM-dd HH:mm[:ss]".
    static QDateTime parseBound(QStringView text);

    TimeRange() = default;   // last 1 hour

    Kind kind() const { return m_kind; }
    // Preset key for relative kinds ("1h", "today"…); empty for Absolute.
    QString key() const;
    qint64 relativeSeconds() const { return m_seconds; }
    QDateTime absoluteFrom() const { return m_from; }
    QDateTime absoluteTo() const { return m_to; }

    // Concrete bounds at `now` (local time decides where "today" starts).
    Window resolve(const QDateTime& now) const;

    bool operator==(const TimeRange& other) const = default;

private:
    Kind m_kind = Kind::Relative;
    qint64 m_seconds = 3600;
    QDateTime m_from;
    QDateTime m_to;
};

} // namespace lv
