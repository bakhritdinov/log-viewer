#include <QSignalSpy>
#include <QTest>
#include <atomic>
#include <thread>

#include "LinkHandler.h"
#include "app/AppServices.h"
#include "app/Session.h"
#include "support/FakeHttp.h"

using namespace lv;
using namespace lvtest;

// logviewer:// links on the desktop: from the command line, and handed from a
// second start to the running app.
class TestLinks : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() { qputenv("LOGVIEWER_INSTANCE_NAME", "LogViewer-tests-links"); }

    void linkFromArguments()
    {
        QCOMPARE(LinkHandler::linkFromArguments({ "LogViewer" }), QString());
        QCOMPARE(LinkHandler::linkFromArguments({ "LogViewer", "--flag", "logviewer://open?v=1&env=DEV" }),
                 "logviewer://open?v=1&env=DEV");
        QCOMPARE(LinkHandler::linkFromArguments({ "LogViewer", "LOGVIEWER://open?x" }), "LOGVIEWER://open?x");
    }

    void secondStartHandsItsLinkToTheRunningApp()
    {
        FakeHttpClient http;
        MemoryStore kv;
        MemorySecretStore secrets;
        AppServices services(http, kv, secrets, makeInlineParseExecutor());
        Session session(services);

        LinkHandler running;
        QVERIFY(!running.handedToRunningApp({}));              // nobody listens yet
        running.listen(session, nullptr);

        QSignalSpy missing(&session, &Session::linkEnvironmentMissing);
        // The second start is another process; here a thread, so the running
        // app's event loop can answer while it waits.
        std::atomic<bool> handed = false;
        std::thread second([&] {
            LinkHandler other;
            handed = other.handedToRunningApp("logviewer://open?v=1&env=QA&ns=a&app=b&range=1h");
        });
        QTRY_COMPARE(missing.count(), 1);                      // the running app opened it
        second.join();
        QVERIFY(handed);
        QCOMPARE(missing.first().first().toString(), "QA");
    }
};

QTEST_GUILESS_MAIN(TestLinks)
#include "tst_links.moc"
