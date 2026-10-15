#pragma once

#include <QHash>
#include <QString>
#include <QStringList>
#include <QVariant>

class QSettings;

namespace lv {

// Persistent settings seam (QSettings in the app, a map in tests).
class KeyValueStore {
public:
    virtual ~KeyValueStore() = default;
    virtual QVariant value(const QString& key, const QVariant& fallback = {}) const = 0;
    virtual void setValue(const QString& key, const QVariant& value) = 0;
    virtual void remove(const QString& key) = 0;
    virtual bool contains(const QString& key) const = 0;
    virtual QStringList allKeys() const = 0;
};

class QSettingsStore : public KeyValueStore {
public:
    // Uses the application's default QSettings (organization/application names).
    QSettingsStore();
    explicit QSettingsStore(QSettings* settings);   // not owned
    ~QSettingsStore() override;

    QVariant value(const QString& key, const QVariant& fallback = {}) const override;
    void setValue(const QString& key, const QVariant& value) override;
    void remove(const QString& key) override;
    bool contains(const QString& key) const override;
    QStringList allKeys() const override;

private:
    QSettings* m_settings;
    bool m_owned;
};

class MemoryStore : public KeyValueStore {
public:
    QVariant value(const QString& key, const QVariant& fallback = {}) const override
    {
        return m_values.value(key, fallback);
    }
    void setValue(const QString& key, const QVariant& value) override { m_values.insert(key, value); }
    void remove(const QString& key) override { m_values.remove(key); }
    bool contains(const QString& key) const override { return m_values.contains(key); }
    QStringList allKeys() const override { return m_values.keys(); }

private:
    QHash<QString, QVariant> m_values;
};

} // namespace lv
