#pragma once

#include <QHash>
#include <QString>
#include <functional>

#include "core/storage/KeyValueStore.h"

namespace lv {

// Passwords and tokens. Asynchronous like the OS keychains it fronts; callbacks
// may run synchronously in simple implementations.
class SecretStore {
public:
    using ReadCallback = std::function<void(bool ok, const QString& value)>;
    using DoneCallback = std::function<void(bool ok)>;

    virtual ~SecretStore() = default;
    virtual void read(const QString& key, ReadCallback done) = 0;
    virtual void write(const QString& key, const QString& value, DoneCallback done) = 0;
    virtual void remove(const QString& key, DoneCallback done) = 0;
    // False where secrets end up in plain settings (browser builds): the UI
    // warns the user.
    virtual bool isSecure() const = 0;
};

// Tests.
class MemorySecretStore : public SecretStore {
public:
    void read(const QString& key, ReadCallback done) override { done(true, m_values.value(key)); }
    void write(const QString& key, const QString& value, DoneCallback done) override
    {
        m_values.insert(key, value);
        done(true);
    }
    void remove(const QString& key, DoneCallback done) override
    {
        m_values.remove(key);
        done(true);
    }
    bool isSecure() const override { return true; }
    const QHash<QString, QString>& values() const { return m_values; }

private:
    QHash<QString, QString> m_values;
};

// Fallback without an OS keychain (WebAssembly): secrets kept in settings
// under "secrets/<key>".
class SettingsSecretStore : public SecretStore {
public:
    explicit SettingsSecretStore(KeyValueStore& store) : m_store(store) {}
    void read(const QString& key, ReadCallback done) override;
    void write(const QString& key, const QString& value, DoneCallback done) override;
    void remove(const QString& key, DoneCallback done) override;
    bool isSecure() const override { return false; }

private:
    KeyValueStore& m_store;
};

} // namespace lv
