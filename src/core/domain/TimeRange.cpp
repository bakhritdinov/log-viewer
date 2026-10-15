#include "core/domain/TimeRange.h"

#include <QRegularExpression>

namespace lv {

TimeRange TimeRange::relative(qint64 seconds)
{
    TimeRange r;
    r.m_seconds = seconds > 0 ? seconds : 3600;
    return r;
}

TimeRange TimeRange::fromKey(QStringView key)
{
    if (key == u"today") return today();
    if (key == u"yesterday") return yesterday();
    static const QRegularExpression re(QStringLiteral("^(\\d+)([smhd])$"));
    const auto m = re.matchView(key);
    if (!m.hasMatch()) return relative(3600);
    const qint64 n = m.capturedView(1).toLongLong();
    switch (m.capturedView(2).at(0).toLatin1()) {
        case 's': return relative(n);
        case 'm': return relative(n * 60);
        case 'h': return relative(n * 3600);
        case 'd': return relative(n * 86400);
    }
    return relative(3600);
}

TimeRange TimeRange::today()
{
    TimeRange r;
    r.m_kind = Kind::Today;
    r.m_seconds = 0;
    return r;
}

TimeRange TimeRange::yesterday()
{
    TimeRange r;
    r.m_kind = Kind::Yesterday;
    r.m_seconds = 0;
    return r;
}

std::optional<TimeRange> TimeRange::absolute(const QDateTime& from, const QDateTime& to)
{
    if (!from.isValid() || !to.isValid() || from >= to) return std::nullopt;
    TimeRange r;
    r.m_kind = Kind::Absolute;
    r.m_seconds = 0;
    r.m_from = from;
    r.m_to = to;
    return r;
}

QDateTime TimeRange::parseBound(QStringView text)
{
    const QString t = text.trimmed().toString();
    QDateTime dt = QDateTime::fromString(t, Qt::ISODateWithMs);
    if (!dt.isValid()) dt = QDateTime::fromString(t, Qt::ISODate);
    if (!dt.isValid()) dt = QDateTime::fromString(t, QStringLiteral("yyyy-MM-dd HH:mm:ss"));
    if (!dt.isValid()) dt = QDateTime::fromString(t, QStringLiteral("yyyy-MM-dd HH:mm"));
    return dt;
}

QString TimeRange::key() const
{
    switch (m_kind) {
        case Kind::Today: return QStringLiteral("today");
        case Kind::Yesterday: return QStringLiteral("yesterday");
        case Kind::Absolute: return {};
        case Kind::Relative: break;
    }
    if (m_seconds % 86400 == 0) return QStringLiteral("%1d").arg(m_seconds / 86400);
    if (m_seconds % 3600 == 0) return QStringLiteral("%1h").arg(m_seconds / 3600);
    if (m_seconds % 60 == 0) return QStringLiteral("%1m").arg(m_seconds / 60);
    return QStringLiteral("%1s").arg(m_seconds);
}

TimeRange::Window TimeRange::resolve(const QDateTime& now) const
{
    switch (m_kind) {
        case Kind::Relative:
            return { now.addSecs(-m_seconds), now };
        case Kind::Today: {
            const QDateTime local = now.toLocalTime();
            return { QDateTime(local.date(), QTime(0, 0)), now };
        }
        case Kind::Yesterday: {
            const QDate today = now.toLocalTime().date();
            return { QDateTime(today.addDays(-1), QTime(0, 0)), QDateTime(today, QTime(0, 0)) };
        }
        case Kind::Absolute:
            return { m_from, m_to };
    }
    return { now.addSecs(-3600), now };
}

} // namespace lv
