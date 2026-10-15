#include "core/features/LiveTail.h"

#include <QLoggingCategory>

namespace lv {

Q_LOGGING_CATEGORY(lcLive, "lv.live")

LiveTail::LiveTail(HttpClient& http, ParseExecutor& parser, ClassifyOptions options, Clock clock, QObject* parent)
    : QObject(parent), m_http(http), m_parser(parser), m_options(options), m_clock(std::move(clock))
{
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, &LiveTail::poll);
}

LiveTail::~LiveTail()
{
    stop();
}

void LiveTail::start(const SearchSpec& spec, const QDateTime& since)
{
    stop();
    m_spec = spec;
    m_cursor = since;
    m_running = true;
    m_failing = false;
    m_failures = 0;
    m_delayMs = m_intervalMs;
    poll();
}

void LiveTail::stop()
{
    ++m_generation;
    m_running = false;
    m_timer.stop();
    if (m_call) {
        HttpCall* call = m_call;
        m_call = nullptr;
        call->disconnect(this);
        call->abort();
    }
}

void LiveTail::schedule(int delayMs)
{
    if (!m_running) return;
    m_delayMs = delayMs;
    m_timer.start(delayMs);
}

void LiveTail::poll()
{
    if (!m_running || m_call) return;
    if (!m_spec.connection.isConfigured()) {
        fail({ RequestError::Kind::NotConfigured, 0, {} });
        return;
    }
    LogsQLRequest q;
    q.stream = m_spec.stream;
    q.query = m_spec.query;
    q.serverLevel = m_spec.serverLevel;
    q.timeFilter = timeSinceFilter(m_cursor);
    const QDateTime now = m_clock();
    const HttpRequest req = logsQueryRequest(m_spec.connection, buildLogsQL(q),
                                             QString::number(m_cursor.toMSecsSinceEpoch()),
                                             QString::number(now.toMSecsSinceEpoch()));
    const quint64 gen = m_generation;
    m_call = m_http.send(req);
    connect(m_call, &HttpCall::finished, this, [this, gen](const HttpResponse& r) { onResponse(gen, r); });
}

void LiveTail::onResponse(quint64 generation, const HttpResponse& r)
{
    if (generation != m_generation) return;
    m_call = nullptr;
    if (!r.ok()) {
        const RequestError e = classifyResponse(r, {}, m_options);
        if (e.kind != RequestError::Kind::Cancelled) fail(e);
        return;
    }
    m_parser.parseLogs(r.body, this, [this, generation](ParsedLogs p) { onParsed(generation, p); });
}

void LiveTail::onParsed(quint64 generation, const ParsedLogs& parsed)
{
    if (generation != m_generation) return;
    if (!parsed.error.isEmpty()) {
        fail(classifyResponse({ HttpResponse::Failure::None, 200, {}, {} }, parsed.error, m_options));
        return;
    }
    m_failures = 0;
    if (m_failing) {
        m_failing = false;
        qCInfo(lcLive) << "poll recovered";
        emit recovered();
    }
    const LogEntries& batch = parsed.entries;
    for (const LogEntry& e : batch)
        if (e.timestamp > m_cursor) m_cursor = e.timestamp;
    if (!batch.isEmpty()) emit entriesArrived(batch);
    // A full batch means more is waiting: catch up immediately.
    schedule(batch.size() >= kBatchLimit ? 0 : m_intervalMs);
}

void LiveTail::fail(const RequestError& e)
{
    qCWarning(lcLive) << "poll failed: kind" << int(e.kind) << "http" << e.httpStatus << e.detail.left(300);
    ++m_failures;
    // A dropped keep-alive connection or one 5xx is routine for a request every
    // few seconds: such a failure is retried at once and reported only when
    // the retry fails too. Credentials or the query being wrong is reported at once.
    using K = RequestError::Kind;
    const bool transient = e.kind == K::Unreachable || e.kind == K::TooHeavy || e.kind == K::Server
                        || e.kind == K::RateLimited || e.kind == K::InvalidResponse;
    if (!m_failing && (!transient || m_failures >= kFailuresBeforeReport)) {
        m_failing = true;
        emit failed(e);
    }
    schedule(m_failures == 1 && transient ? m_intervalMs
                                          : int(std::min<qint64>(qint64(m_intervalMs) << std::clamp(m_failures - 1, 1, 12), kMaxBackoffMs)));
}

int TailBuffer::add(const LogEntries& entries)
{
    const int added = m_store.addCapped(entries, m_capacity);
    if (m_paused) m_pending += added;
    return added;
}

void TailBuffer::setPaused(bool paused)
{
    m_paused = paused;
    if (!paused) m_pending = 0;
}

void TailBuffer::clear()
{
    m_store.clear();
    m_pending = 0;
}

} // namespace lv
