// A short network blip is sent again before anyone sees an error; real answers,
// timeouts and cancels are passed on at once.
#include <QSignalSpy>
#include <QTest>

#include "core/data/RetryingHttpClient.h"
#include "support/FakeHttp.h"

Q_DECLARE_METATYPE(lv::HttpResponse)

using namespace lv;
using namespace lvtest;

namespace {
struct Result {
    int calls = 0;
    HttpResponse last;
};

void run(HttpClient& client, Result& result, int timeoutMs = 2000)
{
    HttpCall* call = client.send(HttpRequest{ QUrl("https://grafana/api/ds/query") });
    QObject::connect(call, &HttpCall::finished, [&result](const HttpResponse& r) { ++result.calls; result.last = r; });
    QTRY_COMPARE_WITH_TIMEOUT(result.calls, 1, timeoutMs);
    QTest::qWait(50);   // and only once
}
} // namespace

class TestRetryingHttpClient : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() { qRegisterMetaType<lv::HttpResponse>(); }

    void aBlipIsRetriedAndHidden()
    {
        FakeHttpClient http;
        http.script(failure(HttpResponse::Failure::ConnectionRefused));
        http.script(failure(HttpResponse::Failure::HostNotFound));
        http.script(ok("{}"));
        RetryingHttpClient client(http, { 10, 10 });
        Result r;
        run(client, r);
        QCOMPARE(r.calls, 1);
        QVERIFY(r.last.ok());
        QCOMPARE(http.requests.size(), 3);
        QCOMPARE(http.requests.at(2).url, QUrl("https://grafana/api/ds/query"));
    }

    void aLastingOutageShowsAfterTheRetries()
    {
        FakeHttpClient http;
        for (int i = 0; i < 3; ++i) http.script(failure(HttpResponse::Failure::Other, "network down"));
        RetryingHttpClient client(http, { 10, 10 });
        Result r;
        run(client, r);
        QCOMPARE(r.last.failure, HttpResponse::Failure::Other);
        QCOMPARE(r.last.errorString, QString("network down"));
        QCOMPARE(http.requests.size(), 3);
    }

    void answersTimeoutsAndTlsAreNotRetried()
    {
        for (const HttpResponse& answer : { status(500, "boom"), status(401), failure(HttpResponse::Failure::Timeout),
                                            failure(HttpResponse::Failure::Tls) }) {
            FakeHttpClient http;
            http.script(answer);
            RetryingHttpClient client(http, { 10, 10 });
            Result r;
        run(client, r);
            QCOMPARE(r.last.status, answer.status);
            QCOMPARE(r.last.failure, answer.failure);
            QCOMPARE(http.requests.size(), 1);
        }
    }

    void abortWhileWaitingCancelsOnce()
    {
        FakeHttpClient http;
        http.script(failure(HttpResponse::Failure::RemoteClosed));
        RetryingHttpClient client(http, { 500 });
        HttpCall* call = client.send(HttpRequest{ QUrl("https://grafana") });
        QSignalSpy finished(call, &HttpCall::finished);
        QTRY_COMPARE(http.requests.size(), 1);
        QTest::qWait(50);                         // the first attempt failed; waiting to retry
        call->abort();
        QCOMPARE(finished.size(), 1);
        QCOMPARE(finished.at(0).at(0).value<HttpResponse>().failure, HttpResponse::Failure::Cancelled);
        QTest::qWait(700);
        QCOMPARE(http.requests.size(), 1);        // no retry after the cancel
    }

    void abortInFlightCancelsOnce()
    {
        FakeHttpClient http;
        http.script(std::nullopt);                // stays pending
        RetryingHttpClient client(http, { 10 });
        HttpCall* call = client.send(HttpRequest{ QUrl("https://grafana") });
        QSignalSpy finished(call, &HttpCall::finished);
        call->abort();
        QTRY_COMPARE(finished.size(), 1);
        QCOMPARE(finished.at(0).at(0).value<HttpResponse>().failure, HttpResponse::Failure::Cancelled);
        QTest::qWait(50);
        QCOMPARE(http.requests.size(), 1);
    }
};

QTEST_GUILESS_MAIN(TestRetryingHttpClient)
#include "tst_retrying_http_client.moc"
