#include "core/storage/SecretStore.h"

namespace lv {

namespace {
QString settingsKey(const QString& key) { return QStringLiteral("secrets/") + key; }
} // namespace

void SettingsSecretStore::read(const QString& key, ReadCallback done)
{
    done(true, m_store.value(settingsKey(key)).toString());
}

void SettingsSecretStore::write(const QString& key, const QString& value, DoneCallback done)
{
    m_store.setValue(settingsKey(key), value);
    done(true);
}

void SettingsSecretStore::remove(const QString& key, DoneCallback done)
{
    m_store.remove(settingsKey(key));
    done(true);
}

} // namespace lv
