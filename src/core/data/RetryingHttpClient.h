#pragma once

#include <QList>
#include <QPointer>
#include <QTimer>

#include "core/data/Http.h"

namespace lv {

// Sends again what a short network blip broke (refused, reset, host not found,
// blocked by the browser) before anyone sees "cannot reach the server": the
// connection often comes back within a second or two, and the user pressed
// Retry for nothing. Answers with an HTTP status, timeouts (the query is too
// heavy), TLS problems and cancels are passed on at once.
class RetryingHttpClient : public HttpClient {
public:
    // Waits before each new attempt; its size is the number of retries.
    explicit RetryingHttpClient(HttpClient& inner, QList<int> delaysMs = { 1000, 3000 });

    HttpCall* send(const HttpRequest& request) override;

    static bool isTransient(const HttpResponse& response);

private:
    HttpClient& m_inner;
    QList<int> m_delaysMs;
};

} // namespace lv
