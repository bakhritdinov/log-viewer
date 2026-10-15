#pragma once

#include "core/data/Http.h"

class QNetworkAccessManager;

namespace lv {

// HttpClient over QNetworkAccessManager (desktop, mobile and WebAssembly alike).
class QtHttpClient : public HttpClient {
public:
    QtHttpClient();
    ~QtHttpClient() override;

    HttpCall* send(const HttpRequest& request) override;

private:
    QNetworkAccessManager* m_manager;
};

} // namespace lv
