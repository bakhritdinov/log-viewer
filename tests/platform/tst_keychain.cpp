#include <QSignalSpy>
#include <QTest>

#include "KeychainSecretStore.h"

using namespace lv;

// The system keychain itself: it writes to the user's real keychain (service
// "LogViewer-tests", removed at the end), so it runs only when asked for with
// LOGVIEWER_TEST_KEYCHAIN=1 (a CI runner may have no keychain, or one that
// asks the user).
class TestKeychain : public QObject {
    Q_OBJECT

    template <typename Op>
    static void wait(Op op)
    {
        bool finished = false;
        op([&] { finished = true; });
        QTRY_VERIFY_WITH_TIMEOUT(finished, 10000);
    }

private slots:
    void init()
    {
        if (qEnvironmentVariableIntValue("LOGVIEWER_TEST_KEYCHAIN") != 1)
            QSKIP("set LOGVIEWER_TEST_KEYCHAIN=1 to use the real system keychain");
    }

    void roundTrip()
    {
        MemoryStore settings;
        KeychainSecretStore store(settings, QStringLiteral("LogViewer-tests"));
        bool ok = false;
        wait([&](auto done) { store.write("env/test/password", "s3cret", [&, done](bool r) { ok = r; done(); }); });
        QVERIFY(ok);
        QVERIFY(store.isSecure());
        QVERIFY(settings.allKeys().isEmpty());                 // not in the settings

        QString value;
        wait([&](auto done) { store.read("env/test/password", [&, done](bool r, const QString& v) { ok = r; value = v; done(); }); });
        QVERIFY(ok);
        QCOMPARE(value, "s3cret");

        wait([&](auto done) { store.remove("env/test/password", [&, done](bool r) { ok = r; done(); }); });
        QVERIFY(ok);
        wait([&](auto done) { store.read("env/test/password", [&, done](bool, const QString& v) { value = v; done(); }); });
        QVERIFY(value.isEmpty());
    }

    void valueLeftInTheSettingsIsFound()
    {
        // Written while the keychain was unavailable: still read, and moved on write.
        MemoryStore settings;
        settings.setValue("secrets/env/old/password", "kept");
        KeychainSecretStore store(settings, QStringLiteral("LogViewer-tests"));
        QString value;
        wait([&](auto done) { store.read("env/old/password", [&, done](bool, const QString& v) { value = v; done(); }); });
        QCOMPARE(value, "kept");
        wait([&](auto done) { store.write("env/old/password", "kept", [done](bool) { done(); }); });
        QVERIFY(!settings.contains("secrets/env/old/password"));
        wait([&](auto done) { store.remove("env/old/password", [done](bool) { done(); }); });
    }
};

QTEST_GUILESS_MAIN(TestKeychain)
#include "tst_keychain.moc"
