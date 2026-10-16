#include "core/data/RetryingHttpClient.h"

namespace lv {

namespace {

class RetryingCall : public HttpCall {
public:
    RetryingCall(HttpClient& inner, HttpRequest request, QList<int> delaysMs)
        : m_inner(inner), m_request(std::move(request)), m_delaysMs(std::move(delaysMs))
    {
        m_wait.setSingleShot(true);
        connect(&m_wait, &QTimer::timeout, this, &RetryingCall::attempt);
        attempt();
    }

    void abort() override
    {
        if (m_done) return;
        m_wait.stop();
        if (m_current) {
            m_current->abort();          // finishes with Cancelled → passed on
            return;
        }
        HttpResponse r;
        r.failure = HttpResponse::Failure::Cancelled;
        r.errorString = QStringLiteral("aborted");
        finish(r);
    }

private:
    void attempt()
    {
        m_current = m_inner.send(m_request);
        connect(m_current, &HttpCall::finished, this, [this](const HttpResponse& r) {
            m_current = nullptr;
            if (m_retries < m_delaysMs.size() && RetryingHttpClient::isTransient(r)) {
                m_wait.start(m_delaysMs.at(m_retries++));
                return;
            }
            finish(r);
        });
    }

    void finish(const HttpResponse& r)
    {
        if (m_done) return;
        m_done = true;
        emit finished(r);
        deleteLater();
    }

    HttpClient& m_inner;
    HttpRequest m_request;
    QList<int> m_delaysMs;
    QPointer<HttpCall> m_current;
    QTimer m_wait;
    int m_retries = 0;
    bool m_done = false;
};

} // namespace

RetryingHttpClient::RetryingHttpClient(HttpClient& inner, QList<int> delaysMs)
    : m_inner(inner), m_delaysMs(std::move(delaysMs))
{
}

HttpCall* RetryingHttpClient::send(const HttpRequest& request)
{
    return new RetryingCall(m_inner, request, m_delaysMs);
}

bool RetryingHttpClient::isTransient(const HttpResponse& response)
{
    using F = HttpResponse::Failure;
    switch (response.failure) {
        case F::HostNotFound:
        case F::ConnectionRefused:
        case F::RemoteClosed:
        case F::Other:
            return true;
        case F::None:
        case F::Timeout:
        case F::Tls:
        case F::Cancelled:
            return false;
    }
    return false;
}

} // namespace lv
