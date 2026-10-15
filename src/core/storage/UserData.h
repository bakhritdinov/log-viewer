#pragma once

#include <QDateTime>
#include <QList>
#include <QString>
#include <QStringList>

#include "core/domain/TimeRange.h"
#include "core/storage/KeyValueStore.h"

namespace lv {

// A named search the user can re-run in one click.
struct SavedQuery {
    QString id;
    QString name;
    QString environmentId;
    QString namespaceName;
    QString app;
    QString searchText;
    TimeRange range;
    QDateTime createdAt;

    bool operator==(const SavedQuery& other) const = default;
};

class SavedQueriesStore {
public:
    explicit SavedQueriesStore(KeyValueStore& store);

    QList<SavedQuery> all() const { return m_list; }
    SavedQuery add(SavedQuery query);         // assigns id/createdAt when missing
    bool rename(const QString& id, const QString& name);
    bool remove(const QString& id);
    // Moves a saved query to a new position (shortcut ⌘1…⌘9 follow the order).
    bool move(const QString& id, int toIndex);

private:
    void save();
    KeyValueStore& m_store;
    QList<SavedQuery> m_list;
};

// Recent search texts, most recent first, without duplicates, capped.
class SearchHistory {
public:
    static constexpr int kCapacity = 10;
    explicit SearchHistory(KeyValueStore& store) : m_store(store) {}

    QStringList items() const;
    void add(const QString& text);   // blank and "*" are ignored
    void clear();

private:
    KeyValueStore& m_store;
};

// Last namespace/app per environment and the last time range, restored on start.
struct Selection {
    QString namespaceName;
    QString app;
};

class SelectionMemory {
public:
    explicit SelectionMemory(KeyValueStore& store) : m_store(store) {}

    Selection selection(const QString& environmentId) const;
    void setSelection(const QString& environmentId, const Selection& s);
    TimeRange timeRange() const;
    void setTimeRange(const TimeRange& range);

private:
    KeyValueStore& m_store;
};

// TimeRange <-> "1h" | "today" | "abs:<fromMs>:<toMs>" (settings, saved queries).
QString encodeTimeRange(const TimeRange& range);
TimeRange decodeTimeRange(const QString& text);

} // namespace lv
