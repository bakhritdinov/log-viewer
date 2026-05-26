#pragma once

#include <QAbstractListModel>
#include "EcotoneClient.h"

class FifoChannels;

class ErrorMessagesModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int total READ total NOTIFY totalChanged)

public:
    enum Roles {
        MessageIdRole = Qt::UserRole + 1,
        FailedAtRole,         // ISO-string for display
        RawFailedAtRole,      // qint64 ms since epoch
        PayloadRole,
        HeadersRole,
        ChannelRole,          // polledChannelName from headers
        ContractIdRole,       // contract_id from headers (may be empty)
        IsFifoQueueRole,      // true for contract_update_state* channels
        IsOldestInGroupRole,  // true for the first row of its (channel, contract_id) group, FIFO only
        GroupSizeRole,        // count of rows sharing this row's (channel, contract_id) group
        ReplayStatusRole,     // latest status from ecotone_replay_requests, "" if never queued
        ReplayRequestIdRole,  // latest request id (0 if never queued)
        PositionRole          // 0-based index, for display only
    };

    explicit ErrorMessagesModel(QObject* parent = nullptr);

    // Inject the FIFO channel registry — used to compute IsFifoQueueRole.
    void setFifoChannels(FifoChannels* f) { m_fifoChannels = f; }

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int total() const { return m_total; }

public slots:
    void setEntries(const QList<DlqEntry>& entries, int total);
    void clear();
    void removeById(const QString& messageId);

signals:
    void totalChanged();

private:
    void recomputeGroupMetadata();
    bool isFifoChannel(const QString& channel) const;

    QList<DlqEntry> m_entries;
    QList<bool>     m_oldestInGroup;   // parallel to m_entries
    QList<int>      m_groupSize;       // parallel to m_entries
    int m_total = 0;
    FifoChannels* m_fifoChannels = nullptr;
};
