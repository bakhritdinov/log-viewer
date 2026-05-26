#include "ErrorMessagesModel.h"
#include "FifoChannels.h"

#include <QHash>

ErrorMessagesModel::ErrorMessagesModel(QObject* parent)
    : QAbstractListModel(parent) {}

int ErrorMessagesModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return m_entries.size();
}

bool ErrorMessagesModel::isFifoChannel(const QString& channel) const {
    // Delegate to the injected FifoChannels registry. If none has been
    // configured (shouldn't happen in production), fall back to false so
    // nothing gets the FIFO treatment.
    return m_fifoChannels && m_fifoChannels->isFifo(channel);
}

QVariant ErrorMessagesModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size()) {
        return {};
    }
    const auto& e = m_entries.at(index.row());
    switch (role) {
        case MessageIdRole:        return e.messageId;
        case FailedAtRole:         return e.failedAt.toString(Qt::ISODate);
        case RawFailedAtRole:      return e.failedAt.toMSecsSinceEpoch();
        case PayloadRole:          return e.payload;
        case HeadersRole:          return e.headers;
        case ChannelRole:          return e.channel;
        case ContractIdRole:       return e.contractId;
        case IsFifoQueueRole:      return isFifoChannel(e.channel);
        case IsOldestInGroupRole:  return m_oldestInGroup.value(index.row(), false);
        case GroupSizeRole:        return m_groupSize.value(index.row(), 1);
        case ReplayStatusRole:     return e.replayStatus;
        case ReplayRequestIdRole:  return e.replayRequestId;
        case PositionRole:         return index.row();
        default:                   return {};
    }
}

QHash<int, QByteArray> ErrorMessagesModel::roleNames() const {
    return {
        {MessageIdRole,        "messageId"},
        {FailedAtRole,         "failedAt"},
        {RawFailedAtRole,      "rawFailedAt"},
        {PayloadRole,          "payload"},
        {HeadersRole,          "headers"},
        {ChannelRole,          "channel"},
        {ContractIdRole,       "contractId"},
        {IsFifoQueueRole,      "isFifoQueue"},
        {IsOldestInGroupRole,  "isOldestInGroup"},
        {GroupSizeRole,        "groupSize"},
        {ReplayStatusRole,     "replayStatus"},
        {ReplayRequestIdRole,  "replayRequestId"},
        {PositionRole,         "position"},
    };
}

void ErrorMessagesModel::recomputeGroupMetadata() {
    const int n = m_entries.size();
    m_oldestInGroup.fill(false, n);
    m_groupSize.fill(1, n);

    // Two-pass: first compute group sizes by (channel, contractId) for FIFO
    // channels; mark the first row of each group as oldest. Non-FIFO channels
    // get group size 1 and isOldest = false (they don't carry FIFO semantics).
    QHash<QString, int> sizeByKey;     // key → count
    QHash<QString, int> firstIdxByKey; // key → index of first occurrence

    for (int i = 0; i < n; ++i) {
        const auto& e = m_entries.at(i);
        if (!isFifoChannel(e.channel)) continue;
        const QString key = e.channel + QLatin1Char('|') + e.contractId;
        if (!firstIdxByKey.contains(key)) {
            firstIdxByKey.insert(key, i);
        }
        sizeByKey[key] = sizeByKey.value(key, 0) + 1;
    }

    for (auto it = firstIdxByKey.constBegin(); it != firstIdxByKey.constEnd(); ++it) {
        m_oldestInGroup[it.value()] = true;
    }
    for (int i = 0; i < n; ++i) {
        const auto& e = m_entries.at(i);
        if (!isFifoChannel(e.channel)) continue;
        const QString key = e.channel + QLatin1Char('|') + e.contractId;
        m_groupSize[i] = sizeByKey.value(key, 1);
    }
}

void ErrorMessagesModel::setEntries(const QList<DlqEntry>& entries, int total) {
    beginResetModel();
    m_entries = entries;
    recomputeGroupMetadata();
    endResetModel();
    if (m_total != total) {
        m_total = total;
        emit totalChanged();
    }
}

void ErrorMessagesModel::clear() {
    if (m_entries.isEmpty() && m_total == 0) return;
    beginResetModel();
    m_entries.clear();
    m_oldestInGroup.clear();
    m_groupSize.clear();
    endResetModel();
    if (m_total != 0) {
        m_total = 0;
        emit totalChanged();
    }
}

void ErrorMessagesModel::removeById(const QString& messageId) {
    for (int i = 0; i < m_entries.size(); ++i) {
        if (m_entries.at(i).messageId == messageId) {
            beginRemoveRows({}, i, i);
            m_entries.removeAt(i);
            endRemoveRows();
            recomputeGroupMetadata();
            // Refresh group-related roles on the remaining rows.
            if (!m_entries.isEmpty()) {
                emit dataChanged(index(0), index(m_entries.size() - 1),
                                 {IsOldestInGroupRole, GroupSizeRole, PositionRole});
            }
            if (m_total > 0) {
                --m_total;
                emit totalChanged();
            }
            return;
        }
    }
}
