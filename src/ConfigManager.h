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
    Q_INVOKABLE QString token() { return getVal("token"); }

    // Getters for specific environment (for Settings Dialog)
    Q_INVOKABLE QString getUrl(const QString& env) { return getVal("url", env); }
    Q_INVOKABLE QString getUid(const QString& env) { return getVal("uid", env); }
    Q_INVOKABLE QString getUser(const QString& env) { return getVal("user", env); }
    Q_INVOKABLE QString getPass(const QString& env) { return getVal("pass", env); }
    Q_INVOKABLE QString getToken(const QString& env) { return getVal("token", env); }

    Q_INVOKABLE void saveEnv(const QString& env, const QString& url, const QString& uid,
                             const QString& user, const QString& pass, const QString& token);

    QString currentEnv() const { return m_currentEnv; }
    void setCurrentEnv(const QString& env);

    bool darkTheme() const { return m_darkTheme; }
    void setDarkTheme(bool dark);

    // Last-used selection — restored on startup so users don't have to re-pick every time.
    Q_INVOKABLE QString lastNamespace(const QString& env = "") { return getVal("lastNamespace", env); }
    Q_INVOKABLE QString lastApp(const QString& env = "")       { return getVal("lastApp", env); }
    Q_INVOKABLE QString lastTimeRange()                        { return m_settings.value("lastTimeRange", "1h").toString(); }
    Q_INVOKABLE void setLastSelection(const QString& ns, const QString& app, const QString& timeRange);

    // Recent search queries — most recent first, capped at 10.
    Q_INVOKABLE QStringList searchHistory() { return m_settings.value("searchHistory").toStringList(); }
    Q_INVOKABLE void addToSearchHistory(const QString& query);
    Q_INVOKABLE void clearSearchHistory() { m_settings.remove("searchHistory"); emit searchHistoryChanged(); }

    // Per-column widths in the log table — persisted so user-resized columns survive restarts.
    Q_INVOKABLE int  columnWidth(const QString& col, int fallback) {
        return m_settings.value("columns/" + col, fallback).toInt();
    }
    Q_INVOKABLE void setColumnWidth(const QString& col, int w) {
        m_settings.setValue("columns/" + col, w);
    }

signals:
    void searchHistoryChanged();

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
