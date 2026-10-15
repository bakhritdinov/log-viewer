#include "core/storage/KeyValueStore.h"

#include <QSettings>

namespace lv {

QSettingsStore::QSettingsStore() : m_settings(new QSettings), m_owned(true) {}

QSettingsStore::QSettingsStore(QSettings* settings) : m_settings(settings), m_owned(false) {}

QSettingsStore::~QSettingsStore()
{
    if (m_owned) delete m_settings;
}

QVariant QSettingsStore::value(const QString& key, const QVariant& fallback) const
{
    return m_settings->value(key, fallback);
}

void QSettingsStore::setValue(const QString& key, const QVariant& value)
{
    m_settings->setValue(key, value);
}

void QSettingsStore::remove(const QString& key)
{
    m_settings->remove(key);
}

bool QSettingsStore::contains(const QString& key) const
{
    return m_settings->contains(key);
}

QStringList QSettingsStore::allKeys() const
{
    return m_settings->allKeys();
}

} // namespace lv
