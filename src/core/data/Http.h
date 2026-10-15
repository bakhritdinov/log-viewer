#pragma once

#include <QByteArray>
#include <QList>
#include <QObject>
#include <QPair>
#include <QString>
#include <QUrl>

namespace lv {

struct HttpRequest {
    QUrl url;
    QByteArray method = "POST";
    QList<QPair<QByteArray, QByteArray>> headers;
    QByteArray body;
    int timeoutMs = 30000;
};

struct HttpResponse {
    // Transport-level outcome; `None` means an HTTP response was received
    // (whatever its status code).
    enum class Failure { None, Timeout, HostNotFound, ConnectionRefused, Tls, RemoteClosed, Cancelled, Other };

    Failure failure = Failure::None;
    int status = 0;            // 0 when no HTTP response was received
    QByteArray body;
    QString errorString;       // transport error text, for diagnostics only

    bool ok() const { return failure == Failure::None && status >= 200 && status < 300; }
};

// One in-flight request. Emits finished() exactly once — also after abort(),
// with Failure::Cancelled — and deletes itself afterwards.
class HttpCall : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    virtual void abort() = 0;

signals:
    void finished(const lv::HttpResponse& response);
};

// Transport seam: the real client uses QNetworkAccessManager, tests use a fake.
class HttpClient {
public:
    virtual ~HttpClient() = default;
    virtual HttpCall* send(const HttpRequest& request) = 0;
};

} // namespace lv
