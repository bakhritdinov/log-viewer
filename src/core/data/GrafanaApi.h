#pragma once

#include <QByteArray>
#include <QMap>
#include <QString>
#include <QStringList>
#include <QUrl>

#include "core/data/Http.h"
#include "core/domain/LogEntry.h"

namespace lv {

// How to reach one Grafana datasource. A token takes precedence over user/password.
struct Connection {
    QUrl baseUrl;
    QString datasourceUid;
    QString user;
    QString password;
    QString token;

    bool isConfigured() const { return baseUrl.isValid() && !baseUrl.isEmpty() && !datasourceUid.isEmpty(); }
    QByteArray authorizationHeader() const;   // empty when anonymous
    bool operator==(const Connection& other) const = default;
};

// Per-request row cap of /api/ds/query (the chained loader pages around it).
inline constexpr int kBatchLimit = 1000;

// POST {base}/api/ds/query for a range query. `from`/`to` are Grafana time
// expressions ("now-3600s", "now") or ISO dates.
HttpRequest logsQueryRequest(const Connection& c, const QString& expr,
                             const QString& from, const QString& to, int limit = kBatchLimit);

// Label discovery, phase 1: a 24h sample of streams (`{}`) to learn which label
// names carry namespace and app, plus a first set of pairs.
HttpRequest discoveryRequest(const Connection& c);

// Label discovery, phase 2: every distinct (namespace, app) pair over 24h.
HttpRequest streamPairsRequest(const Connection& c, const QString& nsLabel, const QString& appLabel);

struct ParsedLogs {
    LogEntries entries;
    // Datasource-level error reported inside an otherwise successful response
    // (e.g. a LogsQL syntax error), or a malformed body. Empty on success.
    QString error;
};
ParsedLogs parseLogsResponse(const QByteArray& body);

// namespace → apps (insertion order kept, duplicates dropped).
using StreamMap = QMap<QString, QStringList>;

struct DiscoveryResult {
    QString nsLabel;
    QString appLabel;
    StreamMap streams;
    // Label names seen when no namespace/app pair could be identified.
    QStringList seenLabels;
    QString error;

    bool found() const { return !nsLabel.isEmpty() && !appLabel.isEmpty(); }
};

// Label-name candidates, in priority order.
const QStringList& namespaceLabelCandidates();
const QStringList& appLabelCandidates();

DiscoveryResult parseDiscoveryResponse(const QByteArray& body);
// Adds the pairs of a phase-2 response to `streams`; returns how many were new.
int mergeStreamPairs(const QByteArray& body, const QString& nsLabel, const QString& appLabel,
                     StreamMap& streams);

} // namespace lv
