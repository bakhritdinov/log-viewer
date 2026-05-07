#include "LogModel.h"
#include <algorithm>

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
        case MessageRole: return entry.message;
        case FieldsRole: return entry.allFields;
        case RawTimestampRole: return entry.timestamp.toMSecsSinceEpoch();
    }
    return {};
}

QHash<int, QByteArray> LogModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[TimestampRole] = "timestamp";
    roles[MessageRole] = "message";
    roles[FieldsRole] = "fields";
    roles[RawTimestampRole] = "rawTimestamp";
    return roles;
}

QString LogModel::formatValue(const QVariant &value) const {
    if (!value.isValid() || value.isNull()) return "";
    
    // Элегантная конвертация по типу
    switch (value.typeId()) {
        case QMetaType::QDateTime:
            return value.toDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
        case QMetaType::LongLong:
        case QMetaType::Int:
        case QMetaType::Double:
            return QString::number(value.toDouble(), 'f', 0); // Можно настроить точность
        case QMetaType::Bool:
            return value.toBool() ? "true" : "false";
        default:
            return value.toString();
    }
}

void LogModel::setEntries(const QList<LogEntry>& entries) {
    beginResetModel();
    m_entries = entries;
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
