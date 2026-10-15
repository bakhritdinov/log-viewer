#pragma once

// Test doubles for lv::HttpClient: requests are recorded, responses are
// scripted (delivered on the next event-loop tick) or completed by hand, so
// tests can reproduce races, cancellation and failures deterministically.

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QTimer>
#include <optional>

#include "core/data/Http.h"

namespace lvtest {

inline QByteArray fixture(const QString& relativePath)
{
    QFile f(QStringLiteral(LOGVIEWER_FIXTURES_DIR "/") + relativePath);
    if (!f.open(QIODevice::ReadOnly)) qFatal("missing fixture %s", qPrintable(f.fileName()));
    return f.readAll();
}

inline lv::HttpResponse ok(const QByteArray& body)
{
    lv::HttpResponse r;
    r.status = 200;
    r.body = body;
    return r;
}

inline lv::HttpResponse status(int code, const QByteArray& body = {})
{
    lv::HttpResponse r;
    r.status = code;
    r.body = body;
    return r;
}

inline lv::HttpResponse failure(lv::HttpResponse::Failure f, const QString& text = QStringLiteral("transport error"))
{
    lv::HttpResponse r;
    r.failure = f;
    r.errorString = text;
    return r;
}

inline QJsonObject jsonBody(const lv::HttpRequest& r)
{
    return QJsonDocument::fromJson(r.body).object();
}

inline QByteArray header(const lv::HttpRequest& r, const QByteArray& name)
{
    for (const auto& [n, v] : r.headers)
        if (n.compare(name, Qt::CaseInsensitive) == 0) return v;
    return {};
}

class FakeHttpCall : public lv::HttpCall {
public:
    void abort() override { finish(failure(lv::HttpResponse::Failure::Cancelled, QStringLiteral("aborted"))); }

    void finish(const lv::HttpResponse& r)
    {
        if (m_done) return;
        m_done = true;
        emit finished(r);
        deleteLater();
    }
    bool isDone() const { return m_done; }

private:
    bool m_done = false;
};

class FakeHttpClient : public lv::HttpClient {
public:
    // Responses for upcoming send() calls, in order. std::nullopt leaves that
    // call pending until complete() is called.
    void script(std::optional<lv::HttpResponse> response) { m_script.append(std::move(response)); }

    lv::HttpCall* send(const lv::HttpRequest& request) override
    {
        requests.append(request);
        auto* call = new FakeHttpCall;
        calls.append(call);
        if (!m_script.isEmpty()) {
            const std::optional<lv::HttpResponse> next = m_script.takeFirst();
            if (next) QTimer::singleShot(0, call, [call, r = *next] { call->finish(r); });
        }
        return call;
    }

    // Completes the i-th call (if still alive and pending).
    void complete(qsizetype i, const lv::HttpResponse& r)
    {
        if (i < calls.size() && calls.at(i)) calls.at(i)->finish(r);
    }

    QList<lv::HttpRequest> requests;
    QList<QPointer<FakeHttpCall>> calls;

private:
    QList<std::optional<lv::HttpResponse>> m_script;
};

} // namespace lvtest
