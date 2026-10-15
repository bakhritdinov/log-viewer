#include <QTest>
#include <QThread>

#include "core/data/ParseExecutor.h"
#include "support/FakeHttp.h"

using namespace lv;
using namespace lvtest;

class TestParseExecutor : public QObject {
    Q_OBJECT

private slots:
    void threadedDeliversOnContextThread()
    {
        auto exec = makeThreadedParseExecutor();
        QObject context;
        bool called = false;
        QThread* deliveredOn = nullptr;
        exec->parseLogs(fixture("grafana/logs_basic.json"), &context, [&](ParsedLogs p) {
            called = true;
            deliveredOn = QThread::currentThread();
            QCOMPARE(p.entries.size(), 3);
        });
        QTRY_VERIFY_WITH_TIMEOUT(called, 2000);
        QCOMPARE(deliveredOn, QThread::currentThread());
    }

    void destroyedContextDropsResult()
    {
        auto exec = makeThreadedParseExecutor();
        bool called = false;
        {
            QObject context;
            exec->parseLogs(fixture("grafana/logs_basic.json"), &context, [&](ParsedLogs) { called = true; });
        }
        QTest::qWait(100);
        QVERIFY(!called);
    }

    void inlineRunsOnNextTick()
    {
        auto exec = makeInlineParseExecutor();
        QObject context;
        bool called = false;
        exec->parseLogs(fixture("grafana/logs_basic.json"), &context, [&](ParsedLogs p) {
            called = true;
            QCOMPARE(p.entries.size(), 3);
        });
        QVERIFY(!called);   // not synchronous
        QTRY_VERIFY_WITH_TIMEOUT(called, 1000);
    }

    void defaultExecutorWorks()
    {
        auto exec = makeDefaultParseExecutor();
        QObject context;
        int n = -1;
        exec->parseLogs(fixture("grafana/logs_two_frames.json"), &context, [&](ParsedLogs p) { n = int(p.entries.size()); });
        QTRY_COMPARE_WITH_TIMEOUT(n, 2, 2000);
    }
};

QTEST_GUILESS_MAIN(TestParseExecutor)
#include "tst_parse_executor.moc"
