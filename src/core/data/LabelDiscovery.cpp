#include "core/data/LabelDiscovery.h"

namespace lv {

LabelDiscovery::LabelDiscovery(HttpClient& http, ClassifyOptions options, QObject* parent)
    : QObject(parent), m_http(http), m_options(options)
{
}

LabelDiscovery::~LabelDiscovery()
{
    cancel();
}

void LabelDiscovery::cancel()
{
    if (!m_call) return;
    HttpCall* call = m_call;
    m_call = nullptr;      // the Cancelled result is ignored by the handlers
    call->disconnect(this);
    call->abort();
}

void LabelDiscovery::track(HttpCall* call, void (LabelDiscovery::*handler)(const HttpResponse&))
{
    m_call = call;
    connect(call, &HttpCall::finished, this, [this, call, handler](const HttpResponse& r) {
        if (m_call != call) return;   // superseded
        m_call = nullptr;
        (this->*handler)(r);
    });
}

void LabelDiscovery::start(const Connection& connection, const QString& nsLabel, const QString& appLabel)
{
    cancel();
    if (!connection.isConfigured()) {
        emit failed({ RequestError::Kind::NotConfigured, 0, {} });
        return;
    }
    m_connection = connection;
    m_partial = {};
    if (!nsLabel.isEmpty() && !appLabel.isEmpty()) {
        m_partial.nsLabel = nsLabel;
        m_partial.appLabel = appLabel;
        track(m_http.send(streamPairsRequest(connection, nsLabel, appLabel)), &LabelDiscovery::onPairsOnly);
        return;
    }
    track(m_http.send(discoveryRequest(connection)), &LabelDiscovery::onPhase1);
}

void LabelDiscovery::onPhase1(const HttpResponse& r)
{
    const DiscoveryResult parsed = r.ok() ? parseDiscoveryResponse(r.body) : DiscoveryResult{};
    const RequestError err = classifyResponse(r, parsed.error, m_options);
    if (err.kind == RequestError::Kind::Cancelled) return;
    if (err.isError()) {
        emit failed(err);
        return;
    }
    if (!parsed.found()) {
        emit failed({ RequestError::Kind::UnknownLabels, r.status, parsed.seenLabels.join(QStringLiteral(", ")) });
        return;
    }
    m_partial = parsed;
    emit labelsFound(parsed.nsLabel, parsed.appLabel);
    track(m_http.send(streamPairsRequest(m_connection, parsed.nsLabel, parsed.appLabel)),
          &LabelDiscovery::onPhase2);
}

void LabelDiscovery::onPairsOnly(const HttpResponse& r)
{
    // Labels chosen by the user: the pairs request is the only check, so its
    // errors (unreachable, 401, unknown datasource) are reported.
    const RequestError err = classifyResponse(r, {}, m_options);
    if (err.kind == RequestError::Kind::Cancelled) return;
    if (err.isError()) {
        emit failed(err);
        return;
    }
    emit labelsFound(m_partial.nsLabel, m_partial.appLabel);
    mergeStreamPairs(r.body, m_partial.nsLabel, m_partial.appLabel, m_partial.streams);
    emit finished(m_partial);
}

void LabelDiscovery::onPhase2(const HttpResponse& r)
{
    if (r.failure == HttpResponse::Failure::Cancelled) return;
    // Phase 2 only widens the set; on any failure keep what phase 1 found.
    if (r.ok()) mergeStreamPairs(r.body, m_partial.nsLabel, m_partial.appLabel, m_partial.streams);
    emit finished(m_partial);
}

} // namespace lv
