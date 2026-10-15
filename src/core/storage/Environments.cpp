#include "core/storage/Environments.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>

namespace lv {

namespace {

const QString kListKey = QStringLiteral("environments/list");
const QString kCurrentKey = QStringLiteral("environments/current");

QString authName(Environment::Auth a)
{
    switch (a) {
        case Environment::Auth::None: return QStringLiteral("none");
        case Environment::Auth::Token: return QStringLiteral("token");
        case Environment::Auth::Basic: break;
    }
    return QStringLiteral("basic");
}

Environment::Auth authFromName(const QString& s)
{
    if (s == u"none") return Environment::Auth::None;
    if (s == u"token") return Environment::Auth::Token;
    return Environment::Auth::Basic;
}

QJsonObject toJson(const Environment& e)
{
    QJsonObject o{ { "id", e.id }, { "name", e.name }, { "color", e.color }, { "url", e.url.toString() },
                   { "uid", e.datasourceUid }, { "user", e.user }, { "auth", authName(e.auth) } };
    if (!e.nsLabel.isEmpty()) o.insert("nsLabel", e.nsLabel);
    if (!e.appLabel.isEmpty()) o.insert("appLabel", e.appLabel);
    return o;
}

Environment fromJson(const QJsonObject& o)
{
    Environment e;
    e.id = o.value("id").toString();
    e.name = o.value("name").toString();
    e.color = o.value("color").toString();
    e.url = QUrl(o.value("url").toString());
    e.datasourceUid = o.value("uid").toString();
    e.user = o.value("user").toString();
    e.auth = authFromName(o.value("auth").toString());
    e.nsLabel = o.value("nsLabel").toString();
    e.appLabel = o.value("appLabel").toString();
    return e;
}

QString newId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

} // namespace

Connection Environment::connection(const QString& password, const QString& token) const
{
    Connection c;
    c.baseUrl = url;
    c.datasourceUid = datasourceUid;
    if (auth == Auth::Basic) {
        c.user = user;
        c.password = password;
    } else if (auth == Auth::Token) {
        c.token = token;
    }
    return c;
}

const QStringList& environmentColors()
{
    static const QStringList colors = { "#3fb950", "#d29922", "#f85149", "#388bfd", "#6e7681" };
    return colors;
}

QList<Environment> EnvironmentsStore::defaults()
{
    Environment dev;
    dev.id = QStringLiteral("dev");
    dev.name = QStringLiteral("DEV");
    dev.color = environmentColors().at(0);
    Environment prod;
    prod.id = QStringLiteral("prod");
    prod.name = QStringLiteral("PROD");
    prod.color = environmentColors().at(2);
    return { dev, prod };
}

EnvironmentsStore::EnvironmentsStore(KeyValueStore& store) : m_store(store)
{
    const QJsonArray arr = QJsonDocument::fromJson(m_store.value(kListKey).toByteArray()).array();
    for (const QJsonValue& v : arr) {
        const Environment e = fromJson(v.toObject());
        if (!e.id.isEmpty()) m_list.append(e);
    }
    if (m_list.isEmpty()) m_list = defaults();
    m_currentId = m_store.value(kCurrentKey).toString();
    if (!find(m_currentId)) m_currentId = m_list.first().id;
}

std::optional<Environment> EnvironmentsStore::find(const QString& id) const
{
    for (const Environment& e : m_list)
        if (e.id == id) return e;
    return std::nullopt;
}

std::optional<Environment> EnvironmentsStore::findByName(const QString& name) const
{
    for (const Environment& e : m_list)
        if (e.name.compare(name, Qt::CaseInsensitive) == 0) return e;
    return std::nullopt;
}

Environment EnvironmentsStore::current() const
{
    return find(m_currentId).value_or(m_list.first());
}

void EnvironmentsStore::setCurrent(const QString& id)
{
    if (!find(id)) return;
    m_currentId = id;
    save();
}

Environment EnvironmentsStore::upsert(Environment env)
{
    if (env.id.isEmpty()) env.id = newId();
    for (Environment& e : m_list) {
        if (e.id == env.id) {
            e = env;
            save();
            return env;
        }
    }
    m_list.append(env);
    save();
    return env;
}

bool EnvironmentsStore::remove(const QString& id)
{
    if (m_list.size() <= 1) return false;
    const qsizetype before = m_list.size();
    m_list.removeIf([&](const Environment& e) { return e.id == id; });
    if (m_list.size() == before) return false;
    if (m_currentId == id) m_currentId = m_list.first().id;
    save();
    return true;
}

void EnvironmentsStore::replaceAll(const QList<Environment>& list, const QString& currentId)
{
    m_list = list.isEmpty() ? defaults() : list;
    m_currentId = find(currentId) ? currentId : m_list.first().id;
    save();
}

void EnvironmentsStore::save()
{
    QJsonArray arr;
    for (const Environment& e : m_list) arr.append(toJson(e));
    m_store.setValue(kListKey, QJsonDocument(arr).toJson(QJsonDocument::Compact));
    m_store.setValue(kCurrentKey, m_currentId);
}

} // namespace lv
