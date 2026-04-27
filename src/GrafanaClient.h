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
    QString level;
    QString message;
    QString traceId;
    QString service;
    QString pod;
    QVariantMap allFields;
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

    Q_INVOKABLE void queryLogs(const QString& url, const QString& token, const QString& uid, const QString& user, const QString& pass, const QString& logql, const QString& from, const QString& to, bool append = false);
    Q_INVOKABLE void fetchMappings(const QString& url, const QString& token, const QString& uid, const QString& user, const QString& pass);

signals:
    void logsReceived(const QList<LogEntry>& entries, bool append);
    void facetsReceived(const QVariantMap& facets);
    void mappingsReceived(const QVariantMap& mappings);
    void errorOccurred(const QString& error);
    void loadingChanged(bool loading);

private:
    QNetworkAccessManager* m_manager;
    QNetworkReply* m_currentReply = nullptr;
    void parseLogsResponse(const QByteArray& data, bool append);
    void calculateFacets(const QList<LogEntry>& entries, bool append);
    void parseMappingsResponse(const QByteArray& data);

    QVariantMap m_currentFacets;
};
