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

QList<SavedQuery> parseSaved(const QJsonArray& arr)
{
    QList<SavedQuery> list;
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
        if (!q.id.isEmpty()) list.append(q);
    }
    return list;
}

QByteArray serializeSaved(const QList<SavedQuery>& list, QJsonDocument::JsonFormat format)
{
    QJsonArray arr;
    for (const SavedQuery& q : list) {
        arr.append(QJsonObject{ { "id", q.id }, { "name", q.name }, { "env", q.environmentId },
                                { "ns", q.namespaceName }, { "app", q.app }, { "q", q.searchText },
                                { "range", encodeTimeRange(q.range) },
                                { "created", double(q.createdAt.toMSecsSinceEpoch()) } });
    }
    return QJsonDocument(arr).toJson(format);
}
} // namespace

SavedQueriesStore::SavedQueriesStore(KeyValueStore& store) : m_store(store)
{
    m_list = parseSaved(QJsonDocument::fromJson(m_store.value(kSavedKey).toByteArray()).array());
}

QByteArray SavedQueriesStore::exportJson() const
{
    return serializeSaved(m_list, QJsonDocument::Indented);
}

int SavedQueriesStore::importJson(const QByteArray& json, bool replace)
{
    const QJsonDocument doc = QJsonDocument::fromJson(json);
    if (!doc.isArray()) return -1;
    const QList<SavedQuery> incoming = parseSaved(doc.array());
    if (replace) m_list.clear();
    int added = 0;
    for (const SavedQuery& q : incoming) {
        const bool known = std::any_of(m_list.cbegin(), m_list.cend(), [&](const SavedQuery& o) { return o.id == q.id; });
        if (known) continue;
        m_list.append(q);
        ++added;
    }
    save();
    return added;
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

bool SavedQueriesStore::update(const SavedQuery& query)
{
    for (SavedQuery& q : m_list) {
        if (q.id != query.id) continue;
        const QString name = q.name;
        const QDateTime created = q.createdAt;
        q = query;
        q.name = name;
        q.createdAt = created;
        save();
        return true;
    }
    return false;
}

void SavedQueriesStore::insert(int index, const SavedQuery& query)
{
    m_list.insert(std::clamp<qsizetype>(index, 0, m_list.size()), query);
    save();
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
    m_store.setValue(kSavedKey, serializeSaved(m_list, QJsonDocument::Compact));
}

// ── SearchHistory ───────────────────────────────────────────────────────────

namespace {
const QString kHistoryKey = QStringLiteral("searchHistory");
const QString kHistorySourcesKey = QStringLiteral("searchHistorySources");
} // namespace

QStringList SearchHistory::items() const
{
    return m_store.value(kHistoryKey).toStringList();
}

void SearchHistory::add(const QString& text, const QString& source)
{
    const QString t = text.trimmed();
    if (t.isEmpty() || t == u"*") return;
    QStringList list = items();
    list.removeAll(t);
    list.prepend(t);
    while (list.size() > kCapacity) list.removeLast();
    m_store.setValue(kHistoryKey, list);

    QVariantMap sources;
    const QVariantMap old = m_store.value(kHistorySourcesKey).toMap();
    for (const QString& item : std::as_const(list))
        if (old.contains(item)) sources.insert(item, old.value(item));
    if (!source.isEmpty()) sources.insert(t, source);
    else sources.remove(t);
    m_store.setValue(kHistorySourcesKey, sources);
}

QString SearchHistory::source(const QString& text) const
{
    return m_store.value(kHistorySourcesKey).toMap().value(text.trimmed()).toString();
}

void SearchHistory::clear()
{
    m_store.remove(kHistoryKey);
    m_store.remove(kHistorySourcesKey);
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
