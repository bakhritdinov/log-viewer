#pragma once

#include <QString>

#include "core/data/Http.h"

namespace lv {

// What went wrong with a request, in terms the user can act on. Wording lives
// in the UI layer; the core only decides the kind.
struct RequestError {
    enum class Kind {
        None,
        Unreachable,     // no connection: offline, VPN off, DNS, refused
        BlockedByBrowser,// browser builds: request blocked (CORS) or unreachable — indistinguishable
        Tls,             // certificate / handshake problem
        Unauthorized,    // 401 — wrong credentials
        Forbidden,       // 403 — no access to the datasource
        NotFound,        // 404 — wrong URL or datasource UID
        TooHeavy,        // timeout (client or datasource): narrow the range or add a filter
        RateLimited,     // 429
        BadQuery,        // datasource rejected the query (syntax, unknown field…)
        Server,          // 5xx
        InvalidResponse, // body could not be understood
        NotConfigured,   // no URL / datasource UID yet — show the setup screen
        UnknownLabels,   // datasource answered, but no namespace/app labels were recognized
        Cancelled,       // superseded by a newer request — not shown to the user
    };

    Kind kind = Kind::None;
    int httpStatus = 0;
    // Short raw detail (server message or transport error), for "Details".
    QString detail;

    bool isError() const { return kind != Kind::None && kind != Kind::Cancelled; }
};

struct ClassifyOptions {
    // Running inside a web browser (WebAssembly): fetch() failures without a
    // status are CORS rejections as often as network outages.
    bool browser = false;
};

// Classifies a transport result. `datasourceError` is the error reported inside a
// 200 body (results.A.error), if any.
RequestError classifyResponse(const HttpResponse& response, const QString& datasourceError = {},
                              ClassifyOptions options = {});

} // namespace lv
