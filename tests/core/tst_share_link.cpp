#include <QTest>
#include <QTimeZone>

#include "core/features/ShareLink.h"

using namespace lv;

Q_DECLARE_METATYPE(lv::SharedView)

namespace {
SharedView view()
{
    SharedView v;
    v.environment = "PROD";
    v.namespaceName = "prod-core";
    v.app = "billing-api";
    v.searchText = "timeout AND level:error";
    v.range = TimeRange::fromKey(u"1h");
    return v;
}
} // namespace

class TestShareLink : public QObject {
    Q_OBJECT

private slots:
    void roundTrip_data()
    {
        QTest::addColumn<SharedView>("v");
        QTest::newRow("preset") << view();
        SharedView abs = view();
        abs.range = *TimeRange::absolute(QDateTime::fromMSecsSinceEpoch(1792054800000, QTimeZone::UTC),
                                         QDateTime::fromMSecsSinceEpoch(1792065600000, QTimeZone::UTC));
        abs.anchorMs = 1792065522318;
        QTest::newRow("absolute with anchor") << abs;
        SharedView nasty = view();
        nasty.searchText = "msg:\"a & b # c\" AND url:http://x/?q=1&r=2 AND ошибка + 100%";
        nasty.app = "app with spaces/and#hash";
        QTest::newRow("special characters") << nasty;
        SharedView today = view();
        today.range = TimeRange::today();
        today.searchText.clear();
        QTest::newRow("today, empty search") << today;
    }
    void roundTrip()
    {
        QFETCH(SharedView, v);
        const auto desktop = parseShareUrl(desktopShareUrl(v));
        QVERIFY(desktop.has_value());
        QCOMPARE(*desktop, v);
        const auto web = parseShareUrl(webShareUrl(QUrl("https://logs.example/app/"), v));
        QVERIFY(web.has_value());
        QCOMPARE(*web, v);
        // The link survives being pasted around as text.
        const auto pasted = parseShareUrl(QUrl(webShareUrl(QUrl("https://logs.example/"), v).toString(QUrl::FullyEncoded)));
        QVERIFY(pasted.has_value());
        QCOMPARE(*pasted, v);
    }

    void urlShapes()
    {
        const QUrl d = desktopShareUrl(view());
        QCOMPARE(d.scheme(), "logviewer");
        QCOMPARE(d.host(), "open");
        QVERIFY(d.query().contains("env=PROD"));
        const QUrl w = webShareUrl(QUrl("https://logs.example/app/"), view());
        QCOMPARE(w.path(), "/app/");
        QVERIFY(w.fragment().startsWith("/open?v=1&"));
        QVERIFY(!w.toString().contains("password"));
    }

    void rejectsForeignOrIncompleteLinks_data()
    {
        QTest::addColumn<QUrl>("url");
        QTest::newRow("other site") << QUrl("https://example.com/#/other?v=1&env=PROD&ns=a&app=b");
        QTest::newRow("other scheme host") << QUrl("logviewer://settings?v=1&env=PROD&ns=a&app=b");
        QTest::newRow("no version") << QUrl("logviewer://open?env=PROD&ns=a&app=b");
        QTest::newRow("future version") << QUrl("logviewer://open?v=2&env=PROD&ns=a&app=b");
        QTest::newRow("missing app") << QUrl("logviewer://open?v=1&env=PROD&ns=a");
        QTest::newRow("reversed range") << QUrl("logviewer://open?v=1&env=PROD&ns=a&app=b&from=10&to=5");
        QTest::newRow("bad bound") << QUrl("logviewer://open?v=1&env=PROD&ns=a&app=b&from=x&to=5");
    }
    void rejectsForeignOrIncompleteLinks()
    {
        QFETCH(QUrl, url);
        QVERIFY(!parseShareUrl(url).has_value());
    }

    void unknownRangeKeyFallsBackToDefault()
    {
        const auto v = parseShareUrl(QUrl("logviewer://open?v=1&env=PROD&ns=a&app=b&range=nonsense"));
        QVERIFY(v.has_value());
        QCOMPARE(v->range, TimeRange());
    }
};

QTEST_GUILESS_MAIN(TestShareLink)
#include "tst_share_link.moc"
