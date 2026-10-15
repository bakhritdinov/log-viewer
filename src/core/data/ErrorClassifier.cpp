#include "core/data/ErrorClassifier.h"

namespace lv {

namespace {

constexpr qsizetype kDetailLimit = 600;

bool mentionsTimeout(const QString& text)
{
    return text.contains(u"timeout", Qt::CaseInsensitive)
        || text.contains(u"deadline exceeded", Qt::CaseInsensitive)
        || text.contains(u"timed out", Qt::CaseInsensitive);
}

QString detailOf(const HttpResponse& r)
{
    const QString body = QString::fromUtf8(r.body.left(kDetailLimit)).trimmed();
    return body.isEmpty() ? r.errorString : body;
}

} // namespace

RequestError classifyResponse(const HttpResponse& r, const QString& datasourceError, ClassifyOptions options)
{
    using K = RequestError::Kind;
    RequestError e;
    e.httpStatus = r.status;

    switch (r.failure) {
        case HttpResponse::Failure::Cancelled:
            e.kind = K::Cancelled;
            return e;
        case HttpResponse::Failure::Timeout:
            e.kind = K::TooHeavy;
            e.detail = r.errorString;
            return e;
        case HttpResponse::Failure::Tls:
            e.kind = K::Tls;
            e.detail = r.errorString;
            return e;
        case HttpResponse::Failure::HostNotFound:
        case HttpResponse::Failure::ConnectionRefused:
        case HttpResponse::Failure::RemoteClosed:
        case HttpResponse::Failure::Other:
            e.kind = options.browser ? K::BlockedByBrowser : K::Unreachable;
            e.detail = r.errorString;
            return e;
        case HttpResponse::Failure::None:
            break;
    }

    e.detail = detailOf(r);
    const int s = r.status;
    if (s == 401) { e.kind = K::Unauthorized; return e; }
    if (s == 403) { e.kind = K::Forbidden; return e; }
    if (s == 404) { e.kind = K::NotFound; return e; }
    if (s == 429) { e.kind = K::RateLimited; return e; }
    if (s == 408 || s == 504 || (s >= 500 && mentionsTimeout(e.detail))) { e.kind = K::TooHeavy; return e; }
    if (s >= 500) { e.kind = K::Server; return e; }
    if (s >= 400) { e.kind = K::BadQuery; return e; }
    if (s < 200 || s >= 300) { e.kind = K::InvalidResponse; return e; }

    if (!datasourceError.isEmpty()) {
        e.detail = datasourceError.left(kDetailLimit);
        e.kind = datasourceError.startsWith(u"Malformed response") ? K::InvalidResponse
               : mentionsTimeout(datasourceError) ? K::TooHeavy
               : K::BadQuery;
        return e;
    }
    e.detail.clear();
    e.kind = K::None;
    return e;
}

} // namespace lv
