#include "GrafanaClient.h"
#include <QUrl>
#include <QNetworkRequest>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QDebug>

GrafanaClient::GrafanaClient(QObject *parent) : QObject(parent) {
    m_manager = new QNetworkAccessManager(this);
}

void GrafanaClient::queryLogs(const QString& url, const QString& token, const QString& uid, const QString& user, const QString& pass, const QString& logql, const QString& from, const QString& to, bool append) {
    Config config { url, token, uid, user, pass };
    emit loadingChanged(true);
    
    QJsonObject requestBody;
    requestBody["from"] = from;
    requestBody["to"] = to;

    QJsonArray queries;
    QJsonObject query;
    query["refId"] = "A";
    QJsonObject datasource;
    datasource["uid"] = config.datasourceUid;
    query["datasource"] = datasource;
    query["expr"] = logql;
    query["queryType"] = "range";
    query["maxDataPoints"] = 5000;
    query["limit"] = 1000;
    // VERY IMPORTANT for pagination: fetch most recent logs from the range
    query["direction"] = "backward";
    
    queries.append(query);
    requestBody["queries"] = queries;

    QUrl apiUrl(config.url + "/api/ds/query");
    QNetworkRequest request(apiUrl);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    
    QString auth = config.getAuthHeader();
    if (!auth.isEmpty()) {
        request.setRawHeader("Authorization", auth.toUtf8());
    }

    QByteArray postData = QJsonDocument(requestBody).toJson();
    qDebug() << ">>> LOG QUERY:" << apiUrl.toString();
    // qDebug() << ">>> BODY:" << postData;

    // Cancel previous request if it's still running
    if (m_currentReply) {
        m_currentReply->disconnect();
        if (m_currentReply->isRunning()) {
            qDebug() << ">>> ABORTING previous request";
            m_currentReply->abort();
        }
        m_currentReply->deleteLater();
    }

    QNetworkReply* reply = m_manager->post(request, postData);
    m_currentReply = reply;

    connect(reply, &QNetworkReply::finished, this, [this, reply, append]() {
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray responseData = reply->readAll();
            qDebug() << "<<< RESPONSE RECEIVED (" << responseData.size() << "bytes)";
            parseLogsResponse(responseData, append);
        } else if (reply->error() != QNetworkReply::OperationCanceledError) {
            qDebug() << "!!! NETWORK ERROR:" << reply->errorString();
            emit errorOccurred("Grafana API Error: " + reply->errorString());
        }

        if (m_currentReply == reply) {
            m_currentReply = nullptr;
            emit loadingChanged(false);
        }
        reply->deleteLater();
    });
}

void GrafanaClient::fetchMappings(const QString& url, const QString& token, const QString& uid, const QString& user, const QString& pass) {
    Config config { url, token, uid, user, pass };
    emit loadingChanged(true);
    
    QJsonObject requestBody;
    requestBody["from"] = "now-24h";
    requestBody["to"] = "now";

    QJsonArray queries;
    QJsonObject query;
    query["refId"] = "A";
    QJsonObject datasource;
    datasource["uid"] = config.datasourceUid;
    query["datasource"] = datasource;
    query["expr"] = "* | stats by (_namespace, _appName) count() total";
    query["queryType"] = "range";
    queries.append(query);
    requestBody["queries"] = queries;

    QUrl apiUrl(config.url + "/api/ds/query");
    QNetworkRequest request(apiUrl);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    
    QString auth = config.getAuthHeader();
    if (!auth.isEmpty()) {
        request.setRawHeader("Authorization", auth.toUtf8());
    }

    QByteArray postData = QJsonDocument(requestBody).toJson();
    qDebug() << ">>> FETCH MAPPINGS:" << apiUrl.toString();

    QNetworkReply* reply = m_manager->post(request, postData);
    
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        emit loadingChanged(false);
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray responseData = reply->readAll();
            qDebug() << "<<< MAPPINGS RECEIVED (" << responseData.size() << "bytes)";
            parseMappingsResponse(responseData);
        } else {
            qDebug() << "!!! MAPPINGS ERROR:" << reply->errorString();
            emit errorOccurred(reply->errorString());
        }
        reply->deleteLater();
    });
}

void GrafanaClient::parseLogsResponse(const QByteArray& data, bool append) {
    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonArray frames = doc.object()["results"].toObject()["A"].toObject()["frames"].toArray();
    
    QList<LogEntry> entries;
    for (const auto& frameRef : frames) {
        QJsonObject frame = frameRef.toObject();
        QJsonArray fields = frame["schema"].toObject()["fields"].toArray();
        QJsonArray values = frame["data"].toObject()["values"].toArray();
        
        if (values.isEmpty()) continue;
        
        int rowCount = values[0].toArray().size();
        QMap<QString, int> fieldMap;
        for (int i = 0; i < fields.size(); ++i) {
            fieldMap[fields[i].toObject()["name"].toString()] = i;
        }
        
        for (int r = 0; r < rowCount; ++r) {
            LogEntry entry;
            entry.timestamp = QDateTime::currentDateTime(); // Default
            
            for (auto it = fieldMap.begin(); it != fieldMap.end(); ++it) {
                QString colName = it.key();
                QJsonValue val = values[it.value()].toArray()[r];
                
                if (colName == "Time" || colName == "ts") {
                    entry.timestamp = QDateTime::fromMSecsSinceEpoch(val.toVariant().toLongLong());
                } else if (colName == "Line" || colName == "message") {
                    entry.message = val.toString();
                } else if (colName == "labels") {
                    QJsonObject labels = val.toObject();
                    for (auto lit = labels.begin(); lit != labels.end(); ++lit) {
                        QString k = lit.key();
                        QString v = lit.value().toString();
                        entry.allFields[k] = v;
                        if (k == "trace_id" || k == "traceId") entry.traceId = v;
                        else if (k == "level") entry.level = v;
                        else if (k == "_appName" || k == "service_name") entry.service = v;
                        else if (k == "host.name" || k == "pod") entry.pod = v;
                    }
                } else {
                    entry.allFields[colName] = val.toVariant();
                }
            }
            
            if (entry.level.isEmpty()) {
                if (entry.message.contains("ERROR")) entry.level = "ERROR";
                else if (entry.message.contains("WARN")) entry.level = "WARN";
                else entry.level = "INFO";
            }
            
            entries.append(entry);
        }
    }
    qDebug() << ">>> LOGS PARSED. Entries count:" << entries.size();
    emit logsReceived(entries, append);
    calculateFacets(entries, append);
}

void GrafanaClient::calculateFacets(const QList<LogEntry>& entries, bool append) {
    if (!append) {
        m_currentFacets.clear();
    }

    for (const auto& entry : entries) {
        for (auto it = entry.allFields.begin(); it != entry.allFields.end(); ++it) {
            QString key = it.key();
            QString value = it.value().toString();
            if (key == "Line" || key == "message" || key == "ts" || key == "Time" || value.isEmpty()) continue;
            
            QVariantMap fieldData = m_currentFacets[key].toMap();
            fieldData[value] = fieldData.value(value, 0).toInt() + 1;
            m_currentFacets[key] = fieldData;
        }
    }
    qDebug() << ">>> FACETS CALCULATED. Fields:" << m_currentFacets.keys().size() << (append ? "(appended)" : "(reset)");
    emit facetsReceived(m_currentFacets);
}

void GrafanaClient::parseMappingsResponse(const QByteArray& data) {
    qDebug() << ">>> MAPPINGS DATA RECEIVED. Size:" << data.size();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonArray frames = doc.object()["results"].toObject()["A"].toObject()["frames"].toArray();
    
    QVariantMap mappings;
    for (const auto& frameRef : frames) {
        QJsonObject frame = frameRef.toObject();
        QJsonArray dataValues = frame["data"].toObject()["values"].toArray();
        QJsonArray fields = frame["schema"].toObject()["fields"].toArray();
        
        int lineCol = -1;
        for (int i = 0; i < fields.size(); ++i) {
            if (fields[i].toObject()["name"].toString() == "Line") {
                lineCol = i;
                break;
            }
        }
        
        if (lineCol != -1 && dataValues.size() > lineCol) {
            QJsonArray lines = dataValues[lineCol].toArray();
            for (const auto& lineRef : lines) {
                QJsonDocument lineDoc = QJsonDocument::fromJson(lineRef.toString().toUtf8());
                QString ns = lineDoc.object()["_namespace"].toString();
                QString app = lineDoc.object()["_appName"].toString();
                if (!ns.isEmpty() && !app.isEmpty()) {
                    QStringList apps = mappings[ns].toStringList();
                    if (!apps.contains(app)) {
                        apps.append(app);
                        mappings[ns] = apps;
                        qDebug() << "  Found mapping:" << ns << "->" << app;
                    }
                }
            }
        }
    }
    qDebug() << ">>> EMITTING MAPPINGS. Count:" << mappings.size();
    emit mappingsReceived(mappings);
}
