#pragma once

#include <QSet>

#include "core/domain/LogEntry.h"

namespace lv {

// The loaded entries of one search: newest first, without duplicates, with an
// optional view filter (histogram click) and page slicing over the filtered set.
class LogStore {
public:
    // Client-side narrowing; [fromMs, toMs) when toMs > 0, plus an exact level.
    struct Filter {
        qint64 fromMs = 0;
        qint64 toMs = 0;
        Level level = Level::Unknown;

        bool isActive() const { return toMs > 0 || level != Level::Unknown; }
        bool matches(const LogEntry& e) const;
        bool operator==(const Filter& other) const = default;
    };

    // Merges entries in, keeping newest-first order. Entries already present
    // (same time, message and fields) are dropped. Returns how many were new.
    int add(const LogEntries& entries);
    // As add(), then evicts the oldest entries beyond `capacity` (live tail).
    int addCapped(const LogEntries& entries, int capacity);
    void clear();

    const LogEntries& all() const { return m_all; }
    int size() const { return int(m_all.size()); }
    qint64 oldestMs() const { return m_all.isEmpty() ? 0 : m_all.last().timeMs(); }
    qint64 newestMs() const { return m_all.isEmpty() ? 0 : m_all.first().timeMs(); }

    void setFilter(const Filter& filter);
    void clearFilter() { setFilter({}); }
    const Filter& filter() const { return m_filter; }
    // Entries passing the filter (all of them without a filter).
    const LogEntries& visible() const { return m_filter.isActive() ? m_visible : m_all; }

    // Paging over visible(); pageSize <= 0 means one page with everything.
    int pageCount(int pageSize) const;
    // Out-of-range pages are clamped into [0, pageCount - 1].
    int clampPage(int page, int pageSize) const;
    LogEntries page(int page, int pageSize) const;

private:
    void rebuildVisible();

    LogEntries m_all;
    LogEntries m_visible;
    Filter m_filter;
    QSet<quint64> m_keys;
};

// Identity of an entry for de-duplication across overlapping batches.
quint64 entryKey(const LogEntry& entry);

} // namespace lv
