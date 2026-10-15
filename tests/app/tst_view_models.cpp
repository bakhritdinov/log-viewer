// Unit tests of the smaller view-model pieces: error presentation, the log
// list's two slicing modes, entry details and the trace focus.
#include <QAbstractItemModelTester>
#include <QSignalSpy>
#include <QTest>

#include "app/AppServices.h"
#include "app/EntryDetails.h"
#include "app/ErrorInfo.h"
#include "app/FocusSession.h"
#include "app/LogListModel.h"
#include "app/Session.h"
#include "support/FakeHttp.h"

using namespace lv;
using namespace lvtest;

Q_DECLARE_METATYPE(lv::RequestError::Kind)

namespace {
const QDateTime kNow = QDateTime::fromString("2026-10-15T12:00:00Z", Qt::ISODate);

LogEntry entry(int i, Level level = Level::Info, QVariantMap fields = {})
{
    return { kNow.addSecs(-i), QStringLiteral("m%1").arg(i), std::move(fields), level };
}
} // namespace

class TestViewModels : public QObject {
    Q_OBJECT

private slots:
    void everyErrorKindIsPresentable_data()
    {
        QTest::addColumn<RequestError::Kind>("kind");
        using K = RequestError::Kind;
        for (K k : { K::Unreachable, K::BlockedByBrowser, K::Tls, K::Unauthorized, K::Forbidden, K::NotFound,
                     K::TooHeavy, K::RateLimited, K::BadQuery, K::Server, K::InvalidResponse, K::NotConfigured,
                     K::UnknownLabels })
            QTest::newRow(QMetaEnum::fromType<ErrorInfo::Kind>().valueToKey(int(k))) << k;
    }
    void everyErrorKindIsPresentable()
    {
        QFETCH(RequestError::Kind, kind);
        const ErrorInfo e = ErrorInfo::from({ kind, 500, "detail" }, "PROD", "grafana.example");
        QVERIFY(e.isActive());
        QVERIFY(!e.title.isEmpty());
        QVERIFY(!e.message.isEmpty());
        QVERIFY(e.primaryAction != ErrorInfo::Action::None);
        QVERIFY(!e.primaryLabel.isEmpty());
        QCOMPARE(e.secondaryAction == ErrorInfo::Action::None, e.secondaryLabel.isEmpty());
        QCOMPARE(e.detail, "detail");
    }

    void errorWording()
    {
        QVERIFY(ErrorInfo::from({ RequestError::Kind::Unreachable, 0, {} }, {}, "grafana.example").message.contains("grafana.example"));
        QVERIFY(ErrorInfo::from({ RequestError::Kind::Unauthorized, 401, {} }, "PROD").message.contains("PROD"));
        QVERIFY(ErrorInfo::from({ RequestError::Kind::UnknownLabels, 200, "host, region" }).message.contains("host, region"));
        QVERIFY(!ErrorInfo::from({ RequestError::Kind::Cancelled, 0, {} }).isActive());
        QVERIFY(!ErrorInfo::from({ RequestError::Kind::None, 0, {} }).isActive());
        QCOMPARE(ErrorInfo::from({ RequestError::Kind::BlockedByBrowser, 0, {} }).secondaryAction, ErrorInfo::Action::CopyCorsHint);
        const QString hint = corsHintForDevOps("https://logs.example");
        QVERIFY(hint.contains("Access-Control-Allow-Origin \"https://logs.example\""));
        QVERIFY(hint.contains("return 204"));
        QVERIFY(corsHintForDevOps({}).contains("<pwa-host>"));
    }

    void pagedList()
    {
        LogStore store;
        LogEntries list;
        for (int i = 0; i < 250; ++i) list << entry(i, i % 2 ? Level::Error : Level::Info, { { "_appName", "api" } });
        store.add(list);
        LogListModel model(&store);
        QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
        model.reload(true);
        QCOMPARE(model.rowCount(), 100);
        QCOMPARE(model.pageCount(), 3);
        QCOMPARE(model.firstRowNumber(), 1);
        model.goToPage(2);
        QCOMPARE(model.page(), 2);
        QCOMPARE(model.rowCount(), 50);
        QCOMPARE(model.firstRowNumber(), 201);
        model.goToPage(9);                       // clamped
        QCOMPARE(model.page(), 2);
        QCOMPARE(model.totalCount(), 250);
        QCOMPARE(model.loadedCount(), 250);
        QVERIFY(!model.canShowMore());
        model.showMore();                        // not in paged mode
        QCOMPARE(model.rowCount(), 50);

        model.setServiceField("_appName");
        const QVariantMap row = model.rowData(0);
        QCOMPARE(row.value("service").toString(), "api");
        QVERIFY(row.value("timeText").toString().contains(':'));
        QVERIFY(row.value("dateTimeText").toString().startsWith("2026-10-15"));
        QCOMPARE(row.value("level").toString(), "INFO");   // page 2 starts at entry 200 (even → INFO)
        QVERIFY(model.rowData(999).isEmpty());
        QVERIFY(!model.entryAt(-1));
        QCOMPARE(model.roleNames().size(), 8);

        model.setPageSize(1000);
        QCOMPARE(model.rowCount(), 250);
        QCOMPARE(model.page(), 0);
    }

    void progressiveList()
    {
        LogStore store;
        LogEntries list;
        for (int i = 0; i < 230; ++i) list << entry(i);
        store.add(list);
        LogListModel model(&store);
        QAbstractItemModelTester tester(&model, QAbstractItemModelTester::FailureReportingMode::QtTest);
        model.setProgressive(true);
        QCOMPARE(model.rowCount(), 100);
        QVERIFY(model.canShowMore());
        model.showMore();
        QCOMPARE(model.rowCount(), 200);
        model.showMore();
        QCOMPARE(model.rowCount(), 230);
        QVERIFY(!model.canShowMore());
        // New entries keep the grown window instead of collapsing to 100.
        store.add({ entry(-1) });
        model.reload(false);
        QCOMPARE(model.rowCount(), 231);
        model.reload(true);
        QCOMPARE(model.rowCount(), 100);
        model.goToPage(1);                       // ignored in progressive mode
        QCOMPARE(model.firstRowNumber(), 1);
    }

    void entryDetails()
    {
        LogEntry e = entry(0, Level::Error, { { "trace_id", "4f1c" }, { "order_id", 48213 }, { "Line", "dup" } });
        e.message = R"({"msg":"payment failed","order_id":48213})";
        const EntryDetails d = EntryDetails::from(e);
        QVERIFY(d.valid);
        QVERIFY(d.isJson);
        QVERIFY(d.prettyMessage.contains("\n    \"msg\": \"payment failed\""));
        QCOMPARE(d.level, "ERROR");
        QCOMPARE(d.traceId, "4f1c");
        QCOMPARE(d.fields.size(), 2);   // Line excluded
        QCOMPARE(d.fields.first().toMap().value("key").toString(), "order_id");
        QCOMPARE(d.fields.first().toMap().value("value").toString(), "48213");
        QVERIFY(d.rawJson.contains("\"_msg\""));
        QVERIFY(d.rawJson.contains("\"_time\": \"2026-10-15T12:00:00.000Z\""));

        e.message = "{not json";
        const EntryDetails plain = EntryDetails::from(e);
        QVERIFY(!plain.isJson);
        QCOMPARE(plain.prettyMessage, "{not json");
        QVERIFY(!EntryDetails().valid);
    }

    void traceFocusAndOpenAsSearch()
    {
        FakeHttpClient http;
        MemoryStore kv;
        MemorySecretStore secrets;
        AppServices services(http, kv, secrets, makeInlineParseExecutor(), {}, [] { return kNow; });
        Environment dev = *services.environments().find("dev");
        dev.url = QUrl("https://g");
        dev.datasourceUid = "u";
        dev.auth = Environment::Auth::None;
        services.environments().upsert(dev);
        Session session(services);

        // Main list with one traced entry.
        http.script(ok(fixture("grafana/discovery_phase1.json")));
        http.script(ok(fixture("grafana/discovery_phase2.json")));
        http.script(ok(fixture("grafana/logs_basic.json")));
        session.start();
        QTRY_VERIFY_WITH_TIMEOUT(session.logs()->rowCount() == 3 && !session.isLoading(), 2000);

        // logs_basic has no trace ids: trace focus refuses, context works.
        FocusSession* f = session.focus();
        f->openTrace(session.logs(), 0);
        QVERIFY(!f->isActive());

        LogStore store;
        store.add({ entry(0, Level::Error, { { "trace_id", "abc" } }) });
        LogListModel traced(&store);
        traced.reload(true);
        http.script(ok(logsBody(QList<Row>{})));
        f->openTrace(&traced, 0);
        QCOMPARE(f->mode(), FocusSession::Mode::Trace);
        QCOMPARE(f->traceId(), "abc");
        QVERIFY(f->canShowTrace());
        QTRY_VERIFY_WITH_TIMEOUT(!f->isLoading() && http.requests.size() == 4, 2000);
        QVERIFY(http.requests.at(3).body.contains("trace_id:\\\"abc\\\""));
        QCOMPARE(f->windowText().count(u':'), 4);   // "HH:mm:ss → HH:mm:ss"
        QVERIFY(!f->anchorTimeText().isEmpty());

        http.script(ok(logsBody(QList<Row>{})));
        f->showContext();
        QCOMPARE(f->mode(), FocusSession::Mode::Context);
        http.script(ok(logsBody(QList<Row>{})));
        f->setWindowSeconds(300);
        QCOMPARE(f->windowSeconds(), 300);
        QTRY_VERIFY_WITH_TIMEOUT(!f->isLoading() && http.requests.size() == 6, 2000);
        http.script(ok(logsBody(QList<Row>{})));
        f->showTrace();
        QTRY_VERIFY_WITH_TIMEOUT(!f->isLoading() && http.requests.size() == 7, 2000);

        // "Open as search": the trace becomes the main search over its window.
        http.script(ok(logsBody(QList<Row>{})));
        f->openAsSearch();
        QVERIFY(!f->isActive());
        QCOMPARE(session.searchText(), "trace_id:\"abc\"");
        QVERIFY(session.timeRangeAbsolute());
        QTRY_VERIFY_WITH_TIMEOUT(!session.isLoading() && http.requests.size() == 8, 2000);
    }
};

QTEST_GUILESS_MAIN(TestViewModels)
#include "tst_view_models.moc"
