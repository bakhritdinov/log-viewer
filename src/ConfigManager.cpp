#include "ConfigManager.h"
#include <QCoreApplication>

ConfigManager::ConfigManager(QObject *parent) : QObject(parent), m_settings("LogViewer", "LogViewer") {
    m_currentEnv = m_settings.value("currentEnv", "DEV").toString();
    
    // Set defaults if empty
    if (m_settings.value("DEV/url").toString().isEmpty()) {
        saveEnv("DEV", "https://dev02-grafana.ipoint.uz", "fept7ytjacirkc", "", "");
    }
    if (m_settings.value("PROD/url").toString().isEmpty()) {
        saveEnv("PROD", "https://prod01-grafana.ipoint.uz", "bex5rini30agwc", "", "");
    }
}

void ConfigManager::setCurrentEnv(const QString& env) {
    if (m_currentEnv == env) return;
    m_currentEnv = env;
    m_settings.setValue("currentEnv", env);
    emit currentEnvChanged();
}

void ConfigManager::saveEnv(const QString& env, const QString& url, const QString& uid, const QString& user, const QString& pass) {
    m_settings.setValue(env + "/url", url);
    m_settings.setValue(env + "/uid", uid);
    m_settings.setValue(env + "/user", user);
    m_settings.setValue(env + "/pass", pass);
    emit settingsChanged();
}

QString ConfigManager::getVal(const QString& key, QString env) {
    if (env.isEmpty()) env = m_currentEnv;
    return m_settings.value(env + "/" + key).toString();
}
