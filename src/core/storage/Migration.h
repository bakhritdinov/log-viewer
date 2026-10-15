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

// What it takes to move settings written by LogViewer 2.x (per-environment
// `DEV/url`, `DEV/pass`, … keys) to the current layout. Computed without side
// effects; the caller writes secrets first and drops the legacy keys only once
// the secrets are stored.
struct LegacyMigration {
    bool needed = false;
    QList<Environment> environments;
    QString currentId;
    QHash<QString, QString> secrets;                 // SecretStore key → value
    QList<QPair<QString, QVariant>> settings;        // new key → value
    QStringList keysToRemove;                        // legacy keys incl. plaintext secrets and Ecotone
};

LegacyMigration planLegacyMigration(const KeyValueStore& store);

} // namespace lv
