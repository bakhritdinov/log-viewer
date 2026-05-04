#include "ConfigManager.h"
#include <QCoreApplication>

ConfigManager::ConfigManager(QObject *parent) : QObject(parent), m_settings("LogViewer", "LogViewer") {
    m_currentEnv = m_settings.value("currentEnv", "DEV").toString();
}

void ConfigManager::setCurrentEnv(const QString& env) {
    if (m_currentEnv == env) return;
    m_currentEnv = env;
    m_settings.setValue("currentEnv", env);
    emit currentEnvChanged();
}

void ConfigManager::saveEnv(const QString& env, const QString& url, const QString& uid, const QString& user, const QString& pass, const QString& nsLabel, const QString& appLabel) {
    m_settings.setValue(env + "/url", url);
    m_settings.setValue(env + "/uid", uid);
    m_settings.setValue(env + "/user", user);
    m_settings.setValue(env + "/pass", pass);
    m_settings.setValue(env + "/nsLabel", nsLabel);
    m_settings.setValue(env + "/appLabel", appLabel);
    emit settingsChanged();
}

QString ConfigManager::getVal(const QString& key, QString env) {
    if (env.isEmpty()) env = m_currentEnv;
    QString val = m_settings.value(env + "/" + key).toString();
    
    // Fallback to defaults for labels if empty
    if (val.isEmpty()) {
        if (key == "nsLabel") return "_namespace";
        if (key == "appLabel") return "_appName";
    }
    
    return val;
}
