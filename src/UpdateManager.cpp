#include "UpdateManager.h"
#include <QSysInfo>
#include <QDebug>

UpdateManager::UpdateManager(QObject *parent)
    : QObject(parent)
    , m_currentVersion(APP_VERSION)
    , m_networkManager(new QNetworkAccessManager(this))
{
}

void UpdateManager::checkForUpdates() {
    if (m_checking) return;

    m_checking = true;
    emit checkingChanged();

    QUrl url(QString("https://api.github.com/repos/%1/releases/latest").arg(GITHUB_REPO));
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "LogViewer-Updater");

    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onReplyFinished(reply);
    });
}

void UpdateManager::onReplyFinished(QNetworkReply *reply) {
    m_checking = false;
    emit checkingChanged();

    if (reply->error() != QNetworkReply::NoError) {
        emit updateCheckFinished(false, "Network error: " + reply->errorString());
        reply->deleteLater();
        return;
    }

    QByteArray response = reply->readAll();
    reply->deleteLater();

    QJsonDocument doc = QJsonDocument::fromJson(response);
    QJsonObject obj = doc.object();

    m_latestVersion = obj.value("tag_name").toString();
    if (m_latestVersion.startsWith('v')) {
        m_latestVersion.remove(0, 1);
    }

    if (m_latestVersion.isEmpty()) {
        emit updateCheckFinished(false, "Could not find latest version info");
        return;
    }

    // Version comparison (simple string comparison for now, can be improved)
    m_updateAvailable = (m_latestVersion != m_currentVersion);

    // Find the correct asset for current platform
    QJsonArray assets = obj.value("assets").toArray();
    QString targetExtension;
#ifdef Q_OS_WIN
    targetExtension = ".exe";
#elif defined(Q_OS_MACOS)
    targetExtension = ".dmg";
#elif defined(Q_OS_LINUX)
    targetExtension = ".AppImage";
#endif

    for (const QJsonValue &asset : assets) {
        QString name = asset.toObject().value("name").toString();
        if (name.endsWith(targetExtension, Qt::CaseInsensitive)) {
            m_downloadUrl = asset.toObject().value("browser_download_url").toString();
            break;
        }
    }

    emit latestVersionChanged();
    emit updateAvailableChanged();
    emit updateCheckFinished(true, m_updateAvailable ? "New version available" : "Already up to date");
}

void UpdateManager::downloadLatest() {
    if (!m_downloadUrl.isEmpty()) {
        QDesktopServices::openUrl(QUrl(m_downloadUrl));
    }
}
