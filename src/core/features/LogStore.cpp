#include "core/features/LogStore.h"

#include <algorithm>
#include <iterator>

#include <QCryptographicHash>
#include <QtEndian>

#include "core/features/Analysis.h"
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
    if (level != Level::Unknown && e.level != level) return false;
    if (!messageTemplate.isEmpty()) {
        const bool problem = e.level == Level::Warn || e.level == Level::Error;
        const bool inPattern = (!templateProblemsOnly || problem) && templateMessage(e.message).templateText == messageTemplate;
        return inPattern != excludeTemplate;
    }
    return true;
}

int LogStore::add(const LogEntries& entries)
{
    LogEntries fresh;
    for (const LogEntry& e : entries) {
        const quint64 key = entryKey(e);
        if (m_keys.contains(key)) continue;
        m_keys.insert(key);
        fresh.append(e);
    }
    if (fresh.isEmpty()) return 0;
    const auto newerFirst = [](const LogEntry& a, const LogEntry& b) { return a.timestamp > b.timestamp; };
    std::stable_sort(fresh.begin(), fresh.end(), newerFirst);
    // Merge instead of re-sorting / re-filtering everything: only the new
    // entries are matched against the filter.
    LogEntries merged;
    merged.reserve(m_all.size() + fresh.size());
    std::merge(m_all.cbegin(), m_all.cend(), fresh.cbegin(), fresh.cend(), std::back_inserter(merged), newerFirst);
    m_all = std::move(merged);
    if (m_filter.isActive()) {
        const LogEntries matched = filterEntries(fresh, m_filter);
        LogEntries visible;
        visible.reserve(m_visible.size() + matched.size());
        std::merge(m_visible.cbegin(), m_visible.cend(), matched.cbegin(), matched.cend(), std::back_inserter(visible), newerFirst);
        m_visible = std::move(visible);
    }
    ++m_revision;
    return int(fresh.size());
}

int LogStore::addCapped(const LogEntries& entries, int capacity)
{
    const int added = add(entries);
    if (capacity > 0 && m_all.size() > capacity) {
        for (qsizetype i = capacity; i < m_all.size(); ++i) m_keys.remove(entryKey(m_all.at(i)));
        m_all.resize(capacity);
        rebuildVisible();
        ++m_revision;
    }
    return added;
}

void LogStore::clear()
{
    m_all.clear();
    m_visible.clear();
    m_keys.clear();
    ++m_revision;
}

void LogStore::setFilter(const Filter& filter)
{
    m_filter = filter;
    rebuildVisible();
}

void LogStore::setFilter(const Filter& filter, LogEntries visible)
{
    m_filter = filter;
    m_visible = filter.isActive() ? std::move(visible) : LogEntries();
}

LogEntries LogStore::filterEntries(const LogEntries& entries, const Filter& filter)
{
    LogEntries out;
    if (!filter.isActive()) return out;
    for (const LogEntry& e : entries)
        if (filter.matches(e)) out.append(e);
    return out;
}

void LogStore::rebuildVisible()
{
    m_visible = filterEntries(m_all, m_filter);
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
