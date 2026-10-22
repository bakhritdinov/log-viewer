#pragma once

#include <QAbstractListModel>
#include <QtQml/qqmlregistration.h>

#include "core/features/LogStore.h"

namespace lv {

class Preferences;

// Log entries of a LogStore for a list/table. Two ways to slice the visible
// entries: pages (desktop: page / pageCount / goToPage) or a growing window
// (mobile feed: showMore()). The store is owned elsewhere; call reload() after
// it changed.
class LogListModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Provided by Session")
    Q_PROPERTY(bool progressive READ isProgressive WRITE setProgressive NOTIFY slicingChanged)
    Q_PROPERTY(int pageSize READ pageSize WRITE setPageSize NOTIFY slicingChanged)
    Q_PROPERTY(int page READ page NOTIFY slicingChanged)
    Q_PROPERTY(int pageCount READ pageCount NOTIFY slicingChanged)
    Q_PROPERTY(int firstRowNumber READ firstRowNumber NOTIFY slicingChanged)
    Q_PROPERTY(int lastRowNumber READ lastRowNumber NOTIFY slicingChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY slicingChanged)
    Q_PROPERTY(int loadedCount READ loadedCount NOTIFY slicingChanged)
    Q_PROPERTY(bool canShowMore READ canShowMore NOTIFY slicingChanged)

public:
    enum Role {
        TimeTextRole = Qt::UserRole + 1,  // "HH:mm:ss.zzz", local time
        DateTimeTextRole,                 // "yyyy-MM-dd HH:mm:ss.zzz", local time
        TimeMsRole,
        MessageRole,
        LevelRole,                        // "ERROR" … "" for unknown
        ServiceRole,                      // app/service label value
        FieldsRole,
        TraceIdRole,
        OneLineRole,                      // message on one line (" ↵ " between lines)
        MoreLinesRole,                    // lines after the first
    };

    explicit LogListModel(const LogStore* store = nullptr, QObject* parent = nullptr);

    // Time texts follow these preferences (format, UTC); local HH:mm:ss.zzz without.
    void setPreferences(const Preferences* prefs);

    void setStore(const LogStore* store);
    // Field holding the app/service name (the discovered app label).
    void setServiceField(const QString& field);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool isProgressive() const { return m_progressive; }
    void setProgressive(bool on);
    int pageSize() const { return m_pageSize; }
    void setPageSize(int size);
    // Oldest entry first (a trace reads top-down); the store keeps newest first.
    bool isOldestFirst() const { return m_oldestFirst; }
    void setOldestFirst(bool on);
    int page() const { return m_page; }
    int pageCount() const;
    int firstRowNumber() const;   // 1-based number of the first row shown, 0 if none
    int lastRowNumber() const;    // 1-based number of the last row shown, 0 if none
    int totalCount() const;       // visible (filtered) entries
    int loadedCount() const;      // all loaded entries
    bool canShowMore() const;

    Q_INVOKABLE void goToPage(int page);
    Q_INVOKABLE void showMore();
    // The entry at a row of this model; nullptr when out of range.
    const LogEntry* entryAt(int row) const;
    Q_INVOKABLE QVariantMap rowData(int row) const;
    // A field of the entry at `row` as shown in the table ("" when absent).
    Q_INVOKABLE QString fieldText(int row, const QString& field) const;

    // Rebuilds rows from the store; `resetSlice` returns to the first page /
    // initial window (a new search), otherwise the current slice is kept.
    void reload(bool resetSlice = false);

signals:
    void slicingChanged();

private:
    const Preferences* m_prefs = nullptr;
    QString serviceOf(const LogEntry& e) const;

    const LogStore* m_store = nullptr;
    LogEntries m_rows;
    QString m_serviceField;
    bool m_progressive = false;
    bool m_oldestFirst = false;
    int m_pageSize = 100;
    int m_page = 0;
    int m_limit = 100;
};

} // namespace lv
