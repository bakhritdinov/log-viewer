#include "EcotoneConfigManager.h"

EcotoneConfigManager::EcotoneConfigManager(QObject* parent)
    : QObject(parent), m_settings("LogViewer", "LogViewer") {}

QString EcotoneConfigManager::prefix(const QString& env, const QString& field) const {
    const QString e = env.isEmpty() ? QStringLiteral("DEV") : env;
    return e + QStringLiteral("/ecotone/") + field;
}

QString EcotoneConfigManager::host(const QString& env) const {
    return m_settings.value(prefix(env, "host")).toString();
}

int EcotoneConfigManager::port(const QString& env) const {
    return m_settings.value(prefix(env, "port"), 5432).toInt();
}

QString EcotoneConfigManager::database(const QString& env) const {
    return m_settings.value(prefix(env, "database")).toString();
}

QString EcotoneConfigManager::user(const QString& env) const {
    return m_settings.value(prefix(env, "user")).toString();
}

QString EcotoneConfigManager::password(const QString& env) const {
    return m_settings.value(prefix(env, "password")).toString();
}

void EcotoneConfigManager::save(const QString& env,
                                const QString& host, int port, const QString& database,
                                const QString& user, const QString& password) {
    m_settings.setValue(prefix(env, "host"),     host);
    m_settings.setValue(prefix(env, "port"),     port);
    m_settings.setValue(prefix(env, "database"), database);
    m_settings.setValue(prefix(env, "user"),     user);
    m_settings.setValue(prefix(env, "password"), password);
    emit settingsChanged();
}

int EcotoneConfigManager::columnWidth(const QString& col, int fallback) const {
    return m_settings.value(QStringLiteral("ecotone/columns/") + col, fallback).toInt();
}

void EcotoneConfigManager::setColumnWidth(const QString& col, int w) {
    m_settings.setValue(QStringLiteral("ecotone/columns/") + col, w);
}

int EcotoneConfigManager::timeRangeHours() const {
    return m_settings.value(QStringLiteral("ecotone/filters/timeRangeHours"), 0).toInt();
}

void EcotoneConfigManager::setTimeRangeHours(int h) {
    m_settings.setValue(QStringLiteral("ecotone/filters/timeRangeHours"), h);
}

QString EcotoneConfigManager::replayStatusFilter() const {
    return m_settings.value(QStringLiteral("ecotone/filters/replayStatus"), QString()).toString();
}

void EcotoneConfigManager::setReplayStatusFilter(const QString& s) {
    m_settings.setValue(QStringLiteral("ecotone/filters/replayStatus"), s);
}

bool EcotoneConfigManager::autoRefresh() const {
    return m_settings.value(QStringLiteral("ecotone/filters/autoRefresh"), false).toBool();
}

void EcotoneConfigManager::setAutoRefresh(bool on) {
    m_settings.setValue(QStringLiteral("ecotone/filters/autoRefresh"), on);
}

int EcotoneConfigManager::fifoLastTabIndex() const {
    return m_settings.value(QStringLiteral("ecotone/fifo/lastTabIndex"), 0).toInt();
}

void EcotoneConfigManager::setFifoLastTabIndex(int idx) {
    m_settings.setValue(QStringLiteral("ecotone/fifo/lastTabIndex"), idx);
}

QString EcotoneConfigManager::fifoSearchValue(const QString& groupId) const {
    return m_settings.value(QStringLiteral("ecotone/fifo/search/") + groupId, QString()).toString();
}

void EcotoneConfigManager::setFifoSearchValue(const QString& groupId, const QString& v) {
    m_settings.setValue(QStringLiteral("ecotone/fifo/search/") + groupId, v);
}
