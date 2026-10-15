#include "core/data/ParseExecutor.h"

#include <QTimer>
#include <QtCore/qtcore-config.h>
#if QT_CONFIG(thread) && QT_CONFIG(future)
#include <QFuture>
#include <QPromise>
#include <QThreadPool>
#endif

namespace lv {

namespace {

#if QT_CONFIG(thread) && QT_CONFIG(future)
class ThreadedParseExecutor : public ParseExecutor {
public:
    void parseLogs(QByteArray body, QObject* context, std::function<void(ParsedLogs)> done) override
    {
        auto promise = std::make_shared<QPromise<ParsedLogs>>();
        QFuture<ParsedLogs> future = promise->future();
        // The continuation is bound to `context`: it runs on its thread and is
        // dropped if `context` is gone by then.
        future.then(context, [done = std::move(done)](const ParsedLogs& parsed) { done(parsed); });
        QThreadPool::globalInstance()->start([promise, body = std::move(body)] {
            promise->start();
            promise->addResult(parseLogsResponse(body));
            promise->finish();
        });
    }
};
#endif

class InlineParseExecutor : public ParseExecutor {
public:
    void parseLogs(QByteArray body, QObject* context, std::function<void(ParsedLogs)> done) override
    {
        QTimer::singleShot(0, context, [body = std::move(body), done = std::move(done)] {
            done(parseLogsResponse(body));
        });
    }
};

} // namespace

std::unique_ptr<ParseExecutor> makeThreadedParseExecutor()
{
#if QT_CONFIG(thread) && QT_CONFIG(future)
    return std::make_unique<ThreadedParseExecutor>();
#else
    return makeInlineParseExecutor();   // no threads in this Qt build
#endif
}

std::unique_ptr<ParseExecutor> makeInlineParseExecutor()
{
    return std::make_unique<InlineParseExecutor>();
}

std::unique_ptr<ParseExecutor> makeDefaultParseExecutor()
{
    return makeThreadedParseExecutor();
}

} // namespace lv
