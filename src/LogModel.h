#pragma once

#include <QAbstractListModel>
#include "GrafanaClient.h"

class LogModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY totalCountChanged)

public:
    enum Roles {
        TimestampRole = Qt::UserRole + 1,
        MessageRole,
        FieldsRole,
        RawTimestampRole
    };

    explicit LogModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE QString formatValue(const QVariant &value) const;

    // Oldest entry's timestamp (ms since epoch) over the full loaded set, or 0 if empty.
    // Used by the QML chained-loader to determine the next fetch offset.
    Q_INVOKABLE qint64 oldestTimestamp() const;

    bool loading() const { return m_loading; }
    int  totalCount() const { return m_full.size(); }

    // QML reads this when computing sidebar facets — full unsorted set across the load.
    Q_INVOKABLE QVariantList allFields() const;

public slots:
    // Replaces the entire loaded set. Re-applies current page slice afterwards.
    void setEntries(const QList<LogEntry>& entries);
    // Append a batch to the currently-loading set without resetting (used by chained fetch).
    void appendEntries(const QList<LogEntry>& entries);
    // Switch the visible slice. pageSize <= 0 means "show all".
    Q_INVOKABLE void setPage(int page, int pageSize);
    void setLoading(bool loading);
    void clear();

signals:
    void loadingChanged();
    void countChanged();
    void totalCountChanged();

private:
    void applySlice();

    QList<LogEntry> m_full;       // entire loaded set, sorted newest-first
    QList<LogEntry> m_entries;    // current page slice — what ListView sees
    int  m_page = 0;
    int  m_pageSize = 0;          // 0 = show all
    bool m_loading = false;
};
