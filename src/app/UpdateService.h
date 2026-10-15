#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonArray>
#include <QSettings>
#include <QtQml/qqmlregistration.h>

namespace lv {

// Checks GitHub Releases for a newer version, downloads and installs it.
// (Moved from the legacy app, which keeps its own copy until it is removed.)

class UpdateService : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(Updates)
    QML_SINGLETON

    // State exposed as string ("idle"/"checking"/"uptodate"/"available"/
    // "downloading"/"ready"/"failed") to avoid registering an enum type
    // separately — matches the QML-string-driven style elsewhere in the app.
    Q_PROPERTY(QString state READ stateString NOTIFY stateChanged)
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY metadataChanged)
    Q_PROPERTY(QString releaseNotes READ releaseNotes NOTIFY metadataChanged)
    Q_PROPERTY(QString releaseUrl READ releaseUrl NOTIFY metadataChanged)
    Q_PROPERTY(qint64  downloadedBytes READ downloadedBytes NOTIFY downloadProgressChanged)
    Q_PROPERTY(qint64  totalBytes READ totalBytes NOTIFY downloadProgressChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)
    // False on Linux when not running from an AppImage — UI falls back to "Open release page".
    Q_PROPERTY(bool canInstallInPlace READ canInstallInPlace CONSTANT)
    // Check at start-up (Settings → Version); stored in the app settings.
    Q_PROPERTY(bool autoCheck READ autoCheck WRITE setAutoCheck NOTIFY autoCheckChanged)
    // When the last check succeeded, "" if never.
    Q_PROPERTY(QString lastCheckText READ lastCheckText NOTIFY stateChanged)

public:
    explicit UpdateService(QObject *parent = nullptr);

    QString stateString() const;
    QString currentVersion() const;
    QString latestVersion()  const { return m_latestVersion; }
    QString releaseNotes()   const { return m_releaseNotes; }
    QString releaseUrl()     const { return m_releaseUrl; }
    qint64  downloadedBytes() const { return m_downloaded; }
    qint64  totalBytes()      const { return m_total; }
    QString errorMessage()    const { return m_error; }
    bool    canInstallInPlace() const;
    bool    autoCheck() const { return m_settings.value("update/autoCheck", true).toBool(); }
    void    setAutoCheck(bool on);
    QString lastCheckText() const;

    // Auto check — silently no-ops if the last successful round-trip was less
    // than kMinAutoCheckMs ago, so dev-style frequent restarts don't burn rate
    // limit. Use forceCheck() from manual UI actions.
    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE void forceCheck();
    Q_INVOKABLE void downloadUpdate();
    Q_INVOKABLE void installAndRestart();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void openReleasePage();

signals:
    void stateChanged();
    void metadataChanged();
    void downloadProgressChanged();
    void autoCheckChanged();

private slots:
    void onCheckFinished();
    void onDownloadFinished();
    void onDownloadProgress(qint64 received, qint64 total);

private:
    enum State { Idle, Checking, UpToDate, UpdateAvailable, Downloading, ReadyToInstall, Failed };

    void setState(State s, const QString& error = QString());
    void pickAssetForPlatform(const QJsonArray& assets, QString& outName, QString& outUrl) const;
    static int compareVersions(const QString& a, const QString& b);

    void runCheck(bool force);
    void loadCachedRelease();
    void saveCachedRelease(const QByteArray& etag);
    void clearCachedRelease();

    // 4h between automatic checks. ETag conditional requests don't cost
    // rate-limit quota on 304, but the request still costs a TCP round-trip
    // and a tiny amount on the GitHub side — no need to spam it.
    static constexpr qint64 kMinAutoCheckMs = 4LL * 60LL * 60LL * 1000LL;

    QSettings       m_settings;
    QNetworkAccessManager m_nam;
    QNetworkReply*  m_currentReply = nullptr;
    State           m_state = Idle;
    QString         m_latestVersion;
    QString         m_releaseNotes;
    QString         m_releaseUrl;
    QString         m_assetName;
    QString         m_assetUrl;
    QString         m_downloadedFile;
    qint64          m_downloaded = 0;
    qint64          m_total = 0;
    QString         m_error;
};

} // namespace lv
