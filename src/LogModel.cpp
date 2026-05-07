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

qint64 LogModel::oldestTimestamp() const {
    if (m_entries.isEmpty()) return 0;
    // We sort newest first, so the last entry is the oldest.
    return m_entries.last().timestamp.toMSecsSinceEpoch();
}

void LogModel::setEntries(const QList<LogEntry>& entries, bool append) {
    auto sortNewestFirst = [](QList<LogEntry>& list) {
        std::sort(list.begin(), list.end(), [](const LogEntry& a, const LogEntry& b) {
            return a.timestamp > b.timestamp;
        });
    };

    if (!append) {
        beginResetModel();
        m_entries = entries;
        sortNewestFirst(m_entries);
        endResetModel();
        emit countChanged();
        return;
    }

    // Pagination append: dedupe against existing rows, then insert at the end.
    // Using beginInsertRows (instead of beginResetModel) preserves ListView scroll
    // position so the viewport doesn't snap to the top on every batch.
    QSet<QString> existingKeys;
    for (const auto& e : m_entries) {
        existingKeys.insert(QString::number(e.timestamp.toMSecsSinceEpoch()) + e.message);
    }

    QList<LogEntry> incoming;
    incoming.reserve(entries.size());
    for (const auto& e : entries) {
        QString key = QString::number(e.timestamp.toMSecsSinceEpoch()) + e.message;
        if (!existingKeys.contains(key)) {
            incoming.append(e);
            existingKeys.insert(key);
        }
    }

    if (incoming.isEmpty()) {
        emit countChanged(); // let QML observers re-evaluate hasMore guards
        return;
    }

    sortNewestFirst(incoming); // pagination always fetches strictly older logs, so they go after existing rows

    const int first = m_entries.size();
    const int last = first + incoming.size() - 1;
    beginInsertRows(QModelIndex(), first, last);
    m_entries.append(incoming);
    endInsertRows();
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
