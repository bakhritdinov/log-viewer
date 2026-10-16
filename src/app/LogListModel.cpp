#include "app/LogListModel.h"

#include <algorithm>

#include "app/Preferences.h"
#include "app/Presenters.h"
#include "core/features/Focus.h"
#include "core/query/Query.h"

namespace lv {

LogListModel::LogListModel(const LogStore* store, QObject* parent)
    : QAbstractListModel(parent), m_store(store)
{
}

void LogListModel::setStore(const LogStore* store)
{
    m_store = store;
    reload(true);
}

void LogListModel::setServiceField(const QString& field)
{
    if (m_serviceField == field) return;
    m_serviceField = field;
    if (!m_rows.isEmpty()) emit dataChanged(index(0), index(int(m_rows.size()) - 1), { ServiceRole });
}

int LogListModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : int(m_rows.size());
}

QString LogListModel::serviceOf(const LogEntry& e) const
{
    for (const QString& key : { m_serviceField, QStringLiteral("service"), QStringLiteral("app"),
                                QStringLiteral("_appName"), QStringLiteral("job") }) {
        if (key.isEmpty()) continue;
        const QString v = e.fields.value(key).toString();
        if (!v.isEmpty()) return v;
    }
    return {};
}

QVariant LogListModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= m_rows.size()) return {};
    const LogEntry& e = m_rows.at(index.row());
    switch (role) {
        case Qt::DisplayRole:
        case MessageRole: return presenters::listMessage(e.message);
        case TimeTextRole: return m_prefs ? m_prefs->timeText(e.timestamp)
                                          : e.timestamp.toLocalTime().toString(QStringLiteral("HH:mm:ss.zzz"));
        case DateTimeTextRole: return m_prefs ? m_prefs->dateTimeText(e.timestamp)
                                              : e.timestamp.toLocalTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss.zzz"));
        case TimeMsRole: return e.timeMs();
        case LevelRole: return levelName(e.level);
        case ServiceRole: return serviceOf(e);
        case FieldsRole: return e.fields;
        case TraceIdRole: return traceIdOf(e);
    }
    return {};
}

QHash<int, QByteArray> LogListModel::roleNames() const
{
    return { { TimeTextRole, "timeText" }, { DateTimeTextRole, "dateTimeText" }, { TimeMsRole, "timeMs" },
             { MessageRole, "message" }, { LevelRole, "level" }, { ServiceRole, "service" },
             { FieldsRole, "fields" }, { TraceIdRole, "traceId" } };
}

void LogListModel::setProgressive(bool on)
{
    if (m_progressive == on) return;
    m_progressive = on;
    reload(true);
}

void LogListModel::setPageSize(int size)
{
    size = std::max(1, size);
    if (m_pageSize == size) return;
    m_pageSize = size;
    reload(true);
}

int LogListModel::pageCount() const
{
    return m_store ? m_store->pageCount(m_pageSize) : 1;
}

int LogListModel::totalCount() const
{
    return m_store ? int(m_store->visible().size()) : 0;
}

int LogListModel::loadedCount() const
{
    return m_store ? m_store->size() : 0;
}

int LogListModel::firstRowNumber() const
{
    if (m_rows.isEmpty()) return 0;
    return m_progressive ? 1 : m_page * m_pageSize + 1;
}

int LogListModel::lastRowNumber() const
{
    return m_rows.isEmpty() ? 0 : firstRowNumber() + int(m_rows.size()) - 1;
}

bool LogListModel::canShowMore() const
{
    return m_progressive && m_rows.size() < totalCount();
}

void LogListModel::goToPage(int page)
{
    if (m_progressive || !m_store) return;
    const int clamped = m_store->clampPage(page, m_pageSize);
    if (clamped == m_page) return;
    m_page = clamped;
    reload(false);
}

void LogListModel::showMore()
{
    if (!canShowMore()) return;
    const int from = int(m_rows.size());
    m_limit += m_pageSize;
    const LogEntries more = m_store->visible().mid(from, m_limit - from);
    if (!more.isEmpty()) {
        beginInsertRows({}, from, from + int(more.size()) - 1);
        m_rows.append(more);
        endInsertRows();
    }
    emit slicingChanged();
}

const LogEntry* LogListModel::entryAt(int row) const
{
    return row >= 0 && row < m_rows.size() ? &m_rows.at(row) : nullptr;
}

QVariantMap LogListModel::rowData(int row) const
{
    QVariantMap out;
    const QModelIndex i = index(row);
    if (!i.isValid()) return out;
    const QHash<int, QByteArray> names = roleNames();
    for (auto it = names.cbegin(); it != names.cend(); ++it) out.insert(QString::fromUtf8(it.value()), data(i, it.key()));
    return out;
}

void LogListModel::setOldestFirst(bool on)
{
    if (m_oldestFirst == on) return;
    m_oldestFirst = on;
    reload(false);
}

void LogListModel::reload(bool resetSlice)
{
    beginResetModel();
    if (resetSlice) {
        m_page = 0;
        m_limit = m_pageSize;
    }
    if (!m_store) {
        m_rows.clear();
    } else if (m_progressive) {
        m_rows = m_store->visible().mid(0, m_limit);
    } else {
        m_page = m_store->clampPage(m_page, m_pageSize);
        m_rows = m_store->page(m_page, m_pageSize);
    }
    if (m_oldestFirst) std::reverse(m_rows.begin(), m_rows.end());
    endResetModel();
    emit slicingChanged();
}

void LogListModel::setPreferences(const Preferences* prefs)
{
    if (m_prefs) disconnect(m_prefs, nullptr, this, nullptr);
    m_prefs = prefs;
    if (!m_prefs) return;
    connect(m_prefs, &Preferences::changed, this, [this] {
        if (!m_rows.isEmpty()) emit dataChanged(index(0), index(int(m_rows.size()) - 1), { TimeTextRole, DateTimeTextRole });
    });
}

QString LogListModel::fieldText(int row, const QString& field) const
{
    const LogEntry* e = entryAt(row);
    return e ? formatFieldValue(e->fields.value(field)) : QString();
}

} // namespace lv
