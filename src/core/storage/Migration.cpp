#include "core/storage/Migration.h"

#include <QSet>
#include <algorithm>

#include "core/storage/UserData.h"

namespace lv {

namespace {

// Per-environment field names used by LogViewer 2.x.
const QStringList kEnvFields = { "url", "uid", "user", "pass", "token", "lastNamespace", "lastApp" };

QString colorFor(const QString& name, int index)
{
    if (name.compare(u"PROD", Qt::CaseInsensitive) == 0) return environmentColors().at(2);
    if (name.compare(u"DEV", Qt::CaseInsensitive) == 0) return environmentColors().at(0);
    return environmentColors().at((index + 1) % environmentColors().size());
}

} // namespace

LegacyMigration planLegacyMigration(const KeyValueStore& store)
{
    LegacyMigration m;
    if (store.value(kSchemaKey).toInt() >= kSettingsSchemaVersion) return m;

    const QStringList keys = store.allKeys();
    const QString legacyCurrent = store.value(QStringLiteral("currentEnv")).toString();

    // Environment names: DEV and PROD as the old UI offered, plus whatever the
    // current one was, in that order, if they carry any setting.
    QStringList names = { "DEV", "PROD" };
    if (!legacyCurrent.isEmpty() && !names.contains(legacyCurrent)) names << legacyCurrent;

    int index = 0;
    for (const QString& name : names) {
        bool present = false;
        for (const QString& f : kEnvFields) present = present || store.contains(name + u'/' + f);
        if (!present) continue;

        Environment e;
        e.id = name.toLower();
        e.name = name;
        e.color = colorFor(name, index++);
        e.url = QUrl(store.value(name + "/url").toString());
        e.datasourceUid = store.value(name + "/uid").toString();
        e.user = store.value(name + "/user").toString();
        const QString pass = store.value(name + "/pass").toString();
        const QString token = store.value(name + "/token").toString();
        e.auth = !token.isEmpty() ? Environment::Auth::Token
               : (!e.user.isEmpty() || !pass.isEmpty()) ? Environment::Auth::Basic
               : Environment::Auth::None;
        if (!pass.isEmpty()) m.secrets.insert(e.passwordKey(), pass);
        if (!token.isEmpty()) m.secrets.insert(e.tokenKey(), token);

        const QString ns = store.value(name + "/lastNamespace").toString();
        const QString app = store.value(name + "/lastApp").toString();
        if (!ns.isEmpty() || !app.isEmpty()) {
            m.settings.append({ QStringLiteral("selection/%1/namespace").arg(e.id), ns });
            m.settings.append({ QStringLiteral("selection/%1/app").arg(e.id), app });
        }
        m.environments.append(e);
    }

    // Time range: "1h"-style presets carry over; "Custom" becomes absolute.
    const QString lastRange = store.value(QStringLiteral("lastTimeRange")).toString();
    if (lastRange == u"Custom") {
        const auto r = TimeRange::absolute(TimeRange::parseBound(store.value("lastCustomFrom").toString()),
                                           TimeRange::parseBound(store.value("lastCustomTo").toString()));
        if (r) m.settings.append({ QStringLiteral("selection/timeRange"), encodeTimeRange(*r) });
    } else if (!lastRange.isEmpty()) {
        m.settings.append({ QStringLiteral("selection/timeRange"), encodeTimeRange(TimeRange::fromKey(lastRange)) });
    }
    // The theme chosen in 2.x.
    if (store.contains(QStringLiteral("theme/dark")) && !store.contains(QStringLiteral("prefs/theme")))
        m.settings.append({ QStringLiteral("prefs/theme"), store.value(QStringLiteral("theme/dark")).toBool() ? "dark" : "light" });

    // Ecotone is gone: drop its settings, including its plaintext DB password.
    for (const QString& k : keys) {
        if (k.startsWith(u"ecotone/") || k.contains(u"/ecotone/")) m.keysToRemove << k;
    }

    m.needed = !m.environments.isEmpty() || !m.keysToRemove.isEmpty() || !m.settings.isEmpty();
    m.currentId = legacyCurrent.toLower();
    if (m.environments.isEmpty()) {
        m.environments = EnvironmentsStore::defaults();
    } else {
        // DEV/PROD stay available even if only one of them was configured.
        for (const Environment& d : EnvironmentsStore::defaults()) {
            const bool have = std::any_of(m.environments.cbegin(), m.environments.cend(),
                                          [&](const Environment& e) { return e.id == d.id; });
            if (!have) m.environments.append(d);
        }
    }
    m.keysToRemove.removeDuplicates();
    return m;
}

} // namespace lv
