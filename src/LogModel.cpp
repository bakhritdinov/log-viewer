#include "LogModel.h"
#include <algorithm>
#include <QSet>

LogModel::LogModel(QObject *parent) : QAbstractListModel(parent) {}

int LogModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_entries.size();
}

QVariant LogModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_entries.size()) return {};

    const auto& entry = m_entries[index.row()];
    switch (role) {
        case TimestampRole: return entry.timestamp.toString("yyyy-MM-dd HH:mm:ss.zzz");
        case LevelRole: return entry.level;
        case MessageRole: return entry.message;
        case TraceIdRole: return entry.traceId;
        case ServiceRole: return entry.service;
        case PodRole: return entry.pod;
        case AllFieldsRole: return entry.allFields;
        case RawTimestampRole: return entry.timestamp.toMSecsSinceEpoch();
    }
    return {};
}

QHash<int, QByteArray> LogModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[TimestampRole] = "timestamp";
    roles[LevelRole] = "level";
    roles[MessageRole] = "message";
    roles[TraceIdRole] = "traceId";
    roles[ServiceRole] = "service";
    roles[PodRole] = "pod";
    roles[AllFieldsRole] = "allFields";
    roles[RawTimestampRole] = "rawTimestamp";
    return roles;
}

qint64 LogModel::oldestTimestamp() const {
    if (m_entries.isEmpty()) return 0;
    // We sort newest first, so the last entry is the oldest.
    return m_entries.last().timestamp.toMSecsSinceEpoch();
}

void LogModel::setEntries(const QList<LogEntry>& entries, bool append) {
    beginResetModel();
    if (append) {
        // Create a set of unique identifiers for existing logs to avoid duplicates
        // Using timestamp + message hash as a simple unique key
        QSet<QString> existingKeys;
        for (const auto& e : m_entries) {
            existingKeys.insert(QString::number(e.timestamp.toMSecsSinceEpoch()) + e.message);
        }

        for (const auto& e : entries) {
            QString key = QString::number(e.timestamp.toMSecsSinceEpoch()) + e.message;
            if (!existingKeys.contains(key)) {
                m_entries.append(e);
                existingKeys.insert(key);
            }
        }
    } else {
        m_entries = entries;
    }

    // Always sort: newest first
    std::sort(m_entries.begin(), m_entries.end(), [](const LogEntry& a, const LogEntry& b) {
        return a.timestamp > b.timestamp;
    });
    
    endResetModel();
    emit countChanged();
}

void LogModel::setLoading(bool loading) {
    if (m_loading == loading) return;
    m_loading = loading;
    emit loadingChanged();
}

void LogModel::clear() {
    beginResetModel();
    m_entries.clear();
    endResetModel();
    emit countChanged();
}
