#include "app/ErrorInfo.h"

#include <QCoreApplication>

namespace lv {

namespace {
QString tr(const char* text)
{
    return QCoreApplication::translate("ErrorInfo", text);
}
} // namespace

ErrorInfo ErrorInfo::from(const RequestError& error, const QString& environmentName, const QString& host)
{
    using RK = RequestError::Kind;
    ErrorInfo e;
    e.detail = error.detail;
    e.httpStatus = error.httpStatus;
    const QString where = host.isEmpty() ? tr("the server") : host;

    switch (error.kind) {
        case RK::None:
        case RK::Cancelled:
            return {};
        case RK::Unreachable:
            e.kind = Kind::Unreachable;
            e.title = tr("Cannot reach the server");
            e.message = tr("Could not connect to %1. It may only be reachable from the internal network — check your VPN.").arg(where);
            e.primaryAction = Action::Retry;
            e.secondaryAction = Action::OpenSettings;
            break;
        case RK::BlockedByBrowser:
            e.kind = Kind::BlockedByBrowser;
            e.title = tr("The browser blocked the request");
            e.message = tr("Either %1 is unreachable (check your VPN) or Grafana does not allow requests from this app (CORS). CORS is configured on the server side.").arg(where);
            e.primaryAction = Action::Retry;
            e.secondaryAction = Action::CopyCorsHint;
            break;
        case RK::Tls:
            e.kind = Kind::Tls;
            e.title = tr("Secure connection failed");
            e.message = tr("The certificate of %1 was not accepted.").arg(where);
            e.primaryAction = Action::OpenSettings;
            e.secondaryAction = Action::CopyDetails;
            break;
        case RK::Unauthorized:
            e.kind = Kind::Unauthorized;
            e.title = tr("Wrong login or password");
            e.message = environmentName.isEmpty()
                ? tr("Grafana rejected the credentials. If the password changed recently, update it.")
                : tr("Grafana rejected the credentials of %1. If the password changed recently, update it.").arg(environmentName);
            e.primaryAction = Action::OpenSettings;
            e.secondaryAction = Action::Retry;
            break;
        case RK::Forbidden:
            e.kind = Kind::Forbidden;
            e.title = tr("No access to the datasource");
            e.message = tr("The account is valid but may not query this datasource.");
            e.primaryAction = Action::OpenSettings;
            e.secondaryAction = Action::CopyDetails;
            break;
        case RK::NotFound:
            e.kind = Kind::NotFound;
            e.title = tr("Datasource not found");
            e.message = tr("Grafana has no datasource with this UID, or the URL is wrong.");
            e.primaryAction = Action::OpenSettings;
            e.secondaryAction = Action::Retry;
            break;
        case RK::TooHeavy:
            e.kind = Kind::TooHeavy;
            e.title = tr("The query is too heavy");
            e.message = tr("It took too long. Narrow the time range or add a condition.");
            e.primaryAction = Action::NarrowRange;
            e.secondaryAction = Action::EditQuery;
            break;
        case RK::RateLimited:
            e.kind = Kind::RateLimited;
            e.title = tr("Too many requests");
            e.message = tr("The server asked to slow down. Try again in a moment.");
            e.primaryAction = Action::Retry;
            break;
        case RK::BadQuery:
            e.kind = Kind::BadQuery;
            e.title = tr("The query was rejected");
            e.message = tr("The datasource could not run this search. Check the syntax of the search text.");
            e.primaryAction = Action::EditQuery;
            e.secondaryAction = Action::CopyDetails;
            break;
        case RK::Server:
            e.kind = Kind::Server;
            e.title = tr("Grafana error");
            e.message = tr("Grafana or the log storage is temporarily unavailable.");
            e.primaryAction = Action::Retry;
            e.secondaryAction = Action::CopyDetails;
            break;
        case RK::InvalidResponse:
            e.kind = Kind::InvalidResponse;
            e.title = tr("Unexpected response");
            e.message = tr("The server answered with something that is not a Grafana response. Check the URL.");
            e.primaryAction = Action::OpenSettings;
            e.secondaryAction = Action::CopyDetails;
            break;
        case RK::NotConfigured:
            e.kind = Kind::NotConfigured;
            e.title = tr("Connect to Grafana");
            e.message = tr("Enter the Grafana URL, the log datasource UID and credentials.");
            e.primaryAction = Action::OpenSettings;
            break;
        case RK::UnknownLabels:
            e.kind = Kind::UnknownLabels;
            e.title = tr("No namespaces found");
            e.message = error.detail.isEmpty()
                ? tr("The datasource returned no log streams for the last 24 hours.")
                : tr("No namespace/app labels were recognized. Labels seen: %1.").arg(error.detail);
            e.primaryAction = Action::Retry;
            e.secondaryAction = Action::OpenSettings;
            break;
    }

    auto label = [](Action a) -> QString {
        switch (a) {
            case Action::Retry: return tr("Retry");
            case Action::OpenSettings: return tr("Settings");
            case Action::NarrowRange: return tr("Last 1 hour");
            case Action::CopyCorsHint: return tr("Copy instructions for DevOps");
            case Action::CopyDetails: return tr("Copy details");
            case Action::EditQuery: return tr("Edit query");
            case Action::None: break;
        }
        return {};
    };
    e.primaryLabel = label(e.primaryAction);
    e.secondaryLabel = label(e.secondaryAction);
    return e;
}

QString corsHintForDevOps(const QString& pwaOrigin)
{
    const QString origin = pwaOrigin.isEmpty() ? QStringLiteral("https://<pwa-host>") : pwaOrigin;
    return QStringLiteral(
        "# nginx in front of Grafana: allow the LogViewer PWA to call the query API\n"
        "location /api/ {\n"
        "    if ($request_method = OPTIONS) {\n"
        "        add_header Access-Control-Allow-Origin \"%1\" always;\n"
        "        add_header Access-Control-Allow-Credentials \"true\" always;\n"
        "        add_header Access-Control-Allow-Methods \"GET, POST, OPTIONS\" always;\n"
        "        add_header Access-Control-Allow-Headers \"Authorization, Content-Type\" always;\n"
        "        add_header Access-Control-Max-Age 86400 always;\n"
        "        return 204;\n"
        "    }\n"
        "    add_header Access-Control-Allow-Origin \"%1\" always;\n"
        "    add_header Access-Control-Allow-Credentials \"true\" always;\n"
        "    proxy_pass http://grafana;\n"
        "}\n").arg(origin);
}

} // namespace lv
