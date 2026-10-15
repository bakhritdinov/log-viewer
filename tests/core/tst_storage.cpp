#include <QSettings>
#include <QTemporaryDir>
#include <QTest>

#include "core/storage/Environments.h"
#include "core/storage/SecretStore.h"
#include "core/storage/UserData.h"

using namespace lv;

class TestStorage : public QObject {
    Q_OBJECT

private slots:
    void environmentsDefaultToDevAndProd()
    {
        MemoryStore kv;
        EnvironmentsStore envs(kv);
        QCOMPARE(envs.environments().size(), 2);
        QCOMPARE(envs.environments().at(0).name, "DEV");
        QCOMPARE(envs.environments().at(1).name, "PROD");
        QCOMPARE(envs.current().id, "dev");
        QVERIFY(!envs.current().isConfigured());
    }

    void environmentsPersist()
    {
        MemoryStore kv;
        {
            EnvironmentsStore envs(kv);
            Environment stage;
            stage.name = "STAGE";
            stage.color = environmentColors().at(1);
            stage.url = QUrl("https://grafana.stage");
            stage.datasourceUid = "uid";
            stage.auth = Environment::Auth::Token;
            stage = envs.upsert(stage);
            QVERIFY(!stage.id.isEmpty());
            envs.setCurrent(stage.id);
        }
        EnvironmentsStore reloaded(kv);
        QCOMPARE(reloaded.environments().size(), 3);
        QCOMPARE(reloaded.current().name, "STAGE");
        QCOMPARE(reloaded.current().auth, Environment::Auth::Token);
        QVERIFY(reloaded.current().isConfigured());
        QVERIFY(reloaded.findByName("stage").has_value());
    }

    void environmentsRemove()
    {
        MemoryStore kv;
        EnvironmentsStore envs(kv);
        envs.setCurrent("prod");
        QVERIFY(envs.remove("prod"));
        QCOMPARE(envs.current().id, "dev");     // current moves away from a removed env
        QVERIFY(!envs.remove("dev"));           // the last one stays
        QVERIFY(!envs.remove("nope"));
        envs.setCurrent("nope");                 // unknown ids are ignored
        QCOMPARE(envs.currentId(), "dev");
    }

    void connectionByAuthKind()
    {
        Environment e;
        e.url = QUrl("https://g");
        e.datasourceUid = "u";
        e.user = "alice";
        e.auth = Environment::Auth::Basic;
        QCOMPARE(e.connection("pw", "tok").password, "pw");
        QCOMPARE(e.connection("pw", "tok").token, QString());
        e.auth = Environment::Auth::Token;
        QCOMPARE(e.connection("pw", "tok").token, "tok");
        QCOMPARE(e.connection("pw", "tok").user, QString());
        e.auth = Environment::Auth::None;
        QVERIFY(e.connection("pw", "tok").authorizationHeader().isEmpty());
        QCOMPARE(e.passwordKey(), QStringLiteral("env/%1/password").arg(e.id));
    }

    void savedQueries()
    {
        MemoryStore kv;
        {
            SavedQueriesStore s(kv);
            SavedQuery q;
            q.name = "Таймауты оплаты";
            q.environmentId = "prod";
            q.namespaceName = "prod-core";
            q.app = "billing-api";
            q.searchText = "timeout AND level:error";
            q.range = TimeRange::fromKey(u"6h");
            const SavedQuery added = s.add(q);
            QVERIFY(!added.id.isEmpty());
            QVERIFY(added.createdAt.isValid());
            SavedQuery q2 = q;
            q2.name = "Abs";
            q2.range = *TimeRange::absolute(QDateTime::fromMSecsSinceEpoch(1000, QTimeZone::UTC),
                                            QDateTime::fromMSecsSinceEpoch(5000, QTimeZone::UTC));
            s.add(q2);
        }
        SavedQueriesStore s(kv);
        QCOMPARE(s.all().size(), 2);
        QCOMPARE(s.all().at(0).name, "Таймауты оплаты");
        QCOMPARE(s.all().at(0).range, TimeRange::fromKey(u"6h"));
        QCOMPARE(s.all().at(1).range.kind(), TimeRange::Kind::Absolute);
        QCOMPARE(s.all().at(1).range.absoluteTo().toMSecsSinceEpoch(), 5000);
        const QString id = s.all().at(1).id;
        QVERIFY(s.move(id, 0));
        QCOMPARE(s.all().at(0).name, "Abs");
        QVERIFY(s.rename(id, "Renamed"));
        QVERIFY(s.remove(id));
        QCOMPARE(SavedQueriesStore(kv).all().size(), 1);
        QVERIFY(!s.remove("missing"));
    }

    void searchHistory()
    {
        MemoryStore kv;
        SearchHistory h(kv);
        h.add("a");
        h.add("  b ");
        h.add("a");      // moves to front
        h.add("");
        h.add("*");
        QCOMPARE(h.items(), (QStringList{ "a", "b" }));
        for (int i = 0; i < 20; ++i) h.add(QString::number(i));
        QCOMPARE(h.items().size(), SearchHistory::kCapacity);
        QCOMPARE(h.items().first(), "19");
        h.clear();
        QVERIFY(h.items().isEmpty());
    }

    void selectionMemory()
    {
        MemoryStore kv;
        SelectionMemory m(kv);
        QCOMPARE(m.timeRange(), TimeRange::fromKey(u"1h"));
        m.setSelection("prod", { "prod-core", "billing-api" });
        m.setTimeRange(TimeRange::yesterday());
        QCOMPARE(m.selection("prod").app, "billing-api");
        QCOMPARE(m.selection("dev").app, QString());
        QCOMPARE(SelectionMemory(kv).timeRange(), TimeRange::yesterday());
    }

    void timeRangeCodec()
    {
        QCOMPARE(decodeTimeRange(encodeTimeRange(TimeRange::fromKey(u"15m"))), TimeRange::fromKey(u"15m"));
        QCOMPARE(decodeTimeRange("today"), TimeRange::today());
        const auto abs = *TimeRange::absolute(QDateTime::fromMSecsSinceEpoch(1, QTimeZone::UTC),
                                              QDateTime::fromMSecsSinceEpoch(2, QTimeZone::UTC));
        QCOMPARE(encodeTimeRange(abs), "abs:1:2");
        QCOMPARE(decodeTimeRange("abs:1:2"), abs);
        QCOMPARE(decodeTimeRange("abs:5:1"), TimeRange());   // reversed → default
        QCOMPARE(decodeTimeRange("garbage"), TimeRange());
    }

    void settingsSecretStoreIsInsecureFallback()
    {
        MemoryStore kv;
        SettingsSecretStore s(kv);
        QVERIFY(!s.isSecure());
        bool ok = false;
        s.write("env/x/password", "pw", [&](bool r) { ok = r; });
        QVERIFY(ok);
        QCOMPARE(kv.value("secrets/env/x/password").toString(), "pw");
        QString read;
        s.read("env/x/password", [&](bool, const QString& v) { read = v; });
        QCOMPARE(read, "pw");
        s.remove("env/x/password", [](bool) {});
        QVERIFY(!kv.contains("secrets/env/x/password"));
    }

    void qsettingsStoreRoundTrip()
    {
        QTemporaryDir dir;
        QSettings settings(dir.filePath("t.ini"), QSettings::IniFormat);
        QSettingsStore store(&settings);
        store.setValue("a/b", 5);
        QVERIFY(store.contains("a/b"));
        QCOMPARE(store.value("a/b").toInt(), 5);
        QCOMPARE(store.value("missing", "fb").toString(), "fb");
        QVERIFY(store.allKeys().contains("a/b"));
        store.remove("a/b");
        QVERIFY(!store.contains("a/b"));
    }
};

QTEST_GUILESS_MAIN(TestStorage)
#include "tst_storage.moc"
