#include "LogModel.h"
#include <algorithm>
#include <QDebug>

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

QString LogModel::normalizeLevel(const QString& raw) {
    if (raw.isEmpty()) return {};
    const QString l = raw.toUpper().trimmed();
    if (l == "ERR" || l == "ERROR" || l == "FATAL" || l == "CRIT" || l == "CRITICAL" || l == "PANIC")
        return QStringLiteral("ERROR");
    if (l == "WARN" || l == "WARNING")
        return QStringLiteral("WARN");
    if (l == "INFO" || l == "NOTICE" || l == "INFORMATION")
        return QStringLiteral("INFO");
    if (l == "DEBUG" || l == "DBG")
        return QStringLiteral("DEBUG");
    if (l == "TRACE")
        return QStringLiteral("TRACE");
    return {};
}

QString LogModel::extractLevel(const QVariantMap& fields) {
    static const QStringList keys = {
        QStringLiteral("level"), QStringLiteral("severity"),
        QStringLiteral("lvl"), QStringLiteral("loglevel"),
        QStringLiteral("log_level")
    };
    for (const QString& k : keys) {
        const QString v = fields.value(k).toString();
        if (!v.isEmpty()) {
            const QString n = normalizeLevel(v);
            if (!n.isEmpty()) return n;
        }
    }
    return {};
}

QVariantList LogModel::aggregateByLevel(qint64 bucketMs) const {
    QVariantList out;
    if (m_full.isEmpty() || bucketMs <= 0) return out;

    // m_full is sorted newest-first; pick endpoints explicitly to avoid order assumptions.
    qint64 minMs = m_full.first().timestamp.toMSecsSinceEpoch();
    qint64 maxMs = minMs;
    for (const auto& e : m_full) {
        const qint64 ts = e.timestamp.toMSecsSinceEpoch();
        if (ts < minMs) minMs = ts;
        if (ts > maxMs) maxMs = ts;
    }

    const qint64 alignedFrom = (minMs / bucketMs) * bucketMs;
    const int nBuckets = static_cast<int>((maxMs - alignedFrom) / bucketMs) + 1;
    if (nBuckets <= 0) return out;

    // counts[bucketIdx][levelIdx]; levels index: 0=ERROR,1=WARN,2=INFO,3=DEBUG,4=TRACE,5=EMPTY
    QVector<QVector<int>> counts(nBuckets, QVector<int>(6, 0));
    for (const auto& e : m_full) {
        const qint64 ts = e.timestamp.toMSecsSinceEpoch();
        int idx = static_cast<int>((ts - alignedFrom) / bucketMs);
        if (idx < 0) idx = 0;
        if (idx >= nBuckets) idx = nBuckets - 1;
        const QString& lv = e.level;
        if      (lv == "ERROR") counts[idx][0]++;
        else if (lv == "WARN")  counts[idx][1]++;
        else if (lv == "INFO")  counts[idx][2]++;
        else if (lv == "DEBUG") counts[idx][3]++;
        else if (lv == "TRACE") counts[idx][4]++;
        else                    counts[idx][5]++;
    }

    out.reserve(nBuckets);
    for (int i = 0; i < nBuckets; ++i) {
        QVariantMap row;
        row.insert(QStringLiteral("tMs"), QVariant::fromValue<qint64>(alignedFrom + qint64(i) * bucketMs));
        row.insert(QStringLiteral("ERROR"), counts[i][0]);
        row.insert(QStringLiteral("WARN"),  counts[i][1]);
        row.insert(QStringLiteral("INFO"),  counts[i][2]);
        row.insert(QStringLiteral("DEBUG"), counts[i][3]);
        row.insert(QStringLiteral("TRACE"), counts[i][4]);
        row.insert(QStringLiteral("EMPTY"), counts[i][5]);
        out.append(row);
    }
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

QList<LogEntry> LogModel::filteredBase() const {
    if (!m_filterActive) return m_full;
    QList<LogEntry> out;
    out.reserve(m_full.size());
    for (const auto& e : m_full) {
        const qint64 ts = e.timestamp.toMSecsSinceEpoch();
        if (ts < m_filterFromMs || ts >= m_filterToMs) continue;
        if (!m_filterLevel.isEmpty() && e.level != m_filterLevel) continue;
        out.append(e);
    }
    return out;
}

void LogModel::applySlice() {
    const QList<LogEntry> base = filteredBase();
    QList<LogEntry> slice;
    if (m_pageSize <= 0 || base.size() <= m_pageSize) {
        slice = base;
    } else {
        int start = m_page * m_pageSize;
        if (start >= base.size()) {
            m_page = 0;
            start = 0;
        }
        int end = qMin(start + m_pageSize, static_cast<int>(base.size()));
        slice = base.mid(start, end - start);
    }
    beginResetModel();
    m_entries = slice;
    endResetModel();
    emit countChanged();
    emit totalCountChanged();
}

void LogModel::applyTimeLevelFilter(qint64 fromMs, qint64 toMs, const QString& level) {
    m_filterActive = true;
    m_filterFromMs = fromMs;
    m_filterToMs   = toMs;
    m_filterLevel  = level;
    applySlice();
}

void LogModel::clearTimeLevelFilter() {
    if (!m_filterActive) return;
    m_filterActive = false;
    m_filterFromMs = 0;
    m_filterToMs   = 0;
    m_filterLevel.clear();
    applySlice();
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
