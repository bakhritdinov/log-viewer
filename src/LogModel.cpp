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

    switch (value.typeId()) {
        case QMetaType::QDateTime:
            return value.toDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
        case QMetaType::LongLong:
        case QMetaType::Int:
        case QMetaType::Double:
            return QString::number(value.toDouble(), 'f', 0);
        case QMetaType::Bool:
            return value.toBool() ? "true" : "false";
        default:
            return value.toString();
    }
}

qint64 LogModel::oldestTimestamp() const {
    if (m_full.isEmpty()) return 0;
    // m_full is sorted newest-first, so the last element is the oldest.
    return m_full.last().timestamp.toMSecsSinceEpoch();
}

QVariantList LogModel::allFields() const {
    // Each element is the QVariantMap of one entry's fields — QML iterates and aggregates.
    QVariantList out;
    out.reserve(m_full.size());
    for (const auto& e : m_full) out.append(e.allFields);
    return out;
}

void LogModel::setEntries(const QList<LogEntry>& entries) {
    m_full = entries;
    std::sort(m_full.begin(), m_full.end(), [](const LogEntry& a, const LogEntry& b) {
        return a.timestamp > b.timestamp;
    });
    emit totalCountChanged();
    applySlice();
}

void LogModel::appendEntries(const QList<LogEntry>& entries) {
    m_full.append(entries);
    std::sort(m_full.begin(), m_full.end(), [](const LogEntry& a, const LogEntry& b) {
        return a.timestamp > b.timestamp;
    });
    emit totalCountChanged();
    applySlice();
}

void LogModel::setPage(int page, int pageSize) {
    m_page = page < 0 ? 0 : page;
    m_pageSize = pageSize < 0 ? 0 : pageSize;
    applySlice();
}

void LogModel::applySlice() {
    QList<LogEntry> slice;
    if (m_pageSize <= 0 || m_full.size() <= m_pageSize) {
        slice = m_full;
    } else {
        int start = m_page * m_pageSize;
        if (start >= m_full.size()) {
            m_page = 0;
            start = 0;
        }
        int end = qMin(start + m_pageSize, static_cast<int>(m_full.size()));
        slice = m_full.mid(start, end - start);
    }
    beginResetModel();
    m_entries = slice;
    endResetModel();
    emit countChanged();
}

void LogModel::setLoading(bool loading) {
    if (m_loading == loading) return;
    m_loading = loading;
    emit loadingChanged();
}

void LogModel::clear() {
    m_full.clear();
    beginResetModel();
    m_entries.clear();
    endResetModel();
    emit countChanged();
    emit totalCountChanged();
}
