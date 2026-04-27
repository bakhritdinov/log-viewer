#pragma once

#include <QAbstractListModel>
#include "GrafanaClient.h"

class LogModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        TimestampRole = Qt::UserRole + 1,
        LevelRole,
        MessageRole,
        TraceIdRole,
        ServiceRole,
        PodRole,
        AllFieldsRole,
        RawTimestampRole
    };

    explicit LogModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool loading() const { return m_loading; }
    
    // Get the oldest timestamp in the model (for pagination)
    Q_INVOKABLE qint64 oldestTimestamp() const;

public slots:
    void setEntries(const QList<LogEntry>& entries, bool append);
    void setLoading(bool loading);
    void clear();

signals:
    void loadingChanged();
    void countChanged();

private:
    QList<LogEntry> m_entries;
    bool m_loading = false;
};
