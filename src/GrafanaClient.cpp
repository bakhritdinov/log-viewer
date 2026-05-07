#include "GrafanaClient.h"
#include <QUrl>
#include <QUrlQuery>
#include <QNetworkRequest>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QDebug>
#include <QSettings>
#include <QSet>

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
    query["limit"] = 1000;
    query["maxLines"] = 1000; // VictoriaLogs Grafana plugin reads this knob, not "limit"

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

    if (m_currentReply) {
        qDebug() << ">>> ABORTING previous request";
        QNetworkReply* old = m_currentReply;
        m_currentReply = nullptr;
        old->abort(); // finished() fires synchronously; its lambda captures `old` and cleans up.
    }

    qDebug() << ">>> LOG QUERY:" << apiUrl.toString() << "from:" << from << "to:" << to << "append:" << append;
    QNetworkReply* reply = m_manager->post(request, postData);
    m_currentReply = reply;

    connect(reply, &QNetworkReply::finished, this, [this, reply, append]() {
        emit loadingChanged(false);
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray responseData = reply->readAll();
            qDebug() << "<<< RESPONSE RECEIVED (" << responseData.size() << "bytes)";
            parseLogsResponse(responseData, append);
        } else if (reply->error() != QNetworkReply::OperationCanceledError) {
            const QByteArray errBody = reply->readAll();
            qDebug() << "!!! NETWORK ERROR:" << reply->errorString() << "body:" << errBody.left(800);
            emit errorOccurred(reply->errorString());
        }
        if (m_currentReply == reply) m_currentReply = nullptr;
        reply->deleteLater();
    });
}

void GrafanaClient::fetchMappings(const QString& url, const QString& token, const QString& uid, const QString& user, const QString& pass) {
    Config config { url, token, uid, user, pass };
    emit loadingChanged(true);

    // Datasource-agnostic discovery via Grafana's universal /api/ds/query.
    // Pull a 24h sample with a high limit and harvest labels from returned streams.
    QJsonObject requestBody;
    requestBody["from"] = "now-24h";
    requestBody["to"] = "now";

    QJsonObject query;
    query["refId"] = "A";
    QJsonObject datasource;
    datasource["uid"] = config.datasourceUid;
    query["datasource"] = datasource;
    query["expr"] = "{}";
    query["queryType"] = "range";
    query["limit"] = 10000;

    QJsonArray queries;
    queries.append(query);
    requestBody["queries"] = queries;

    QUrl apiUrl(config.url + "/api/ds/query");
    QNetworkRequest request(apiUrl);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    QString auth = config.getAuthHeader();
    if (!auth.isEmpty()) request.setRawHeader("Authorization", auth.toUtf8());

    qDebug() << ">>> DISCOVERING via:" << apiUrl.toString();
    QNetworkReply* reply = m_manager->post(request, QJsonDocument(requestBody).toJson());

    connect(reply, &QNetworkReply::finished, this, [this, config, reply]() {
        const QByteArray body = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            qDebug() << "!!! DISCOVERY ERROR:" << reply->errorString() << "body:" << body.left(500);
            emit loadingChanged(false);
            emit errorOccurred("Namespace discovery failed: " + reply->errorString() + "\n" + QString::fromUtf8(body.left(500)));
            reply->deleteLater();
            return;
        }

        QJsonDocument doc = QJsonDocument::fromJson(body);
        reply->deleteLater();

        const QStringList nsCandidates = {"_namespace", "namespace", "env", "project"};
        const QStringList appCandidates = {"_appName", "app", "service", "job"};

        QVariantMap mappings;
        QString nsKey, appKey;
        QSet<QString> seenLabelKeys;

        const QJsonArray frames = doc.object()["results"].toObject()["A"].toObject()["frames"].toArray();
        for (const auto& frameRef : frames) {
            QJsonObject frame = frameRef.toObject();
            QJsonArray fields = frame["schema"].toObject()["fields"].toArray();
            QJsonArray values = frame["data"].toObject()["values"].toArray();

            int labelsIdx = -1;
            for (int i = 0; i < fields.size(); ++i) {
                if (fields[i].toObject()["name"].toString() == "labels") { labelsIdx = i; break; }
            }
            if (labelsIdx == -1 || values.size() <= labelsIdx) continue;

            const QJsonArray labelsArr = values[labelsIdx].toArray();
            for (const auto& lRef : labelsArr) {
                QJsonObject labels = lRef.toObject();
                for (auto it = labels.begin(); it != labels.end(); ++it) seenLabelKeys.insert(it.key());

                if (nsKey.isEmpty()) for (const auto& c : nsCandidates) if (labels.contains(c)) { nsKey = c; break; }
                if (appKey.isEmpty()) for (const auto& c : appCandidates) if (labels.contains(c)) { appKey = c; break; }
                if (nsKey.isEmpty() || appKey.isEmpty()) continue;

                QString ns = labels[nsKey].toString();
                QString app = labels[appKey].toString();
                if (ns.isEmpty()) continue;
                if (app.isEmpty()) app = "unknown";

                QStringList apps = mappings[ns].toStringList();
                if (!apps.contains(app)) { apps.append(app); mappings[ns] = apps; }
            }
        }

        if (nsKey.isEmpty() || appKey.isEmpty()) {
            QStringList seen = seenLabelKeys.values();
            seen.sort();
            qDebug() << "!!! No matching ns/app labels. Seen:" << seen;
            emit loadingChanged(false);
            emit errorOccurred(QString("No matching namespace/app labels.\nSeen labels: %1").arg(seen.isEmpty() ? "(none — empty result)" : seen.join(", ")));
            return;
        }

        qDebug() << ">>> Phase 1: seeded with" << mappings.keys().size() << "namespaces. Labels:" << nsKey << "/" << appKey << "— enumerating all pairs via metric query…";

        // Phase 2: enumerate all (ns, app) pairs via a metric query. count_over_time returns one
        // series per unique label combination — independent of log volume — so we get the full set
        // even when phase-1 logs were dominated by a few noisy namespaces.
        QJsonObject metricQuery;
        metricQuery["refId"] = "A";
        QJsonObject ds;
        ds["uid"] = config.datasourceUid;
        metricQuery["datasource"] = ds;
        // VictoriaLogs LogsQL: aggregate by (ns, app) to enumerate every unique stream pair.
        metricQuery["expr"] = QString("* | stats by (%1, %2) count()").arg(nsKey, appKey);
        metricQuery["queryType"] = "instant";
        metricQuery["maxDataPoints"] = 10000;

        QJsonArray metricQueries;
        metricQueries.append(metricQuery);
        QJsonObject metricBody;
        metricBody["from"] = "now-24h";
        metricBody["to"] = "now";
        metricBody["queries"] = metricQueries;

        QUrl metricUrl(config.url + "/api/ds/query");
        QNetworkRequest metricReq(metricUrl);
        metricReq.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        QString auth = config.getAuthHeader();
        if (!auth.isEmpty()) metricReq.setRawHeader("Authorization", auth.toUtf8());

        QNetworkReply* metricReply = m_manager->post(metricReq, QJsonDocument(metricBody).toJson());

        connect(metricReply, &QNetworkReply::finished, this, [this, metricReply, mappings, nsKey, appKey]() mutable {
            emit loadingChanged(false);
            const QByteArray body = metricReply->readAll();
            metricReply->deleteLater();

            if (metricReply->error() != QNetworkReply::NoError) {
                qDebug() << "!!! Phase 2 metric query failed, falling back to phase 1 mappings:" << metricReply->errorString() << "body:" << body.left(500);
                emit mappingsReceived(mappings, nsKey, appKey);
                return;
            }

            // VictoriaLogs returns stats results as log-shaped frames: each "Line" value is a
            // JSON string carrying the grouped fields (e.g. {"_namespace":"...","_appName":"..."}).
            QJsonDocument doc = QJsonDocument::fromJson(body);
            const QJsonArray frames = doc.object()["results"].toObject()["A"].toObject()["frames"].toArray();
            int added = 0;
            for (const auto& frameRef : frames) {
                QJsonObject frame = frameRef.toObject();
                QJsonArray fields = frame["schema"].toObject()["fields"].toArray();
                QJsonArray values = frame["data"].toObject()["values"].toArray();

                int lineIdx = -1;
                for (int i = 0; i < fields.size(); ++i) {
                    QString name = fields[i].toObject()["name"].toString();
                    if (name == "Line" || name == "message") { lineIdx = i; break; }
                }
                if (lineIdx == -1 || values.size() <= lineIdx) continue;

                const QJsonArray lines = values[lineIdx].toArray();
                for (const auto& lRef : lines) {
                    QJsonObject row = QJsonDocument::fromJson(lRef.toString().toUtf8()).object();
                    QString ns = row[nsKey].toString();
                    QString app = row[appKey].toString();
                    if (ns.isEmpty()) continue;
                    if (app.isEmpty()) app = "unknown";

                    QStringList apps = mappings[ns].toStringList();
                    if (!apps.contains(app)) { apps.append(app); mappings[ns] = apps; ++added; }
                }
            }

            qDebug() << ">>> Phase 2: added" << added << "pairs;" << mappings.keys().size() << "namespaces total.";
            emit mappingsReceived(mappings, nsKey, appKey);
        });
    });
}

void GrafanaClient::parseLogsResponse(const QByteArray& data, bool append) {
    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonObject results = doc.object()["results"].toObject();
    QJsonObject resA = results["A"].toObject();
    QJsonArray frames = resA["frames"].toArray();
    
    if (frames.isEmpty()) {
        qDebug() << "!!! NO FRAMES IN RESPONSE. Status:" << resA["status"].toInt() << "Error:" << resA["error"].toString();
    }

    QList<LogEntry> entries;
    for (const auto& frameRef : frames) {
        QJsonObject frame = frameRef.toObject();
        QJsonArray fields = frame["schema"].toObject()["fields"].toArray();
        QJsonArray values = frame["data"].toObject()["values"].toArray();
        
        if (values.isEmpty()) {
            qDebug() << ">>> Frame has no values (empty search results)";
            continue;
        }
        
        int rowCount = values[0].toArray().size();
        qDebug() << ">>> Parsing frame with" << rowCount << "rows";
        QMap<QString, int> fieldMap;
        for (int i = 0; i < fields.size(); ++i) {
            QString name = fields[i].toObject()["name"].toString();
            fieldMap[name] = i;
        }
        
        for (int r = 0; r < rowCount; ++r) {
            LogEntry entry;
            entry.timestamp = QDateTime::currentDateTime();
            
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
                        entry.allFields[lit.key()] = lit.value().toString();
                    }
                } else {
                    entry.allFields[colName] = val.toVariant();
                }
            }
            
            entries.append(entry);
        }
    }
    qDebug() << ">>> Total entries parsed:" << entries.size();
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
    emit facetsReceived(m_currentFacets);
}
