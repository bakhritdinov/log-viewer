#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QVariantList>

struct LogEntry {
    QDateTime timestamp;
    QString message;
    QVariantMap allFields;
    // Normalized log level: "ERROR" | "WARN" | "INFO" | "DEBUG" | "TRACE" | "".
    // Populated in GrafanaClient::parseLogsResponse via LogModel::normalizeLevel.
    QString level;
};

class GrafanaClient : public QObject {
    Q_OBJECT
public:
    explicit GrafanaClient(QObject *parent = nullptr);

    struct Config {
        QString url;
        QString token;
        QString datasourceUid;
        QString user;
        QString password;

        QString getAuthHeader() const {
            if (!token.isEmpty()) return "Bearer " + token;
            if (!user.isEmpty()) {
                QString auth = user + ":" + password;
                return "Basic " + auth.toUtf8().toBase64();
            }
            return "";
        }
    };

    Q_INVOKABLE void queryLogs(const QString& url, const QString& token, const QString& uid, const QString& user, const QString& pass, const QString& logql, const QString& from, const QString& to);
    // Abort the in-flight log query (if any). Its result — including a batch still being
    // parsed on the worker thread — is dropped, and loadingChanged(false) is emitted.
    Q_INVOKABLE void cancelQuery();
    Q_INVOKABLE void fetchMappings(const QString& url, const QString& token, const QString& uid, const QString& user, const QString& pass);

signals:
    void logsReceived(const QList<LogEntry>& entries);
    void facetsReceived(const QVariantMap& facets);
    void mappingsReceived(const QVariantMap& mappings, const QString& nsLabel, const QString& appLabel);
    void errorOccurred(const QString& error);
    void loadingChanged(bool loading);

private:
    QNetworkAccessManager* m_manager;
    QNetworkReply* m_currentReply = nullptr;
    // Bumped on every queryLogs()/cancelQuery(); a parse result whose generation is stale
    // belongs to a superseded request and is discarded.
    quint64 m_queryGeneration = 0;
    // Pure function — runs on a worker thread so a 1000-row batch doesn't stall the UI.
    static QList<LogEntry> parseLogsResponse(const QByteArray& data);
    void parseMappingsResponse(const QByteArray& data);
};
