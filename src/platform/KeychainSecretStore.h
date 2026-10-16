#pragma once

#include <QObject>

#include "core/storage/SecretStore.h"

namespace lv {

// Passwords and tokens in the system keychain (Windows Credential Manager,
// macOS Keychain, the Secret Service on Linux) through QtKeychain. Where there
// is none (a Linux desktop without a Secret Service), they go to the settings
// instead and isSecure() turns false, so the environment form says so. A
// value missing from the keychain is looked up in the settings too: it may
// have been written while the keychain was unavailable.
class KeychainSecretStore : public QObject, public SecretStore {
    Q_OBJECT
public:
    KeychainSecretStore(KeyValueStore& settings, const QString& service, QObject* parent = nullptr);

    void read(const QString& key, ReadCallback done) override;
    void write(const QString& key, const QString& value, DoneCallback done) override;
    void remove(const QString& key, DoneCallback done) override;
    bool isSecure() const override { return m_keychain; }

private:
    QString m_service;
    SettingsSecretStore m_fallback;
    bool m_keychain = true;     // false once the keychain turned out to be missing
};

} // namespace lv
