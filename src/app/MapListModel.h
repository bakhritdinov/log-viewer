#pragma once

#include <QAbstractListModel>
#include <QByteArrayList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

namespace lv {

// Read-only list model whose rows are maps with a fixed set of roles. Used for
// small derived lists (chips, suggestions, histogram buckets, facets, …) whose
// content is computed by pure functions in the app layer.
class MapListModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Provided by Session")
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    explicit MapListModel(QByteArrayList roles, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return int(m_rows.size()); }
    const QList<QVariantMap>& rows() const { return m_rows; }
    Q_INVOKABLE QVariantMap get(int row) const;

    // Replaces the rows; same-length updates are reported as dataChanged so
    // views keep their state (scroll position, expanded delegates).
    void setRows(const QList<QVariantMap>& rows);

signals:
    void countChanged();

private:
    QByteArrayList m_roles;
    QList<QVariantMap> m_rows;
};

} // namespace lv
