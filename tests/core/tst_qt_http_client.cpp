// QtHttpClient against a tiny local HTTP server: real sockets, no internet.
#include <QSignalSpy>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTest>

#include "core/data/QtHttpClient.h"

using namespace lv;

Q_DECLARE_METATYPE(lv::HttpResponse)

namespace {

// Answers by path: /ok → 200 echoing the request body, /fail → 503,
// /hang → never answers. Records the raw request it received.
class MiniServer : public QTcpServer {
public:
    MiniServer()
    {
        connect(this, &QTcpServer::newConnection, this, [this] {
            while (QTcpSocket* s = nextPendingConnection()) {
                connect(s, &QTcpSocket::readyRead, this, [this, s] { onData(s); });
                connect(s, &QTcpSocket::disconnected, s, &QObject::deleteLater);
            }
        });
        listen(QHostAddress::LocalHost);
    }

    QUrl url(const QString& path) const
    {
        return QUrl(QStringLiteral("http://127.0.0.1:%1%2").arg(serverPort()).arg(path));
    }

    QByteArray lastRequest;

private:
    void onData(QTcpSocket* s)
    {
        QByteArray& buf = m_buffers[s];
        buf += s->readAll();
        const qsizetype headerEnd = buf.indexOf("\r\n\r\n");
        if (headerEnd < 0) return;
        const QByteArray head = buf.left(headerEnd);
        qsizetype length = 0;
        for (const QByteArray& line : head.split('\n')) {
            if (line.toLower().startsWith("content-length:")) length = line.mid(15).trimmed().toLongLong();
        }
        if (buf.size() < headerEnd + 4 + length) return;
        lastRequest = buf;
        const QByteArray body = buf.mid(headerEnd + 4, length);
        const QByteArray path = head.split(' ').value(1);
        if (path == "/hang") return;
        const QByteArray status = path == "/fail" ? "503 Service Unavailable" : "200 OK";
        const QByteArray reply = path == "/fail" ? QByteArray("down") : body;
        s->write("HTTP/1.1 " + status + "\r\nContent-Type: text/plain\r\nContent-Length: "
                 + QByteArray::number(reply.size()) + "\r\nConnection: close\r\n\r\n" + reply);
        s->disconnectFromHost();
    }

    QHash<QTcpSocket*, QByteArray> m_buffers;
};

HttpResponse sendAndWait(QtHttpClient& client, HttpRequest req, std::function<void(HttpCall*)> after = {})
{
    HttpCall* call = client.send(req);
    QSignalSpy spy(call, &HttpCall::finished);
    if (after) after(call);
    if (spy.isEmpty() && !spy.wait(5000)) qFatal("no response");
    return spy.first().first().value<HttpResponse>();
}

} // namespace

class TestQtHttpClient : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() { qRegisterMetaType<lv::HttpResponse>(); }

    void postEchoesBodyAndSendsHeaders()
    {
        MiniServer server;
        QtHttpClient client;
        HttpRequest req;
        req.url = server.url("/ok");
        req.body = R"({"x":1})";
        req.headers.emplaceBack(QByteArrayLiteral("Authorization"), QByteArrayLiteral("Bearer t"));
        const HttpResponse r = sendAndWait(client, req);
        QCOMPARE(r.failure, HttpResponse::Failure::None);
        QCOMPARE(r.status, 200);
        QVERIFY(r.ok());
        QCOMPARE(r.body, QByteArray(R"({"x":1})"));
        QVERIFY(server.lastRequest.startsWith("POST /ok "));
        // Header names are case-insensitive; Qt 6.8 sends them in lower case.
        QVERIFY(server.lastRequest.toLower().contains("authorization: bearer t"));
    }

    void httpErrorIsAResponseNotAFailure()
    {
        MiniServer server;
        QtHttpClient client;
        const HttpResponse r = sendAndWait(client, { server.url("/fail") });
        QCOMPARE(r.failure, HttpResponse::Failure::None);
        QCOMPARE(r.status, 503);
        QCOMPARE(r.body, QByteArray("down"));
        QVERIFY(!r.ok());
    }

    void timeout()
    {
        MiniServer server;
        QtHttpClient client;
        HttpRequest req{ server.url("/hang") };
        req.timeoutMs = 200;
        QCOMPARE(sendAndWait(client, req).failure, HttpResponse::Failure::Timeout);
    }

    void abortReportsCancelled()
    {
        MiniServer server;
        QtHttpClient client;
        const HttpResponse r = sendAndWait(client, { server.url("/hang") }, [](HttpCall* c) { c->abort(); });
        QCOMPARE(r.failure, HttpResponse::Failure::Cancelled);
    }

    void connectionRefused()
    {
        quint16 port;
        {
            QTcpServer probe;
            probe.listen(QHostAddress::LocalHost);
            port = probe.serverPort();
        }   // closed again: nothing listens on `port`
        QtHttpClient client;
        const HttpResponse r = sendAndWait(client, { QUrl(QStringLiteral("http://127.0.0.1:%1/").arg(port)) });
        QCOMPARE(r.failure, HttpResponse::Failure::ConnectionRefused);
        QCOMPARE(r.status, 0);
        QVERIFY(!r.errorString.isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestQtHttpClient)
#include "tst_qt_http_client.moc"
