#include "core/storage/UserData.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimeZone>
#include <QUuid>
#include <algorithm>

namespace lv {

QString encodeTimeRange(const TimeRange& range)
{
    if (range.kind() == TimeRange::Kind::Absolute)
        return QStringLiteral("abs:%1:%2").arg(range.absoluteFrom().toMSecsSinceEpoch())
                                          .arg(range.absoluteTo().toMSecsSinceEpoch());
    return range.key();
}

TimeRange decodeTimeRange(const QString& text)
{
    if (text.startsWith(u"abs:")) {
        const QStringList parts = text.split(u':');
        if (parts.size() == 3) {
            const auto r = TimeRange::absolute(QDateTime::fromMSecsSinceEpoch(parts[1].toLongLong(), QTimeZone::UTC),
                                               QDateTime::fromMSecsSinceEpoch(parts[2].toLongLong(), QTimeZone::UTC));
            if (r) return *r;
        }
        return TimeRange();
    }
    return TimeRange::fromKey(text);
}

// ── SavedQueriesStore ───────────────────────────────────────────────────────

namespace {
const QString kSavedKey = QStringLiteral("savedQueries/list");
} // namespace

SavedQueriesStore::SavedQueriesStore(KeyValueStore& store) : m_store(store)
{
    const QJsonArray arr = QJsonDocument::fromJson(m_store.value(kSavedKey).toByteArray()).array();
    for (const QJsonValue& v : arr) {
        const QJsonObject o = v.toObject();
        SavedQuery q;
        q.id = o.value("id").toString();
        q.name = o.value("name").toString();
        q.environmentId = o.value("env").toString();
        q.namespaceName = o.value("ns").toString();
        q.app = o.value("app").toString();
        q.searchText = o.value("q").toString();
        q.range = decodeTimeRange(o.value("range").toString());
        q.createdAt = QDateTime::fromMSecsSinceEpoch(qint64(o.value("created").toDouble()), QTimeZone::UTC);
        if (!q.id.isEmpty()) m_list.append(q);
    }
}

SavedQuery SavedQueriesStore::add(SavedQuery query)
{
    if (query.id.isEmpty()) query.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    if (!query.createdAt.isValid()) query.createdAt = QDateTime::currentDateTimeUtc();
    m_list.append(query);
    save();
    return query;
}

bool SavedQueriesStore::rename(const QString& id, const QString& name)
{
    for (SavedQuery& q : m_list) {
        if (q.id != id) continue;
        q.name = name;
        save();
        return true;
    }
    return false;
}

bool SavedQueriesStore::remove(const QString& id)
{
    const qsizetype n = m_list.removeIf([&](const SavedQuery& q) { return q.id == id; });
    if (n) save();
    return n > 0;
}

bool SavedQueriesStore::move(const QString& id, int toIndex)
{
    for (qsizetype i = 0; i < m_list.size(); ++i) {
        if (m_list.at(i).id != id) continue;
        m_list.move(i, std::clamp<qsizetype>(toIndex, 0, m_list.size() - 1));
        save();
        return true;
    }
    return false;
}

void SavedQueriesStore::save()
{
    QJsonArray arr;
    for (const SavedQuery& q : m_list) {
        arr.append(QJsonObject{ { "id", q.id }, { "name", q.name }, { "env", q.environmentId },
                                { "ns", q.namespaceName }, { "app", q.app }, { "q", q.searchText },
                                { "range", encodeTimeRange(q.range) },
                                { "created", double(q.createdAt.toMSecsSinceEpoch()) } });
    }
    m_store.setValue(kSavedKey, QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

// ── SearchHistory ───────────────────────────────────────────────────────────

namespace {
const QString kHistoryKey = QStringLiteral("searchHistory");
} // namespace

QStringList SearchHistory::items() const
{
    return m_store.value(kHistoryKey).toStringList();
}

void SearchHistory::add(const QString& text)
{
    const QString t = text.trimmed();
    if (t.isEmpty() || t == u"*") return;
    QStringList list = items();
    list.removeAll(t);
    list.prepend(t);
    while (list.size() > kCapacity) list.removeLast();
    m_store.setValue(kHistoryKey, list);
}

void SearchHistory::clear()
{
    m_store.remove(kHistoryKey);
}

// ── SelectionMemory ─────────────────────────────────────────────────────────

Selection SelectionMemory::selection(const QString& environmentId) const
{
    const QString base = QStringLiteral("selection/%1/").arg(environmentId);
    return { m_store.value(base + "namespace").toString(), m_store.value(base + "app").toString() };
}

void SelectionMemory::setSelection(const QString& environmentId, const Selection& s)
{
    const QString base = QStringLiteral("selection/%1/").arg(environmentId);
    m_store.setValue(base + "namespace", s.namespaceName);
    m_store.setValue(base + "app", s.app);
}

TimeRange SelectionMemory::timeRange() const
{
    return decodeTimeRange(m_store.value(QStringLiteral("selection/timeRange"), QStringLiteral("1h")).toString());
}

void SelectionMemory::setTimeRange(const TimeRange& range)
{
    m_store.setValue(QStringLiteral("selection/timeRange"), encodeTimeRange(range));
}

} // namespace lv
