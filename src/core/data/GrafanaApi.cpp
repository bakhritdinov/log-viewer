#include "core/data/GrafanaApi.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QTimeZone>

namespace lv {

namespace {

HttpRequest dsQuery(const Connection& c, const QJsonObject& query, const QString& from, const QString& to)
{
    QJsonObject body;
    body["from"] = from;
    body["to"] = to;
    body["queries"] = QJsonArray{ query };

    HttpRequest r;
    QUrl url = c.baseUrl;
    url.setPath(url.path().chopped(url.path().endsWith(u'/') ? 1 : 0) + QStringLiteral("/api/ds/query"));
    r.url = url;
    r.headers.emplaceBack(QByteArrayLiteral("Content-Type"), QByteArrayLiteral("application/json"));
    const QByteArray auth = c.authorizationHeader();
    if (!auth.isEmpty()) r.headers.emplaceBack(QByteArrayLiteral("Authorization"), auth);
    r.body = QJsonDocument(body).toJson(QJsonDocument::Compact);
    return r;
}

QJsonObject baseQuery(const Connection& c, const QString& expr)
{
    QJsonObject q;
    q["refId"] = "A";
    q["datasource"] = QJsonObject{ { "uid", c.datasourceUid } };
    q["expr"] = expr;
    return q;
}

struct Frames {
    QJsonArray frames;
    QString error;
};

// results.A of a /api/ds/query response; an error there means the datasource
// rejected the query even though Grafana answered 200.
Frames framesOf(const QByteArray& body)
{
    QJsonParseError perr;
    const QJsonDocument doc = QJsonDocument::fromJson(body, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
        return { {}, QStringLiteral("Malformed response: %1").arg(perr.errorString()) };
    const QJsonObject a = doc.object().value("results").toObject().value("A").toObject();
    return { a.value("frames").toArray(), a.value("error").toString() };
}

int columnIndex(const QJsonArray& fields, std::initializer_list<QLatin1StringView> names)
{
    for (int i = 0; i < fields.size(); ++i) {
        const QString n = fields.at(i).toObject().value("name").toString();
        for (QLatin1StringView want : names)
            if (n == want) return i;
    }
    return -1;
}

void addPair(StreamMap& streams, const QString& ns, QString app, int* added = nullptr)
{
    if (ns.isEmpty()) return;
    if (app.isEmpty()) app = QStringLiteral("unknown");
    QStringList& apps = streams[ns];
    if (apps.contains(app)) return;
    apps.append(app);
    if (added) ++*added;
}

} // namespace

QByteArray Connection::authorizationHeader() const
{
    if (!token.isEmpty()) return "Bearer " + token.toUtf8();
    if (!user.isEmpty()) return "Basic " + (user + u':' + password).toUtf8().toBase64();
    return {};
}

HttpRequest logsQueryRequest(const Connection& c, const QString& expr, const QString& from,
                             const QString& to, int limit)
{
    QJsonObject q = baseQuery(c, expr);
    q["queryType"] = "range";
    q["limit"] = limit;
    q["maxLines"] = limit;   // the VictoriaLogs plugin reads this knob, not "limit"
    return dsQuery(c, q, from, to);
}

HttpRequest discoveryRequest(const Connection& c)
{
    QJsonObject q = baseQuery(c, QStringLiteral("{}"));
    q["queryType"] = "range";
    q["limit"] = 10000;
    return dsQuery(c, q, QStringLiteral("now-24h"), QStringLiteral("now"));
}

HttpRequest streamPairsRequest(const Connection& c, const QString& nsLabel, const QString& appLabel)
{
    // count() per (ns, app) yields one row per distinct pair regardless of volume,
    // so quiet streams are not drowned by noisy ones as in the phase-1 sample.
    QJsonObject q = baseQuery(c, QStringLiteral("* | stats by (%1, %2) count()").arg(nsLabel, appLabel));
    q["queryType"] = "instant";
    q["maxDataPoints"] = 10000;
    return dsQuery(c, q, QStringLiteral("now-24h"), QStringLiteral("now"));
}

ParsedLogs parseLogsResponse(const QByteArray& body)
{
    const Frames f = framesOf(body);
    ParsedLogs out;
    out.error = f.error;
    for (const QJsonValue& frameRef : f.frames) {
        const QJsonObject frame = frameRef.toObject();
        const QJsonArray fields = frame.value("schema").toObject().value("fields").toArray();
        const QJsonArray values = frame.value("data").toObject().value("values").toArray();
        if (values.isEmpty()) continue;

        const qsizetype rows = values.at(0).toArray().size();
        for (qsizetype r = 0; r < rows; ++r) {
            LogEntry e;
            bool haveTime = false;
            for (int col = 0; col < fields.size() && col < values.size(); ++col) {
                const QString name = fields.at(col).toObject().value("name").toString();
                const QJsonValue v = values.at(col).toArray().at(r);
                if (name == u"Time" || name == u"ts") {
                    e.timestamp = QDateTime::fromMSecsSinceEpoch(v.toVariant().toLongLong(), QTimeZone::UTC);
                    haveTime = true;
                } else if (name == u"Line" || name == u"message") {
                    e.message = v.toString();
                } else if (name == u"labels") {
                    const QJsonObject labels = v.toObject();
                    for (auto it = labels.begin(); it != labels.end(); ++it)
                        e.fields.insert(it.key(), it.value().toString());
                } else {
                    e.fields.insert(name, v.toVariant());
                }
            }
            // Legacy behaviour: an entry without a time column is stamped "now".
            if (!haveTime) e.timestamp = QDateTime::currentDateTimeUtc();
            e.level = levelFromFields(e.fields);
            out.entries.append(e);
        }
    }
    return out;
}

const QStringList& namespaceLabelCandidates()
{
    static const QStringList c = { "_namespace", "namespace", "env", "project" };
    return c;
}

const QStringList& appLabelCandidates()
{
    static const QStringList c = { "_appName", "app", "service", "job" };
    return c;
}

DiscoveryResult parseDiscoveryResponse(const QByteArray& body)
{
    const Frames f = framesOf(body);
    DiscoveryResult out;
    out.error = f.error;
    QSet<QString> seen;
    for (const QJsonValue& frameRef : f.frames) {
        const QJsonObject frame = frameRef.toObject();
        const QJsonArray fields = frame.value("schema").toObject().value("fields").toArray();
        const QJsonArray values = frame.value("data").toObject().value("values").toArray();
        const int labelsCol = columnIndex(fields, { QLatin1StringView("labels") });
        if (labelsCol < 0 || labelsCol >= values.size()) continue;

        for (const QJsonValue& lRef : values.at(labelsCol).toArray()) {
            const QJsonObject labels = lRef.toObject();
            for (auto it = labels.begin(); it != labels.end(); ++it) seen.insert(it.key());
            if (out.nsLabel.isEmpty()) {
                for (const QString& cand : namespaceLabelCandidates())
                    if (labels.contains(cand)) { out.nsLabel = cand; break; }
            }
            if (out.appLabel.isEmpty()) {
                for (const QString& cand : appLabelCandidates())
                    if (labels.contains(cand)) { out.appLabel = cand; break; }
            }
            if (!out.found()) continue;
            addPair(out.streams, labels.value(out.nsLabel).toString(), labels.value(out.appLabel).toString());
        }
    }
    if (!out.found()) {
        out.seenLabels = seen.values();
        out.seenLabels.sort();
    }
    return out;
}

int mergeStreamPairs(const QByteArray& body, const QString& nsLabel, const QString& appLabel,
                     StreamMap& streams)
{
    const Frames f = framesOf(body);
    int added = 0;
    for (const QJsonValue& frameRef : f.frames) {
        const QJsonObject frame = frameRef.toObject();
        const QJsonArray fields = frame.value("schema").toObject().value("fields").toArray();
        const QJsonArray values = frame.value("data").toObject().value("values").toArray();
        const int lineCol = columnIndex(fields, { QLatin1StringView("Line"), QLatin1StringView("message") });
        if (lineCol < 0 || lineCol >= values.size()) continue;
        // VictoriaLogs returns stats as log-shaped frames: each line is a JSON
        // object with the grouped fields.
        for (const QJsonValue& lRef : values.at(lineCol).toArray()) {
            const QJsonObject row = QJsonDocument::fromJson(lRef.toString().toUtf8()).object();
            addPair(streams, row.value(nsLabel).toString(), row.value(appLabel).toString(), &added);
        }
    }
    return added;
}

} // namespace lv
