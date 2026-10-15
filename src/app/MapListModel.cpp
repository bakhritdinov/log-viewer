#include "app/MapListModel.h"

namespace lv {

MapListModel::MapListModel(QByteArrayList roles, QObject* parent)
    : QAbstractListModel(parent), m_roles(std::move(roles))
{
}

int MapListModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : int(m_rows.size());
}

QVariant MapListModel::data(const QModelIndex& index, int role) const
{
    const int r = role - Qt::UserRole - 1;
    if (!index.isValid() || index.row() >= m_rows.size() || r < 0 || r >= m_roles.size()) return {};
    return m_rows.at(index.row()).value(QString::fromUtf8(m_roles.at(r)));
}

QHash<int, QByteArray> MapListModel::roleNames() const
{
    QHash<int, QByteArray> out;
    for (int i = 0; i < m_roles.size(); ++i) out.insert(Qt::UserRole + 1 + i, m_roles.at(i));
    return out;
}

QVariantMap MapListModel::get(int row) const
{
    return row >= 0 && row < m_rows.size() ? m_rows.at(row) : QVariantMap();
}

void MapListModel::setRows(const QList<QVariantMap>& rows)
{
    if (rows == m_rows) return;
    if (rows.size() == m_rows.size() && !rows.isEmpty()) {
        m_rows = rows;
        emit dataChanged(index(0), index(int(m_rows.size()) - 1));
        return;
    }
    beginResetModel();
    m_rows = rows;
    endResetModel();
    emit countChanged();
}

} // namespace lv
