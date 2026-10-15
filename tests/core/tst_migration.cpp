#include <QTest>

#include "core/storage/Migration.h"
#include "core/storage/UserData.h"

using namespace lv;

namespace {

// Settings as LogViewer 2.x left them (ConfigManager + EcotoneConfigManager).
MemoryStore legacyStore()
{
    MemoryStore kv;
    kv.setValue("currentEnv", "PROD");
    kv.setValue("theme/dark", true);
    kv.setValue("DEV/url", "https://dev-grafana");
    kv.setValue("DEV/uid", "dev-uid");
    kv.setValue("DEV/user", "alice");
    kv.setValue("DEV/pass", "dev-pass");
    kv.setValue("DEV/token", "");
    kv.setValue("PROD/url", "https://prod-grafana");
    kv.setValue("PROD/uid", "prod-uid");
    kv.setValue("PROD/user", "");
    kv.setValue("PROD/pass", "");
    kv.setValue("PROD/token", "prod-token");
    kv.setValue("PROD/lastNamespace", "prod-core");
    kv.setValue("PROD/lastApp", "billing-api");
    kv.setValue("lastTimeRange", "6h");
    kv.setValue("lastCustomFrom", "");
    kv.setValue("lastCustomTo", "");
    kv.setValue("searchHistory", QStringList{ "timeout" });
    kv.setValue("histogram/height", 140);
    kv.setValue("PROD/ecotone/host", "db");
    kv.setValue("PROD/ecotone/password", "db-pass");
    kv.setValue("ecotone/filters/autoRefresh", true);
    return kv;
}

QVariant settingValue(const LegacyMigration& m, const QString& key)
{
    for (const auto& [k, v] : m.settings)
        if (k == key) return v;
    return {};
}

} // namespace

class TestMigration : public QObject {
    Q_OBJECT

private slots:
    void migratesEnvironments()
    {
        const LegacyMigration m = planLegacyMigration(legacyStore());
        QVERIFY(m.needed);
        QCOMPARE(m.environments.size(), 2);
        const Environment& dev = m.environments.at(0);
        QCOMPARE(dev.id, "dev");
        QCOMPARE(dev.name, "DEV");
        QCOMPARE(dev.url, QUrl("https://dev-grafana"));
        QCOMPARE(dev.datasourceUid, "dev-uid");
        QCOMPARE(dev.auth, Environment::Auth::Basic);
        QCOMPARE(dev.color, environmentColors().at(0));
        const Environment& prod = m.environments.at(1);
        QCOMPARE(prod.auth, Environment::Auth::Token);
        QCOMPARE(prod.color, environmentColors().at(2));
        QCOMPARE(m.currentId, "prod");
    }

    void movesSecretsOutOfSettings()
    {
        const LegacyMigration m = planLegacyMigration(legacyStore());
        QCOMPARE(m.secrets.size(), 2);
        QCOMPARE(m.secrets.value("env/dev/password"), "dev-pass");
        QCOMPARE(m.secrets.value("env/prod/token"), "prod-token");
        QVERIFY(m.keysToRemove.contains("DEV/pass"));
        QVERIFY(m.keysToRemove.contains("PROD/token"));
    }

    void carriesSelectionAndRange()
    {
        const LegacyMigration m = planLegacyMigration(legacyStore());
        QCOMPARE(settingValue(m, "selection/prod/namespace").toString(), "prod-core");
        QCOMPARE(settingValue(m, "selection/prod/app").toString(), "billing-api");
        QCOMPARE(settingValue(m, "selection/timeRange").toString(), "6h");
        QVERIFY(!settingValue(m, "selection/dev/app").isValid());
    }

    void customRangeBecomesAbsolute()
    {
        MemoryStore kv = legacyStore();
        kv.setValue("lastTimeRange", "Custom");
        kv.setValue("lastCustomFrom", "2026-10-15T09:00:00Z");
        kv.setValue("lastCustomTo", "2026-10-15T12:00:00Z");
        const LegacyMigration m = planLegacyMigration(kv);
        const TimeRange r = decodeTimeRange(settingValue(m, "selection/timeRange").toString());
        QCOMPARE(r.kind(), TimeRange::Kind::Absolute);
        QCOMPARE(r.resolve(QDateTime::currentDateTimeUtc()).seconds(), qint64(10800));
    }

    void dropsEcotoneAndLegacyKeysButKeepsCompatibleOnes()
    {
        const LegacyMigration m = planLegacyMigration(legacyStore());
        for (const char* k : { "PROD/ecotone/host", "PROD/ecotone/password", "ecotone/filters/autoRefresh",
                               "currentEnv", "lastTimeRange", "DEV/url", "PROD/lastApp" })
            QVERIFY2(m.keysToRemove.contains(QLatin1StringView(k)), k);
        for (const char* k : { "theme/dark", "searchHistory", "histogram/height" })
            QVERIFY2(!m.keysToRemove.contains(QLatin1StringView(k)), k);
    }

    void onlyDevConfiguredStillOffersProd()
    {
        MemoryStore kv;
        kv.setValue("DEV/url", "https://d");
        const LegacyMigration m = planLegacyMigration(kv);
        QCOMPARE(m.environments.size(), 2);
        QCOMPARE(m.environments.at(1).id, "prod");
        QCOMPARE(m.environments.at(0).auth, Environment::Auth::None);
    }

    void customEnvironmentName()
    {
        MemoryStore kv;
        kv.setValue("currentEnv", "QA");
        kv.setValue("QA/url", "https://qa");
        const LegacyMigration m = planLegacyMigration(kv);
        QCOMPARE(m.currentId, "qa");
        QVERIFY(std::any_of(m.environments.cbegin(), m.environments.cend(),
                            [](const Environment& e) { return e.name == "QA"; }));
    }

    void nothingToDo()
    {
        QVERIFY(!planLegacyMigration(MemoryStore()).needed);
        MemoryStore migrated = legacyStore();
        migrated.setValue(kSchemaKey, kSettingsSchemaVersion);
        QVERIFY(!planLegacyMigration(migrated).needed);
    }
};

QTEST_GUILESS_MAIN(TestMigration)
#include "tst_migration.moc"
