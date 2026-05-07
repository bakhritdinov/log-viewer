#pragma once

#include <QObject>
#include <QSettings>
#include "GrafanaClient.h"

class ConfigManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentEnv READ currentEnv WRITE setCurrentEnv NOTIFY currentEnvChanged)
    Q_PROPERTY(bool darkTheme READ darkTheme WRITE setDarkTheme NOTIFY darkThemeChanged)

public:
    explicit ConfigManager(QObject *parent = nullptr);

    // Getters for current environment
    Q_INVOKABLE QString url() { return getVal("url"); }
    Q_INVOKABLE QString datasourceUid() { return getVal("uid"); }
    Q_INVOKABLE QString user() { return getVal("user"); }
    Q_INVOKABLE QString password() { return getVal("pass"); }

    // Getters for specific environment (for Settings Dialog)
    Q_INVOKABLE QString getUrl(const QString& env) { return getVal("url", env); }
    Q_INVOKABLE QString getUid(const QString& env) { return getVal("uid", env); }
    Q_INVOKABLE QString getUser(const QString& env) { return getVal("user", env); }
    Q_INVOKABLE QString getPass(const QString& env) { return getVal("pass", env); }

    Q_INVOKABLE void saveEnv(const QString& env, const QString& url, const QString& uid, const QString& user, const QString& pass);

    QString currentEnv() const { return m_currentEnv; }
    void setCurrentEnv(const QString& env);

    bool darkTheme() const { return m_darkTheme; }
    void setDarkTheme(bool dark);

signals:
    void currentEnvChanged();
    void darkThemeChanged();
    void settingsChanged();

private:
    QSettings m_settings;
    QString m_currentEnv;
    bool m_darkTheme = true;
    QString getVal(const QString& key, QString env = "");
};
