#pragma once

#include <QString>
#include <QUrl>
#include <optional>

#include "core/domain/TimeRange.h"

namespace lv {

// The part of a search that can be handed to a colleague. No URL or secrets:
// the environment travels by name and must exist on the receiving side.
struct SharedView {
    QString environment;
    QString namespaceName;
    QString app;
    QString searchText;
    TimeRange range;
    qint64 anchorMs = 0;       // entry to highlight; 0 = none

    bool operator==(const SharedView& other) const = default;
};

// Encoded as query parameters: env, ns, app, q, range ("1h", "today", or
// from/to in epoch ms for a fixed period) and at (anchor). Version "v=1".
QString encodeSharedViewQuery(const SharedView& view);

// Desktop deep link: logviewer://open?<query>.
QUrl desktopShareUrl(const SharedView& view);
// PWA link: <base>#/open?<query>.
QUrl webShareUrl(const QUrl& base, const SharedView& view);

// Accepts both forms (and a bare query string). nullopt when the link is not
// ours, misses the environment/namespace/app, or carries an invalid range.
std::optional<SharedView> parseShareUrl(const QUrl& url);

} // namespace lv
