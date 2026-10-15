#pragma once

#include <memory>

#include "core/data/ErrorClassifier.h"
#include "core/data/Http.h"
#include "core/data/ParseExecutor.h"
#include "core/features/ChainedLoader.h"
#include "core/storage/Environments.h"
#include "core/storage/KeyValueStore.h"
#include "core/storage/SecretStore.h"
#include "core/storage/UserData.h"

namespace lv {

// Everything the view-models need from the outside world. The platform layer
// builds the real thing (QNetworkAccessManager, QSettings, OS keychain); tests
// build one from fakes. Owns the stores; does not own http/secrets/settings.
class AppServices {
public:
    AppServices(HttpClient& http, KeyValueStore& settings, SecretStore& secrets,
                std::unique_ptr<ParseExecutor> parser, ClassifyOptions classify = {},
                Clock clock = systemClock());

    HttpClient& http() const { return m_http; }
    KeyValueStore& settings() const { return m_settings; }
    SecretStore& secrets() const { return m_secrets; }
    ParseExecutor& parser() const { return *m_parser; }
    ClassifyOptions classifyOptions() const { return m_classify; }
    const Clock& clock() const { return m_clock; }

    EnvironmentsStore& environments() { return *m_environments; }
    SavedQueriesStore& savedQueries() { return *m_savedQueries; }
    SearchHistory& history() { return *m_history; }
    SelectionMemory& selection() { return *m_selection; }

    // Reloads the stores from settings (after a migration rewrote them).
    void reloadStores();

private:
    HttpClient& m_http;
    KeyValueStore& m_settings;
    SecretStore& m_secrets;
    std::unique_ptr<ParseExecutor> m_parser;
    ClassifyOptions m_classify;
    Clock m_clock;
    std::unique_ptr<EnvironmentsStore> m_environments;
    std::unique_ptr<SavedQueriesStore> m_savedQueries;
    std::unique_ptr<SearchHistory> m_history;
    std::unique_ptr<SelectionMemory> m_selection;
};

// Applies planLegacyMigration(): secrets first, and only when all of them are
// stored are the new settings written and the legacy keys (with plaintext
// passwords) removed. `done(true)` also when there was nothing to migrate.
void runLegacyMigration(AppServices& services, std::function<void(bool ok)> done);

} // namespace lv
