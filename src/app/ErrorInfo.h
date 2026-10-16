#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

#include "core/data/ErrorClassifier.h"

namespace lv {

// A request error as the user sees it: what happened, why, and what to do.
// Shared by every design; texts are translatable (tr()).
class ErrorInfo {
    Q_GADGET
    QML_VALUE_TYPE(errorInfo)
    Q_PROPERTY(bool active READ isActive)
    Q_PROPERTY(Kind kind MEMBER kind)
    Q_PROPERTY(QString title MEMBER title)
    Q_PROPERTY(QString message MEMBER message)
    Q_PROPERTY(QString detail MEMBER detail)
    Q_PROPERTY(int httpStatus MEMBER httpStatus)
    Q_PROPERTY(Action primaryAction MEMBER primaryAction)
    Q_PROPERTY(QString primaryLabel MEMBER primaryLabel)
    Q_PROPERTY(Action secondaryAction MEMBER secondaryAction)
    Q_PROPERTY(QString secondaryLabel MEMBER secondaryLabel)

public:
    enum class Kind {
        None, Unreachable, BlockedByBrowser, Tls, Unauthorized, Forbidden, NotFound, TooHeavy,
        RateLimited, BadQuery, Server, InvalidResponse, NotConfigured, UnknownLabels, CorsBlocked
    };
    Q_ENUM(Kind)

    // What the error banner's buttons do; the design maps them to its actions.
    enum class Action { None, Retry, OpenSettings, NarrowRange, CopyCorsHint, CopyDetails, EditQuery, OpenCorsHelp };
    Q_ENUM(Action)

    Kind kind = Kind::None;
    QString title;
    QString message;
    QString detail;
    int httpStatus = 0;
    Action primaryAction = Action::None;
    QString primaryLabel;
    Action secondaryAction = Action::None;
    QString secondaryLabel;

    bool isActive() const { return kind != Kind::None; }
    bool operator==(const ErrorInfo& other) const = default;

    // `environmentName` and `host` personalise the message ("… for PROD",
    // "cannot reach grafana.example").
    static ErrorInfo from(const RequestError& error, const QString& environmentName = {},
                          const QString& host = {});
};

// Exposes ErrorInfo's enums to QML as `ErrorInfo.Retry`, `ErrorInfo.Unauthorized`…
// (a value type itself must have a lowercase name).
namespace ErrorInfoForeign {
Q_NAMESPACE
QML_NAMED_ELEMENT(ErrorInfo)
QML_FOREIGN_NAMESPACE(lv::ErrorInfo)
}

// Snippet for whoever runs the Grafana reverse proxy (CORS for the PWA).
QString corsHintForDevOps(const QString& pwaOrigin);

} // namespace lv
