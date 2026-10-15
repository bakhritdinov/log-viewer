#include <QTest>

#include "core/data/ErrorClassifier.h"
#include "support/FakeHttp.h"

using namespace lv;
using namespace lvtest;
using K = RequestError::Kind;

Q_DECLARE_METATYPE(lv::HttpResponse)
Q_DECLARE_METATYPE(lv::RequestError::Kind)

class TestErrorClassifier : public QObject {
    Q_OBJECT

private slots:
    void classify_data()
    {
        QTest::addColumn<HttpResponse>("response");
        QTest::addColumn<QString>("dsError");
        QTest::addColumn<bool>("browser");
        QTest::addColumn<K>("expected");

        using F = HttpResponse::Failure;
        QTest::newRow("ok") << ok("{}") << "" << false << K::None;
        QTest::newRow("cancelled") << failure(F::Cancelled) << "" << false << K::Cancelled;
        QTest::newRow("client timeout") << failure(F::Timeout) << "" << false << K::TooHeavy;
        QTest::newRow("dns") << failure(F::HostNotFound) << "" << false << K::Unreachable;
        QTest::newRow("refused") << failure(F::ConnectionRefused) << "" << false << K::Unreachable;
        QTest::newRow("closed") << failure(F::RemoteClosed) << "" << false << K::Unreachable;
        QTest::newRow("other") << failure(F::Other) << "" << false << K::Unreachable;
        QTest::newRow("browser fetch failure") << failure(F::Other) << "" << true << K::BlockedByBrowser;
        QTest::newRow("browser timeout stays timeout") << failure(F::Timeout) << "" << true << K::TooHeavy;
        QTest::newRow("tls") << failure(F::Tls) << "" << false << K::Tls;
        QTest::newRow("401") << status(401) << "" << false << K::Unauthorized;
        QTest::newRow("403") << status(403) << "" << false << K::Forbidden;
        QTest::newRow("404") << status(404) << "" << false << K::NotFound;
        QTest::newRow("429") << status(429) << "" << false << K::RateLimited;
        QTest::newRow("400 bad query") << status(400, "parse error") << "" << false << K::BadQuery;
        QTest::newRow("408") << status(408) << "" << false << K::TooHeavy;
        QTest::newRow("504 gateway timeout") << status(504) << "" << false << K::TooHeavy;
        QTest::newRow("500 deadline") << status(500, "context deadline exceeded") << "" << false << K::TooHeavy;
        QTest::newRow("502") << status(502, "bad gateway") << "" << false << K::Server;
        QTest::newRow("200 with ds error") << ok("{}") << "unexpected token" << false << K::BadQuery;
        QTest::newRow("200 with ds timeout") << ok("{}") << "context deadline exceeded" << false << K::TooHeavy;
        QTest::newRow("200 malformed") << ok("<html>") << "Malformed response: x" << false << K::InvalidResponse;
        QTest::newRow("302") << status(302) << "" << false << K::InvalidResponse;
    }
    void classify()
    {
        QFETCH(HttpResponse, response);
        QFETCH(QString, dsError);
        QFETCH(bool, browser);
        QFETCH(K, expected);
        const RequestError e = classifyResponse(response, dsError, { browser });
        QCOMPARE(e.kind, expected);
        QCOMPARE(e.isError(), expected != K::None && expected != K::Cancelled);
    }

    void detailCarriesServerMessage()
    {
        const RequestError e = classifyResponse(status(502, QByteArray(" upstream down \n") + QByteArray(2000, 'x')));
        QVERIFY(e.detail.startsWith("upstream down"));
        QVERIFY(e.detail.size() <= 600);
        QCOMPARE(e.httpStatus, 502);
        QCOMPARE(classifyResponse(failure(HttpResponse::Failure::Other, "boom")).detail, QStringLiteral("boom"));
        QCOMPARE(classifyResponse(ok("{}")).detail, QString());
    }
};

QTEST_GUILESS_MAIN(TestErrorClassifier)
#include "tst_error_classifier.moc"
