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
