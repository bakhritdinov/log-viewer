#include "core/features/ShareLink.h"

#include <QTimeZone>
#include <QUrlQuery>

namespace lv {

namespace {

std::optional<SharedView> fromQuery(const QUrlQuery& q)
{
    if (q.queryItemValue("v") != u"1") return std::nullopt;
    SharedView v;
    v.environment = q.queryItemValue("env", QUrl::FullyDecoded);
    v.namespaceName = q.queryItemValue("ns", QUrl::FullyDecoded);
    v.app = q.queryItemValue("app", QUrl::FullyDecoded);
    v.searchText = q.queryItemValue("q", QUrl::FullyDecoded);
    if (v.environment.isEmpty() || v.namespaceName.isEmpty() || v.app.isEmpty()) return std::nullopt;

    if (q.hasQueryItem("from") || q.hasQueryItem("to")) {
        bool okFrom = false;
        bool okTo = false;
        const qint64 from = q.queryItemValue("from").toLongLong(&okFrom);
        const qint64 to = q.queryItemValue("to").toLongLong(&okTo);
        if (!okFrom || !okTo) return std::nullopt;
        const auto r = TimeRange::absolute(QDateTime::fromMSecsSinceEpoch(from, QTimeZone::UTC),
                                           QDateTime::fromMSecsSinceEpoch(to, QTimeZone::UTC));
        if (!r) return std::nullopt;
        v.range = *r;
    } else {
        v.range = TimeRange::fromKey(q.queryItemValue("range"));
    }
    v.anchorMs = q.queryItemValue("at").toLongLong();
    return v;
}

} // namespace

QString encodeSharedViewQuery(const SharedView& view)
{
    QUrlQuery q;
    q.addQueryItem("v", "1");
    q.addQueryItem("env", view.environment);
    q.addQueryItem("ns", view.namespaceName);
    q.addQueryItem("app", view.app);
    if (!view.searchText.isEmpty()) q.addQueryItem("q", view.searchText);
    if (view.range.kind() == TimeRange::Kind::Absolute) {
        q.addQueryItem("from", QString::number(view.range.absoluteFrom().toMSecsSinceEpoch()));
        q.addQueryItem("to", QString::number(view.range.absoluteTo().toMSecsSinceEpoch()));
    } else {
        q.addQueryItem("range", view.range.key());
    }
    if (view.anchorMs > 0) q.addQueryItem("at", QString::number(view.anchorMs));
    // Encode everything that could break the surrounding URL (incl. the
    // fragment form, where '#' and '&' must not leak).
    QString out;
    for (const auto& [key, value] : q.queryItems(QUrl::FullyDecoded)) {
        if (!out.isEmpty()) out += u'&';
        out += key + u'=' + QString::fromUtf8(QUrl::toPercentEncoding(value));
    }
    return out;
}

QUrl desktopShareUrl(const SharedView& view)
{
    QUrl u;
    u.setScheme("logviewer");
    u.setHost("open");
    u.setQuery(encodeSharedViewQuery(view), QUrl::StrictMode);
    return u;
}

QUrl webShareUrl(const QUrl& base, const SharedView& view)
{
    QUrl u = base;
    u.setFragment(QStringLiteral("/open?") + encodeSharedViewQuery(view), QUrl::StrictMode);
    return u;
}

std::optional<SharedView> parseShareUrl(const QUrl& url)
{
    if (url.scheme() == u"logviewer") {
        if (url.host() != u"open") return std::nullopt;
        return fromQuery(QUrlQuery(url.query(QUrl::FullyEncoded)));
    }
    const QString fragment = url.fragment(QUrl::FullyEncoded);
    if (fragment.startsWith(u"/open?")) return fromQuery(QUrlQuery(fragment.mid(6)));
    if (url.scheme().isEmpty() && url.host().isEmpty()) return fromQuery(QUrlQuery(url.toString(QUrl::FullyEncoded)));
    return std::nullopt;
}

} // namespace lv
