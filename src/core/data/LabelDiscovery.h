#pragma once

#include <QObject>
#include <QPointer>

#include "core/data/ErrorClassifier.h"
#include "core/data/GrafanaApi.h"

namespace lv {

// Finds which labels identify namespace and app, and every (namespace, app)
// pair over the last 24h. Phase 1 samples streams to learn the label names;
// phase 2 enumerates all pairs. A failing phase 2 falls back to phase 1 pairs.
class LabelDiscovery : public QObject {
    Q_OBJECT
public:
    LabelDiscovery(HttpClient& http, ClassifyOptions options = {}, QObject* parent = nullptr);
    ~LabelDiscovery() override;

    // Starts discovery, cancelling one already running. With both labels given
    // (chosen by the user) phase 1 is skipped.
    void start(const Connection& connection, const QString& nsLabel = {}, const QString& appLabel = {});
    void cancel();
    bool isRunning() const { return m_call != nullptr; }

signals:
    // Phase 1 answered: the server is reachable, the login and the datasource
    // are fine and the labels are known; phase 2 (all pairs) is under way.
    void labelsFound(const QString& nsLabel, const QString& appLabel);
    void finished(const lv::DiscoveryResult& result);
    // kind UnknownLabels carries the label names that were seen in `detail`.
    void failed(const lv::RequestError& error);

private:
    void onPhase1(const HttpResponse& r);
    void onPhase2(const HttpResponse& r);
    void onPairsOnly(const HttpResponse& r);
    void track(HttpCall* call, void (LabelDiscovery::*handler)(const HttpResponse&));

    HttpClient& m_http;
    ClassifyOptions m_options;
    Connection m_connection;
    DiscoveryResult m_partial;
    QPointer<HttpCall> m_call;
};

} // namespace lv
