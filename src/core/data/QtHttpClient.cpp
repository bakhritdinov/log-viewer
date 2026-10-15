#include "core/data/QtHttpClient.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPointer>

namespace lv {

namespace {

HttpResponse::Failure failureOf(QNetworkReply::NetworkError e, int httpStatus)
{
    // Any HTTP status means the server answered: 4xx/5xx are responses, not
    // transport failures (callers classify them by status).
    if (httpStatus > 0 && e != QNetworkReply::OperationCanceledError && e != QNetworkReply::TimeoutError)
        return HttpResponse::Failure::None;
    switch (e) {
        case QNetworkReply::NoError: return HttpResponse::Failure::None;
        case QNetworkReply::TimeoutError: return HttpResponse::Failure::Timeout;
        case QNetworkReply::OperationCanceledError: return HttpResponse::Failure::Cancelled;
        case QNetworkReply::HostNotFoundError: return HttpResponse::Failure::HostNotFound;
        case QNetworkReply::ConnectionRefusedError: return HttpResponse::Failure::ConnectionRefused;
        case QNetworkReply::SslHandshakeFailedError: return HttpResponse::Failure::Tls;
        case QNetworkReply::RemoteHostClosedError: return HttpResponse::Failure::RemoteClosed;
        default: return HttpResponse::Failure::Other;
    }
}

class QtHttpCall : public HttpCall {
public:
    explicit QtHttpCall(QNetworkReply* reply) : m_reply(reply)
    {
        reply->setParent(this);
        connect(reply, &QNetworkReply::finished, this, &QtHttpCall::onFinished);
    }

    void abort() override
    {
        if (!m_reply || !m_reply->isRunning()) return;
        m_userAborted = true;
        m_reply->abort();   // finished() fires synchronously
    }

private:
    void onFinished()
    {
        if (m_done) return;
        m_done = true;
        HttpResponse r;
        r.status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        r.body = m_reply->readAll();
        r.failure = failureOf(m_reply->error(), r.status);
        if (m_reply->error() == QNetworkReply::OperationCanceledError && !m_userAborted) {
            // setTransferTimeout() aborts with OperationCanceledError: report a timeout.
            r.failure = HttpResponse::Failure::Timeout;
        }
        if (r.failure != HttpResponse::Failure::None) r.errorString = m_reply->errorString();
        emit finished(r);
        deleteLater();
    }

    QPointer<QNetworkReply> m_reply;
    bool m_done = false;
    // Both abort() and the transfer timeout end with OperationCanceledError.
    bool m_userAborted = false;
};

} // namespace

QtHttpClient::QtHttpClient() : m_manager(new QNetworkAccessManager) {}

QtHttpClient::~QtHttpClient() { delete m_manager; }

HttpCall* QtHttpClient::send(const HttpRequest& request)
{
    QNetworkRequest req(request.url);
    for (const auto& [name, value] : request.headers) req.setRawHeader(name, value);
    if (request.timeoutMs > 0) req.setTransferTimeout(request.timeoutMs);
    QNetworkReply* reply = m_manager->sendCustomRequest(req, request.method, request.body);
    return new QtHttpCall(reply);
}

} // namespace lv
