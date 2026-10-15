#include "core/features/LogStore.h"

#include <QCryptographicHash>
#include <QtEndian>
#include <algorithm>

#include "core/query/Query.h"

namespace lv {

quint64 entryKey(const LogEntry& e)
{
    // 64-bit digest of the full content: qHash is only 32-bit on wasm32, where
    // collisions in a 10 000-entry buffer would drop real lines.
    QCryptographicHash h(QCryptographicHash::Md5);
    const qint64 ms = e.timeMs();
    h.addData(QByteArrayView(reinterpret_cast<const char*>(&ms), sizeof ms));
    h.addData(e.message.toUtf8());
    for (auto it = e.fields.cbegin(); it != e.fields.cend(); ++it) {   // QVariantMap is key-sorted
        h.addData("\x1f");
        h.addData(it.key().toUtf8());
        h.addData("\x1e");
        h.addData(formatFieldValue(it.value()).toUtf8());
    }
    return qFromUnaligned<quint64>(h.result().constData());
}

bool LogStore::Filter::matches(const LogEntry& e) const
{
    if (toMs > 0) {
        const qint64 t = e.timeMs();
        if (t < fromMs || t >= toMs) return false;
    }
    return level == Level::Unknown || e.level == level;
}

int LogStore::add(const LogEntries& entries)
{
    int added = 0;
    for (const LogEntry& e : entries) {
        const quint64 key = entryKey(e);
        if (m_keys.contains(key)) continue;
        m_keys.insert(key);
        m_all.append(e);
        ++added;
    }
    if (added == 0) return 0;
    std::stable_sort(m_all.begin(), m_all.end(),
                     [](const LogEntry& a, const LogEntry& b) { return a.timestamp > b.timestamp; });
    rebuildVisible();
    return added;
}

int LogStore::addCapped(const LogEntries& entries, int capacity)
{
    const int added = add(entries);
    if (capacity > 0 && m_all.size() > capacity) {
        for (qsizetype i = capacity; i < m_all.size(); ++i) m_keys.remove(entryKey(m_all.at(i)));
        m_all.resize(capacity);
        rebuildVisible();
    }
    return added;
}

void LogStore::clear()
{
    m_all.clear();
    m_visible.clear();
    m_keys.clear();
}

void LogStore::setFilter(const Filter& filter)
{
    m_filter = filter;
    rebuildVisible();
}

void LogStore::rebuildVisible()
{
    m_visible.clear();
    if (!m_filter.isActive()) return;
    for (const LogEntry& e : m_all)
        if (m_filter.matches(e)) m_visible.append(e);
}

int LogStore::pageCount(int pageSize) const
{
    const qsizetype n = visible().size();
    if (pageSize <= 0 || n == 0) return 1;
    return int((n + pageSize - 1) / pageSize);
}

int LogStore::clampPage(int page, int pageSize) const
{
    return std::clamp(page, 0, pageCount(pageSize) - 1);
}

LogEntries LogStore::page(int page, int pageSize) const
{
    const LogEntries& v = visible();
    if (pageSize <= 0) return v;
    const qsizetype start = qsizetype(clampPage(page, pageSize)) * pageSize;
    return v.mid(start, pageSize);
}

} // namespace lv
