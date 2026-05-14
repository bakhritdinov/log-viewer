#include "ConfigManager.h"
#include <QCoreApplication>

ConfigManager::ConfigManager(QObject *parent) : QObject(parent), m_settings("LogViewer", "LogViewer") {
    m_currentEnv = m_settings.value("currentEnv", "DEV").toString();
    m_darkTheme = m_settings.value("theme/dark", true).toBool();
}

void ConfigManager::setCurrentEnv(const QString& env) {
    if (m_currentEnv == env) return;
    m_currentEnv = env;
    m_settings.setValue("currentEnv", env);
    emit currentEnvChanged();
}

void ConfigManager::setDarkTheme(bool dark) {
    if (m_darkTheme == dark) return;
    m_darkTheme = dark;
    m_settings.setValue("theme/dark", dark);
    emit darkThemeChanged();
}

void ConfigManager::saveEnv(const QString& env, const QString& url, const QString& uid,
                            const QString& user, const QString& pass, const QString& token) {
    m_settings.setValue(env + "/url", url);
    m_settings.setValue(env + "/uid", uid);
    m_settings.setValue(env + "/user", user);
    m_settings.setValue(env + "/pass", pass);
    m_settings.setValue(env + "/token", token);
    emit settingsChanged();
}

void ConfigManager::setLastSelection(const QString& ns, const QString& app, const QString& timeRange,
                                     const QString& customFrom, const QString& customTo) {
    m_settings.setValue(m_currentEnv + "/lastNamespace", ns);
    m_settings.setValue(m_currentEnv + "/lastApp", app);
    m_settings.setValue("lastTimeRange", timeRange);
    m_settings.setValue("lastCustomFrom", customFrom);
    m_settings.setValue("lastCustomTo", customTo);
}

void ConfigManager::addToSearchHistory(const QString& query) {
    QString q = query.trimmed();
    if (q.isEmpty()) return;
    QStringList h = searchHistory();
    h.removeAll(q);
    h.prepend(q);
    while (h.size() > 10) h.removeLast();
    m_settings.setValue("searchHistory", h);
    emit searchHistoryChanged();
}

QString ConfigManager::getVal(const QString& key, QString env) {
    if (env.isEmpty()) env = m_currentEnv;
    return m_settings.value(env + "/" + key).toString();
}
