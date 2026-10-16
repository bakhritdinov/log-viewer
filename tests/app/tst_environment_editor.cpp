#include <QSignalSpy>
#include <QTest>
#include <QTimer>

#include "app/AppServices.h"
#include "app/EnvironmentEditor.h"
#include "app/Session.h"
#include "support/FakeHttp.h"

using namespace lv;
using namespace lvtest;

namespace {
struct Harness {
    FakeHttpClient http;
    MemoryStore kv;
    MemorySecretStore secrets;
    AppServices services{ http, kv, secrets, makeInlineParseExecutor() };
    Session session{ services };
    EnvironmentEditor editor{ session };
};
// Like the OS keychain: a write finishes later, a read may be answered first.
class SlowWriteSecretStore : public MemorySecretStore {
public:
    void write(const QString& key, const QString& value, DoneCallback done) override
    {
        QTimer::singleShot(20, [this, key, value, done] { MemorySecretStore::write(key, value, done); });
    }
};
// A keychain that refuses writes (locked, access denied).
class RefusingSecretStore : public MemorySecretStore {
public:
    void write(const QString&, const QString&, DoneCallback done) override { done(false); }
};
} // namespace

class TestEnvironmentEditor : public QObject {
    Q_OBJECT

private slots:
    void newEnvironmentGetsFreeColour()
    {
        Harness h;
        QVERIFY(h.editor.isNew());
        QCOMPARE(h.editor.property("color").toString(), environmentColors().at(1));   // DEV green and PROD red are taken
        QVERIFY(!h.editor.canRemove());
    }

    void dirtyTracksEdits()
    {
        Harness h;
        QVERIFY(!h.editor.isDirty());                             // a blank new form
        h.editor.setProperty("name", "STAGE");
        QVERIFY(h.editor.isDirty());
        h.editor.setProperty("name", "");
        QVERIFY(!h.editor.isDirty());                             // back to what it was

        const QString devId = h.services.environments().environments().first().id;
        h.secrets.write(h.services.environments().environments().first().passwordKey(), "pw", [](bool) {});
        h.editor.load(devId);
        QTRY_COMPARE(h.editor.property("password").toString(), "pw");
        QVERIFY(!h.editor.isDirty());                             // a loaded secret is not an edit
        h.editor.setProperty("url", "https://other");
        QVERIFY(h.editor.isDirty());
        h.editor.load(devId);
        QVERIFY(!h.editor.isDirty());
    }

    void validation()
    {
        Harness h;
        QVERIFY(!h.editor.validationError().isEmpty());          // no name
        h.editor.setProperty("name", "prod");
        QVERIFY(h.editor.validationError().contains("PROD") || h.editor.validationError().contains("prod"));
        h.editor.setProperty("name", "STAGE");
        QVERIFY(h.editor.validationError().isEmpty());
        h.editor.setProperty("url", "grafana.local");             // no scheme
        QVERIFY(!h.editor.validationError().isEmpty());
        QVERIFY(!h.editor.save());
        h.editor.setProperty("url", "https://grafana.stage");
        QVERIFY(h.editor.validationError().isEmpty());
    }

    void saveStoresSecretAndSwitches()
    {
        Harness h;
        h.editor.setProperty("name", "STAGE");
        h.editor.setProperty("url", "https://grafana.stage");
        h.editor.setProperty("datasourceUid", "uid");
        h.editor.setProperty("user", "alice");
        h.editor.setProperty("password", "pw");
        h.editor.setProperty("token", "ignored");
        QSignalSpy saved(&h.editor, &EnvironmentEditor::saved);
        QSignalSpy envChanged(&h.session, &Session::environmentChanged);
        h.http.script(std::nullopt);   // the session starts discovering the new env
        QVERIFY(h.editor.save());
        QCOMPARE(saved.count(), 1);
        const QString id = saved.first().first().toString();
        const auto env = h.services.environments().find(id);
        QVERIFY(env.has_value());
        QCOMPARE(env->name, "STAGE");
        QCOMPARE(h.secrets.values().value(env->passwordKey()), "pw");
        QVERIFY(!h.secrets.values().contains(env->tokenKey()));   // only the chosen auth's secret
        QCOMPARE(h.session.environmentName(), "STAGE");
        QVERIFY(envChanged.count() >= 1);
        QCOMPARE(h.http.requests.size(), 1);                      // rediscovery started
        QVERIFY(!h.editor.isNew());
    }

    // Feedback: after re-entering the password nothing loaded — the session read
    // the keychain before the new password was written.
    void sessionUsesThePasswordJustSaved()
    {
        FakeHttpClient http;
        MemoryStore kv;
        SlowWriteSecretStore secrets;
        AppServices services{ http, kv, secrets, makeInlineParseExecutor() };
        Session session{ services };
        EnvironmentEditor editor{ session };
        editor.load("dev");
        editor.setProperty("url", "https://grafana.dev");
        editor.setProperty("datasourceUid", "uid");
        editor.setProperty("user", "alice");
        editor.setProperty("password", "pw");
        http.script(std::nullopt);
        QVERIFY(editor.save());
        QTRY_COMPARE(http.requests.size(), 1);
        QCOMPARE(header(http.requests.first(), "Authorization"), "Basic " + QByteArray("alice:pw").toBase64());
    }

    void refusedSecretIsReported()
    {
        FakeHttpClient http;
        MemoryStore kv;
        RefusingSecretStore secrets;
        AppServices services{ http, kv, secrets, makeInlineParseExecutor() };
        Session session{ services };
        EnvironmentEditor editor{ session };
        QSignalSpy refused(&session, &Session::secretsNotSaved);
        editor.load("dev");
        editor.setProperty("url", "https://grafana.dev");
        editor.setProperty("datasourceUid", "uid");
        editor.setProperty("user", "alice");
        editor.setProperty("password", "pw");
        QVERIFY(editor.save());
        QCOMPARE(refused.size(), 1);
        QCOMPARE(refused.first().first().toString(), editor.property("name").toString());
    }

    void loadReadsSecretsAndRemoves()
    {
        Harness h;
        Environment dev = *h.services.environments().find("dev");
        dev.url = QUrl("https://dev");
        dev.datasourceUid = "u";
        dev.auth = Environment::Auth::Token;
        h.services.environments().upsert(dev);
        h.secrets.write(dev.tokenKey(), "tok", [](bool) {});
        h.editor.load("dev");
        QCOMPARE(h.editor.property("token").toString(), "tok");
        QCOMPARE(h.editor.property("auth").value<EnvironmentEditor::Auth>(), EnvironmentEditor::Auth::Token);
        QVERIFY(h.editor.canRemove());
        h.http.script(std::nullopt);
        QVERIFY(h.editor.remove());
        QVERIFY(!h.services.environments().find("dev"));
        QVERIFY(!h.secrets.values().contains(dev.tokenKey()));
        QVERIFY(h.editor.isNew());
        h.editor.load("prod");
        QVERIFY(!h.editor.canRemove());   // the last one stays
    }

    void testConnectionReportsResult()
    {
        Harness h;
        h.editor.setProperty("name", "STAGE");
        h.editor.setProperty("url", "https://grafana.stage");
        h.editor.setProperty("datasourceUid", "uid");
        h.http.script(ok(fixture("grafana/discovery_phase1.json")));
        h.http.script(ok(fixture("grafana/discovery_phase2.json")));
        h.editor.testConnection();
        QCOMPARE(h.editor.testState(), EnvironmentEditor::TestState::Testing);
        QTRY_COMPARE_WITH_TIMEOUT(h.editor.testState(), EnvironmentEditor::TestState::Passed, 2000);
        QVERIFY(h.editor.testMessage().contains("_namespace / _appName"));
        QVERIFY(h.editor.testMessage().contains("3"));   // namespaces found
        QCOMPARE(h.http.requests.first().url, QUrl("https://grafana.stage/api/ds/query"));

        h.http.script(status(401));
        h.editor.testConnection();
        QTRY_COMPARE_WITH_TIMEOUT(h.editor.testState(), EnvironmentEditor::TestState::Failed, 2000);
        QCOMPARE(h.editor.testError().kind, ErrorInfo::Kind::Unauthorized);
        QVERIFY(h.services.environments().findByName("STAGE") == std::nullopt);   // testing does not save
    }

    void testConnectionReportsSteps()
    {
        Harness h;
        h.editor.setProperty("name", "STAGE");
        h.editor.setProperty("url", "https://grafana.stage");
        h.editor.setProperty("datasourceUid", "uid");
        h.http.script(ok(fixture("grafana/discovery_phase1.json")));
        h.http.script(std::nullopt);                          // listing the namespaces hangs
        h.editor.testConnection();
        QCOMPARE(h.editor.testStep(), 0);
        QTRY_COMPARE_WITH_TIMEOUT(h.editor.testStep(), 1, 2000);   // server, login and datasource are fine
        QCOMPARE(h.editor.testState(), EnvironmentEditor::TestState::Testing);
        QVERIFY(h.editor.testServerMs() >= 0);

        h.editor.cancelTest();
        QCOMPARE(h.editor.testState(), EnvironmentEditor::TestState::Idle);
    }
};

QTEST_GUILESS_MAIN(TestEnvironmentEditor)
#include "tst_environment_editor.moc"
