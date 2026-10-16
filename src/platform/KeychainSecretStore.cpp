#include "KeychainSecretStore.h"

#include <qtkeychain/keychain.h>

namespace lv {

namespace {

// No keychain at all here (as opposed to "this entry does not exist").
bool keychainMissing(QKeychain::Error error)
{
    return error == QKeychain::NoBackendAvailable || error == QKeychain::NotImplemented
        || error == QKeychain::OtherError;
}

} // namespace

KeychainSecretStore::KeychainSecretStore(KeyValueStore& settings, const QString& service, QObject* parent)
    : QObject(parent), m_service(service), m_fallback(settings)
{
}

void KeychainSecretStore::read(const QString& key, ReadCallback done)
{
    if (!m_keychain) {
        m_fallback.read(key, std::move(done));
        return;
    }
    auto* job = new QKeychain::ReadPasswordJob(m_service, this);
    job->setKey(key);
    connect(job, &QKeychain::Job::finished, this, [this, job, key, done = std::move(done)] {
        if (job->error() == QKeychain::NoError) {
            done(true, job->textData());
            return;
        }
        if (keychainMissing(job->error())) m_keychain = false;
        // Not in the keychain: perhaps written while it was unavailable.
        m_fallback.read(key, done);
    });
    job->start();
}

void KeychainSecretStore::write(const QString& key, const QString& value, DoneCallback done)
{
    if (!m_keychain) {
        m_fallback.write(key, value, std::move(done));
        return;
    }
    auto* job = new QKeychain::WritePasswordJob(m_service, this);
    job->setKey(key);
    job->setTextData(value);
    connect(job, &QKeychain::Job::finished, this, [this, job, key, value, done = std::move(done)] {
        if (job->error() == QKeychain::NoError) {
            // A copy left in the settings from a time without the keychain goes.
            m_fallback.remove(key, [](bool) {});
            done(true);
            return;
        }
        if (keychainMissing(job->error())) {
            m_keychain = false;
            m_fallback.write(key, value, done);
            return;
        }
        done(false);
    });
    job->start();
}

void KeychainSecretStore::remove(const QString& key, DoneCallback done)
{
    m_fallback.remove(key, [](bool) {});
    if (!m_keychain) {
        done(true);
        return;
    }
    auto* job = new QKeychain::DeletePasswordJob(m_service, this);
    job->setKey(key);
    connect(job, &QKeychain::Job::finished, this, [job, done = std::move(done)] {
        done(job->error() == QKeychain::NoError || job->error() == QKeychain::EntryNotFound
             || keychainMissing(job->error()));
    });
    job->start();
}

} // namespace lv
