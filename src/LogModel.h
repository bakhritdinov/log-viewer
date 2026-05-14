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
    // When the histogram filter is active, "visible" count = size of the
    // filtered subset (drives both the table view and pagination).
    int  totalCount() const { return m_filterActive ? filteredBase().size() : m_full.size(); }

    // QML reads this when computing sidebar facets — full unsorted set across the load.
    Q_INVOKABLE QVariantList allFields() const;

    // Bucket loaded entries by time × level. Returns a list of QVariantMap of the form
    // { "tMs": <bucket start, ms>, "ERROR": N, "WARN": M, "INFO": K, "DEBUG": L,
    //   "TRACE": P, "EMPTY": Q }. Used by HistogramChart.qml.
    Q_INVOKABLE QVariantList aggregateByLevel(qint64 bucketMs) const;

    // Client-side filter over m_full for histogram clicks. No server query;
    // shows exactly the loaded entries that fall into the bucket window and
    // (optionally) match the normalized level. Guarantees chartCount == tableCount.
    Q_INVOKABLE void applyTimeLevelFilter(qint64 fromMs, qint64 toMs, const QString& level);
    Q_INVOKABLE void clearTimeLevelFilter();
    Q_INVOKABLE bool hasTimeLevelFilter() const { return m_filterActive; }

    // Canonical "level" normalization. Free-form input → ERROR/WARN/INFO/DEBUG/TRACE/"".
    // Mirrors the old _normalizeLevel() in LogTableView.qml so C++ and QML agree on buckets.
    static QString normalizeLevel(const QString& raw);
    // Convenience: pull "level"/"severity"/"lvl"/"loglevel"/"log_level" out of a fields map,
    // pick the first non-empty, and normalize. Used by GrafanaClient on each entry.
    static QString extractLevel(const QVariantMap& fields);

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
    // Base set used to build the page slice — equals m_full when no filter
    // is active, otherwise the time-and-level filtered subset.
    QList<LogEntry> filteredBase() const;

    QList<LogEntry> m_full;       // entire loaded set, sorted newest-first
    QList<LogEntry> m_entries;    // current page slice — what ListView sees
    int  m_page = 0;
    int  m_pageSize = 0;          // 0 = show all
    bool m_loading = false;

    bool   m_filterActive = false;
    qint64 m_filterFromMs = 0;
    qint64 m_filterToMs   = 0;
    QString m_filterLevel;
};
