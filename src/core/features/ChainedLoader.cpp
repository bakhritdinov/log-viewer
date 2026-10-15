#include "core/features/ChainedLoader.h"

#include <QTimeZone>

namespace lv {

Clock systemClock()
{
    return [] { return QDateTime::currentDateTimeUtc(); };
}

ChainedLoader::ChainedLoader(HttpClient& http, ParseExecutor& parser, LogStore& store,
                             ClassifyOptions options, Clock clock, QObject* parent)
    : QObject(parent), m_http(http), m_parser(parser), m_store(store),
      m_options(options), m_clock(std::move(clock))
{
}

ChainedLoader::~ChainedLoader()
{
    ++m_generation;
    if (m_call) {
        m_call->disconnect(this);
        m_call->abort();
    }
}

void ChainedLoader::start(const SearchSpec& spec, const TimeRange& range)
{
    stop();
    m_spec = spec;
    m_window = range.resolve(m_clock());
    m_cursor = m_window.to;
    m_cap = m_step;
    m_hasMore = false;
    m_stopped = false;
    m_store.clear();
    if (!spec.connection.isConfigured()) {
        emit failed({ RequestError::Kind::NotConfigured, 0, {} });
        return;
    }
    fetchNext();
}

void ChainedLoader::loadMore()
{
    if (m_loading || !m_hasMore) return;
    m_cap = m_store.size() + m_step;
    m_hasMore = false;
    m_stopped = false;
    fetchNext();
}

void ChainedLoader::stop()
{
    // Stopped mid-chain: the range was not walked to its start, so "load more"
    // continues from the cursor (the oldest loaded entry).
    if (m_loading) {
        m_hasMore = true;
        m_stopped = true;
    }
    ++m_generation;
    if (m_call) {
        HttpCall* call = m_call;
        m_call = nullptr;
        call->disconnect(this);
        call->abort();
    }
    setLoading(false);
}

void ChainedLoader::fetchNext()
{
    setLoading(true);
    LogsQLRequest q;
    q.stream = m_spec.stream;
    q.query = m_spec.query;
    q.serverLevel = m_spec.serverLevel;
    q.timeFilter = timeRangeFilter(m_window.from, m_cursor);
    const HttpRequest req = logsQueryRequest(m_spec.connection, buildLogsQL(q),
                                             QString::number(m_window.from.toMSecsSinceEpoch()),
                                             QString::number(m_cursor.toMSecsSinceEpoch()));
    const quint64 gen = m_generation;
    m_call = m_http.send(req);
    connect(m_call, &HttpCall::finished, this, [this, gen](const HttpResponse& r) { onResponse(gen, r); });
}

void ChainedLoader::onResponse(quint64 generation, const HttpResponse& r)
{
    if (generation != m_generation) return;
    m_call = nullptr;
    if (!r.ok()) {
        const RequestError e = classifyResponse(r, {}, m_options);
        if (e.kind == RequestError::Kind::Cancelled) return;
        setLoading(false);
        emit failed(e);
        return;
    }
    m_parser.parseLogs(r.body, this, [this, generation](ParsedLogs parsed) { onParsed(generation, parsed); });
}

void ChainedLoader::onParsed(quint64 generation, const ParsedLogs& parsed)
{
    if (generation != m_generation) return;
    if (!parsed.error.isEmpty()) {
        setLoading(false);
        emit failed(classifyResponse({ HttpResponse::Failure::None, 200, {}, {} }, parsed.error, m_options));
        return;
    }

    const LogEntries& batch = parsed.entries;
    const int added = m_store.add(batch);
    emit batchAdded(added);

    // Guardrails against endless paging (kept from the legacy loader, plus the
    // all-duplicates case introduced by inclusive bounds).
    if (batch.isEmpty() || added == 0) return finish(false);       // nothing new: range exhausted
    if (batch.size() < kBatchLimit) return finish(false);          // short batch: window exhausted

    qint64 oldest = batch.first().timeMs();
    for (const LogEntry& e : batch) oldest = std::min(oldest, e.timeMs());
    m_cursor = QDateTime::fromMSecsSinceEpoch(oldest, QTimeZone::UTC);
    if (m_cursor <= m_window.from) return finish(false);           // walked past the start
    if (m_store.size() >= m_cap) return finish(true);              // soft cap: more may exist

    fetchNext();
}

void ChainedLoader::finish(bool hasMore)
{
    m_hasMore = hasMore;
    setLoading(false);
    emit finished(hasMore);
}

void ChainedLoader::setLoading(bool loading)
{
    if (m_loading == loading) return;
    m_loading = loading;
    emit loadingChanged(loading);
}

} // namespace lv
