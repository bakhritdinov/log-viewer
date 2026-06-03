#pragma once

#include <QObject>
#include <QSettings>

// Stores per-environment PostgreSQL credentials for the Ecotone DLQ.
// Keys are namespaced under "<env>/ecotone/<field>" so they do not collide
// with the Grafana settings owned by ConfigManager.
class EcotoneConfigManager : public QObject {
    Q_OBJECT

public:
    explicit EcotoneConfigManager(QObject* parent = nullptr);

    Q_INVOKABLE QString host(const QString& env)     const;
    Q_INVOKABLE int     port(const QString& env)     const;
    Q_INVOKABLE QString database(const QString& env) const;
    Q_INVOKABLE QString user(const QString& env)     const;
    Q_INVOKABLE QString password(const QString& env) const;

    Q_INVOKABLE void save(const QString& env,
                          const QString& host, int port, const QString& database,
                          const QString& user, const QString& password);

    // Per-column widths in the DLQ table — same pattern as ConfigManager::columnWidth.
    Q_INVOKABLE int  columnWidth(const QString& col, int fallback) const;
    Q_INVOKABLE void setColumnWidth(const QString& col, int w);

    // EcotoneWindow main-list filters — persisted globally (not per-env) so a
    // PROD switch keeps the operator's chosen view.
    Q_INVOKABLE int     timeRangeHours() const;
    Q_INVOKABLE void    setTimeRangeHours(int h);
    Q_INVOKABLE QString replayStatusFilter() const;
    Q_INVOKABLE void    setReplayStatusFilter(const QString& s);
    Q_INVOKABLE bool    autoRefresh() const;
    Q_INVOKABLE void    setAutoRefresh(bool on);

    // ReplayFifoGroupDialog persistence — remember last active tab and the
    // most recent search value entered per group, so reopening doesn't force
    // the user to retype.
    Q_INVOKABLE int     fifoLastTabIndex() const;
    Q_INVOKABLE void    setFifoLastTabIndex(int idx);
    Q_INVOKABLE QString fifoSearchValue(const QString& groupId) const;
    Q_INVOKABLE void    setFifoSearchValue(const QString& groupId, const QString& v);

signals:
    void settingsChanged();

private:
    QSettings m_settings;
    QString prefix(const QString& env, const QString& field) const;
};
