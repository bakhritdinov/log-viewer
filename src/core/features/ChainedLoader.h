#pragma once

#include <QObject>
#include <QPointer>
#include <functional>
#include <optional>

#include "core/data/ErrorClassifier.h"
#include "core/data/GrafanaApi.h"
#include "core/data/ParseExecutor.h"
#include "core/domain/TimeRange.h"
#include "core/features/LogStore.h"
#include "core/query/LogsQL.h"

namespace lv {

// What to search, independent of when.
struct SearchSpec {
    Connection connection;
    StreamSelector stream;
    Query query;
    Level serverLevel = Level::Unknown;   // level pushed into the query
};

using Clock = std::function<QDateTime()>;
Clock systemClock();

// Loads a time range into a LogStore in batches of kBatchLimit, newest first,
// walking back until the range is exhausted or the soft cap is reached. The
// window is fixed when the load starts; each batch asks for `_time:[from, oldest]`
// so nothing is skipped, and overlap is removed by the store.
class ChainedLoader : public QObject {
    Q_OBJECT
public:
    // Soft cap step: a fresh load stops after this many entries; loadMore()
    // raises the cap by the same amount.
    static constexpr int kStep = 5000;
    // Entries per load and per loadMore() (the user's "entries at a time").
    void setStep(int step) { m_step = step > 0 ? step : kStep; }
    int step() const { return m_step; }

    ChainedLoader(HttpClient& http, ParseExecutor& parser, LogStore& store,
                  ClassifyOptions options = {}, Clock clock = systemClock(), QObject* parent = nullptr);
    ~ChainedLoader() override;

    // Clears the store and loads `range` from its newest end. With
    // `keepShown` (a refresh of the same search) the store is cleared only when
    // the first batch arrives: until then, and if the load fails or is stopped
    // before it, the entries already loaded stay as they were.
    void start(const SearchSpec& spec, const TimeRange& range, bool keepShown = false);
    // Continues where the last load stopped (only when hasMore()).
    void loadMore();
    // Stops the running load; what was loaded stays.
    void stop();

    bool isLoading() const { return m_loading; }
    // The last load stopped at the cap (or was stopped) and the range may hold more entries.
    bool hasMore() const { return m_hasMore; }
    // The last load was stopped by stop() before it finished.
    bool wasStopped() const { return m_stopped; }
    TimeRange::Window window() const { return m_window; }

signals:
    void loadingChanged(bool loading);
    // A batch was merged into the store; `added` counts new entries.
    void batchAdded(int added);
    void finished(bool hasMore);
    void failed(const lv::RequestError& error);

private:
    int m_step = kStep;
    void fetchNext();
    void onResponse(quint64 generation, const HttpResponse& r);
    void onParsed(quint64 generation, const ParsedLogs& parsed);
    void finish(bool hasMore);
    void setLoading(bool loading);
    void restoreShown();

    HttpClient& m_http;
    ParseExecutor& m_parser;
    LogStore& m_store;
    ClassifyOptions m_options;
    Clock m_clock;

    SearchSpec m_spec;
    TimeRange::Window m_window;
    QDateTime m_cursor;        // upper bound of the next batch (inclusive)
    int m_cap = kStep;
    bool m_loading = false;
    bool m_hasMore = false;
    bool m_stopped = false;
    quint64 m_generation = 0;  // bumps on start/stop; stale results are dropped

    // The load a keepShown start replaces, until its first batch arrives.
    struct Shown {
        TimeRange::Window window;
        QDateTime cursor;
        int cap = kStep;
        bool hasMore = false;
        bool stopped = false;
    };
    std::optional<Shown> m_shown;
    QPointer<HttpCall> m_call;
};

} // namespace lv
