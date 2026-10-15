#include "app/AppServices.h"

#include "core/storage/Migration.h"

namespace lv {

AppServices::AppServices(HttpClient& http, KeyValueStore& settings, SecretStore& secrets,
                         std::unique_ptr<ParseExecutor> parser, ClassifyOptions classify, Clock clock)
    : m_http(http), m_settings(settings), m_secrets(secrets), m_parser(std::move(parser)),
      m_classify(classify), m_clock(std::move(clock))
{
    reloadStores();
}

void AppServices::reloadStores()
{
    m_environments = std::make_unique<EnvironmentsStore>(m_settings);
    m_savedQueries = std::make_unique<SavedQueriesStore>(m_settings);
    m_history = std::make_unique<SearchHistory>(m_settings);
    m_selection = std::make_unique<SelectionMemory>(m_settings);
}

void runLegacyMigration(AppServices& services, std::function<void(bool ok)> done)
{
    const LegacyMigration plan = planLegacyMigration(services.settings());
    if (!plan.needed) {
        services.settings().setValue(kSchemaKey, kSettingsSchemaVersion);
        done(true);
        return;
    }

    auto finish = [&services, plan, done] {
        KeyValueStore& kv = services.settings();
        services.environments().replaceAll(plan.environments, plan.currentId);
        for (const auto& [key, value] : plan.settings) kv.setValue(key, value);
        for (const QString& key : plan.keysToRemove) kv.remove(key);
        kv.setValue(kSchemaKey, kSettingsSchemaVersion);
        services.reloadStores();
        done(true);
    };

    if (plan.secrets.isEmpty()) {
        finish();
        return;
    }
    // Write all secrets; abort (keeping the legacy keys) if any write fails.
    auto remaining = std::make_shared<int>(int(plan.secrets.size()));
    auto failed = std::make_shared<bool>(false);
    for (auto it = plan.secrets.cbegin(); it != plan.secrets.cend(); ++it) {
        services.secrets().write(it.key(), it.value(), [remaining, failed, finish, done](bool ok) {
            if (!ok) *failed = true;
            if (--*remaining > 0) return;
            if (*failed) done(false);
            else finish();
        });
    }
}

} // namespace lv
