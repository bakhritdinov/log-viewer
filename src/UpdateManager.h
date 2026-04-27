#ifndef UPDATEMANAGER_H
#define UPDATEMANAGER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QDesktopServices>

class UpdateManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY latestVersionChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateAvailableChanged)
    Q_PROPERTY(bool checking READ checking NOTIFY checkingChanged)

public:
    explicit UpdateManager(QObject *parent = nullptr);

    QString currentVersion() const { return m_currentVersion; }
    QString latestVersion() const { return m_latestVersion; }
    bool updateAvailable() const { return m_updateAvailable; }
    bool checking() const { return m_checking; }

    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE void downloadLatest();

signals:
    void latestVersionChanged();
    void updateAvailableChanged();
    void checkingChanged();
    void updateCheckFinished(bool success, const QString &message);

private slots:
    void onReplyFinished(QNetworkReply *reply);

private:
    QString m_currentVersion;
    QString m_latestVersion;
    QString m_downloadUrl;
    bool m_updateAvailable = false;
    bool m_checking = false;
    QNetworkAccessManager *m_networkManager;
};

#endif // UPDATEMANAGER_H
