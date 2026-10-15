#pragma once

#include <QList>
#include <QString>
#include <QUrl>
#include <optional>

#include "core/data/GrafanaApi.h"
#include "core/storage/KeyValueStore.h"

namespace lv {

// A named Grafana connection (DEV, PROD, …). Secrets are not part of it: they
// live in the SecretStore under passwordKey() / tokenKey().
struct Environment {
    enum class Auth { None, Basic, Token };

    QString id;          // stable, generated
    QString name;        // shown to the user, also used in share links
    QString color;       // label colour, "#rrggbb"
    QUrl url;
    QString datasourceUid;
    QString user;
    Auth auth = Auth::Basic;
    // Labels that name the namespace and the app; empty: found automatically.
    QString nsLabel;
    QString appLabel;

    QString passwordKey() const { return QStringLiteral("env/%1/password").arg(id); }
    QString tokenKey() const { return QStringLiteral("env/%1/token").arg(id); }
    bool isConfigured() const { return url.isValid() && !url.isEmpty() && !datasourceUid.isEmpty(); }
    Connection connection(const QString& password, const QString& token) const;

    bool operator==(const Environment& other) const = default;
};

// Default label colours offered in Settings (green, amber, red, blue, grey).
const QStringList& environmentColors();

// Persisted list of environments plus the active one. Never empty: an empty
// store yields unconfigured DEV and PROD.
class EnvironmentsStore {
public:
    explicit EnvironmentsStore(KeyValueStore& store);

    QList<Environment> environments() const { return m_list; }
    std::optional<Environment> find(const QString& id) const;
    std::optional<Environment> findByName(const QString& name) const;   // case-insensitive
    Environment current() const;
    QString currentId() const { return m_currentId; }

    void setCurrent(const QString& id);
    // Adds or replaces (by id). A new environment without id gets one.
    Environment upsert(Environment env);
    // Removes an environment; the last one cannot be removed.
    bool remove(const QString& id);
    // Replaces everything (migration).
    void replaceAll(const QList<Environment>& list, const QString& currentId);

    static QList<Environment> defaults();

private:
    void save();

    KeyValueStore& m_store;
    QList<Environment> m_list;
    QString m_currentId;
};

} // namespace lv
