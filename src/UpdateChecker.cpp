#include "UpdateChecker.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileDevice>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

UpdateChecker::UpdateChecker(QObject *parent)
    : QObject(parent)
    , m_settings("LogViewer", "LogViewer")
{
    // Restore the last-known release from disk so the banner appears immediately
    // on startup, before the network check finishes (or even if we're offline).
    loadCachedRelease();
}

QString UpdateChecker::currentVersion() const {
    return QStringLiteral(APP_VERSION);
}

bool UpdateChecker::canInstallInPlace() const {
#if defined(Q_OS_LINUX)
    // On Linux we can only auto-replace when the running binary is itself an AppImage.
    // For .deb/PPA installs we fall back to opening the release page.
    return !qEnvironmentVariableIsEmpty("APPIMAGE");
#else
    return true;
#endif
}

QString UpdateChecker::stateString() const {
    switch (m_state) {
        case Idle:            return "idle";
        case Checking:        return "checking";
        case UpToDate:        return "uptodate";
        case UpdateAvailable: return "available";
        case Downloading:     return "downloading";
        case ReadyToInstall:  return "ready";
        case Failed:          return "failed";
    }
    return "idle";
}

void UpdateChecker::setState(State s, const QString& error) {
    if (m_state == s && error == m_error) return;
    m_state = s;
    m_error = error;
    emit stateChanged();
}

void UpdateChecker::checkForUpdates() { runCheck(false); }
void UpdateChecker::forceCheck()       { runCheck(true);  }

void UpdateChecker::runCheck(bool force) {
    if (m_state == Checking || m_state == Downloading) return;

    if (!force) {
        const qint64 lastMs = m_settings.value("update/lastCheckMs").toLongLong();
        const qint64 nowMs  = QDateTime::currentMSecsSinceEpoch();
        if (lastMs > 0 && (nowMs - lastMs) < kMinAutoCheckMs) {
            // Throttled — leave whatever state the cached banner already set.
            return;
        }
    }

    setState(Checking);

    QUrl url(QStringLiteral("https://api.github.com/repos/%1/releases/latest")
                 .arg(QStringLiteral(GITHUB_REPO)));
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  QByteArray("LogViewer/") + APP_VERSION);
    req.setRawHeader("Accept", "application/vnd.github+json");

    // Conditional request — GitHub returns 304 Not Modified for unchanged
    // releases, and those don't count against the 60/hour rate limit.
    const QString etag = m_settings.value("update/etag").toString();
    if (!etag.isEmpty()) {
        req.setRawHeader("If-None-Match", etag.toUtf8());
    }

    if (m_currentReply) m_currentReply->abort();
    m_currentReply = m_nam.get(req);
    connect(m_currentReply, &QNetworkReply::finished,
            this, &UpdateChecker::onCheckFinished);
}

void UpdateChecker::onCheckFinished() {
    if (!m_currentReply) return;
    QNetworkReply* reply = m_currentReply;
    m_currentReply = nullptr;

    if (reply->error() != QNetworkReply::NoError) {
        reply->deleteLater();
        setState(Failed, reply->errorString());
        return;
    }

    const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    // Successful round-trip (200 or 304) — throttle the next auto check.
    m_settings.setValue("update/lastCheckMs", QDateTime::currentMSecsSinceEpoch());

    if (httpStatus == 304) {
        reply->deleteLater();
        // Nothing changed upstream. If we had a cached release, it's still the
        // current one — keep showing the banner. Otherwise we're up to date.
        setState(m_latestVersion.isEmpty() ? UpToDate : UpdateAvailable);
        return;
    }

    const QByteArray etag = reply->rawHeader("ETag");
    const QByteArray body = reply->readAll();
    reply->deleteLater();

    QJsonDocument doc = QJsonDocument::fromJson(body);
    QJsonObject release = doc.object();

    QString tag = release.value("tag_name").toString();
    if (tag.startsWith('v')) tag = tag.mid(1);
    if (tag.isEmpty()) {
        setState(Failed, QStringLiteral("Empty tag_name in response."));
        return;
    }

    m_latestVersion = tag;
    m_releaseNotes  = release.value("body").toString();
    m_releaseUrl    = release.value("html_url").toString();

    if (compareVersions(currentVersion(), tag) >= 0) {
        // We've caught up — drop the stale cache so we don't restore a banner
        // for an old release next time.
        clearCachedRelease();
        m_latestVersion.clear();
        emit metadataChanged();
        setState(UpToDate);
        return;
    }

    pickAssetForPlatform(release.value("assets").toArray(), m_assetName, m_assetUrl);
    saveCachedRelease(etag);
    emit metadataChanged();
    setState(UpdateAvailable);
}

void UpdateChecker::loadCachedRelease() {
    const QString cachedVersion = m_settings.value("update/latestVersion").toString();
    if (cachedVersion.isEmpty()) return;

    // Already running at-or-past the cached version — wipe and start clean.
    if (compareVersions(currentVersion(), cachedVersion) >= 0) {
        clearCachedRelease();
        return;
    }

    m_latestVersion = cachedVersion;
    m_releaseNotes  = m_settings.value("update/releaseNotes").toString();
    m_releaseUrl    = m_settings.value("update/releaseUrl").toString();
    m_assetName     = m_settings.value("update/assetName").toString();
    m_assetUrl      = m_settings.value("update/assetUrl").toString();
    emit metadataChanged();
    setState(UpdateAvailable);
}

void UpdateChecker::saveCachedRelease(const QByteArray& etag) {
    if (!etag.isEmpty()) m_settings.setValue("update/etag", QString::fromUtf8(etag));
    m_settings.setValue("update/latestVersion", m_latestVersion);
    m_settings.setValue("update/releaseNotes",  m_releaseNotes);
    m_settings.setValue("update/releaseUrl",    m_releaseUrl);
    m_settings.setValue("update/assetName",     m_assetName);
    m_settings.setValue("update/assetUrl",      m_assetUrl);
}

void UpdateChecker::clearCachedRelease() {
    m_settings.remove("update/etag");
    m_settings.remove("update/latestVersion");
    m_settings.remove("update/releaseNotes");
    m_settings.remove("update/releaseUrl");
    m_settings.remove("update/assetName");
    m_settings.remove("update/assetUrl");
}

void UpdateChecker::pickAssetForPlatform(const QJsonArray& assets,
                                         QString& outName, QString& outUrl) const {
    outName.clear();
    outUrl.clear();

    auto matchSuffix = [&](const QString& suffix) {
        for (const QJsonValue& v : assets) {
            QJsonObject o = v.toObject();
            const QString name = o.value("name").toString();
            if (name.endsWith(suffix, Qt::CaseInsensitive)) {
                outName = name;
                outUrl  = o.value("browser_download_url").toString();
                return true;
            }
        }
        return false;
    };

#if defined(Q_OS_MACOS)
    matchSuffix(".dmg");
#elif defined(Q_OS_WIN)
    matchSuffix(".exe");
#elif defined(Q_OS_LINUX)
    if (!qEnvironmentVariableIsEmpty("APPIMAGE")) {
        matchSuffix(".AppImage");
    }
    // Else: leave empty — UI will route to openReleasePage().
#endif
}

void UpdateChecker::downloadUpdate() {
    if (m_state != UpdateAvailable && m_state != Failed) return;
    if (m_assetUrl.isEmpty()) {
        openReleasePage();
        return;
    }

    setState(Downloading);
    m_downloaded = 0;
    m_total = 0;
    emit downloadProgressChanged();

    const QString downloadsDir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    QDir().mkpath(downloadsDir);
    m_downloadedFile = QDir(downloadsDir).absoluteFilePath(m_assetName);

    QNetworkRequest req((QUrl(m_assetUrl)));
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  QByteArray("LogViewer/") + APP_VERSION);
    // GitHub asset download redirects through codeload.github.com / s3 — follow them.
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);

    if (m_currentReply) m_currentReply->abort();
    m_currentReply = m_nam.get(req);
    connect(m_currentReply, &QNetworkReply::downloadProgress,
            this, &UpdateChecker::onDownloadProgress);
    connect(m_currentReply, &QNetworkReply::finished,
            this, &UpdateChecker::onDownloadFinished);
}

void UpdateChecker::onDownloadProgress(qint64 received, qint64 total) {
    m_downloaded = received;
    m_total = total;
    emit downloadProgressChanged();
}

void UpdateChecker::onDownloadFinished() {
    if (!m_currentReply) return;
    QNetworkReply* reply = m_currentReply;
    m_currentReply = nullptr;

    const bool aborted = (reply->error() == QNetworkReply::OperationCanceledError);
    if (reply->error() != QNetworkReply::NoError) {
        reply->deleteLater();
        if (!aborted) setState(Failed, reply->errorString());
        else          setState(UpdateAvailable);
        return;
    }

    QFile out(m_downloadedFile);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        reply->deleteLater();
        setState(Failed, QStringLiteral("Cannot write to %1").arg(m_downloadedFile));
        return;
    }
    out.write(reply->readAll());
    out.close();
    reply->deleteLater();

    setState(ReadyToInstall);
}

void UpdateChecker::cancel() {
    if (m_currentReply) {
        m_currentReply->abort();
        // onDownloadFinished / onCheckFinished will run and reset state.
    } else {
        setState(Idle);
    }
}

void UpdateChecker::openReleasePage() {
    if (!m_releaseUrl.isEmpty()) {
        QDesktopServices::openUrl(QUrl(m_releaseUrl));
    }
}

void UpdateChecker::installAndRestart() {
    if (m_state != ReadyToInstall) return;

#if defined(Q_OS_MACOS)
    // Mount the DMG via Finder; user drags the new app into Applications.
    QDesktopServices::openUrl(QUrl::fromLocalFile(m_downloadedFile));
    QCoreApplication::quit();

#elif defined(Q_OS_WIN)
    // Launch the NSIS installer detached so it survives our exit.
    QProcess::startDetached(m_downloadedFile, {});
    QCoreApplication::quit();

#elif defined(Q_OS_LINUX)
    const QString currentAppImage = qEnvironmentVariable("APPIMAGE");
    if (currentAppImage.isEmpty()) {
        // Non-AppImage runtime — fall back to the release page.
        openReleasePage();
        return;
    }
    const QString backup = currentAppImage + ".bak";
    QFile::remove(backup);
    if (!QFile::rename(currentAppImage, backup)) {
        setState(Failed, QStringLiteral("Cannot rename current AppImage. Check permissions on %1")
                             .arg(currentAppImage));
        return;
    }
    if (!QFile::rename(m_downloadedFile, currentAppImage)) {
        QFile::rename(backup, currentAppImage); // restore
        setState(Failed, QStringLiteral("Cannot move downloaded AppImage into place."));
        return;
    }
    QFile newFile(currentAppImage);
    newFile.setPermissions(newFile.permissions()
                           | QFileDevice::ExeOwner
                           | QFileDevice::ExeGroup
                           | QFileDevice::ExeOther);
    QProcess::startDetached(currentAppImage, {});
    QCoreApplication::quit();
#endif
}

int UpdateChecker::compareVersions(const QString& a, const QString& b) {
    auto parts = [](const QString& v) {
        QList<int> r;
        const auto chunks = v.split('.');
        for (const QString& c : chunks) r << c.toInt();
        while (r.size() < 3) r << 0;
        return r;
    };
    const auto pa = parts(a);
    const auto pb = parts(b);
    for (int i = 0; i < 3; ++i) {
        if (pa[i] < pb[i]) return -1;
        if (pa[i] > pb[i]) return 1;
    }
    return 0;
}
