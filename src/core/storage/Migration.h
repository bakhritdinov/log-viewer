#pragma once

#include <QHash>
#include <QList>
#include <QPair>
#include <QString>
#include <QStringList>
#include <QVariant>

#include "core/storage/Environments.h"
#include "core/storage/KeyValueStore.h"

namespace lv {

inline constexpr int kSettingsSchemaVersion = 2;
inline const QString kSchemaKey = QStringLiteral("schema/version");

// What it takes to bring settings written by LogViewer 2.x (per-environment
// `DEV/url`, `DEV/pass`, … keys) into the current layout, once. The 2.x keys
// stay where they are — nobody has to type a login again, and 2.x keeps
// working for whoever stays on it; only Ecotone's settings (a feature that is
// gone) are dropped. Computed without side effects; the caller writes the
// secrets first and changes the settings only once they are stored.
struct LegacyMigration {
    bool needed = false;
    QList<Environment> environments;
    QString currentId;
    QHash<QString, QString> secrets;                 // SecretStore key → value
    QList<QPair<QString, QVariant>> settings;        // new key → value
    QStringList keysToRemove;                        // Ecotone's settings (incl. its DB password)
};

LegacyMigration planLegacyMigration(const KeyValueStore& store);

} // namespace lv
