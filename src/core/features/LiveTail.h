#pragma once

#include <QObject>
#include <QPointer>
#include <QTimer>

#include "core/features/ChainedLoader.h"

namespace lv {

// Polls for entries newer than the newest one seen (`_time:>=cursor`, overlap
// removed by the receiver's store). A full batch means a burst: poll again at
// once. A network blip is retried at once and reported only if it repeats;
// failures back off (doubling, up to 30 s) and recover on the next success.
class LiveTail : public QObject {
    Q_OBJECT
public:
    static constexpr int kDefaultIntervalMs = 2000;
    static constexpr int kMaxBackoffMs = 30000;
    static constexpr int kFailuresBeforeReport = 2;   // network blips in a row before "no connection"

    LiveTail(HttpClient& http, ParseExecutor& parser, ClassifyOptions options = {},
             Clock clock = systemClock(), QObject* parent = nullptr);
    ~LiveTail() override;

    // Starts polling for entries at or after `since`.
    void start(const SearchSpec& spec, const QDateTime& since);
    void stop();
    bool isRunning() const { return m_running; }
    bool isFailing() const { return m_failing; }

    void setIntervalMs(int ms) { m_intervalMs = ms; }
    int currentDelayMs() const { return m_delayMs; }

signals:
    void entriesArrived(const lv::LogEntries& entries);
    void failed(const lv::RequestError& error);
    void recovered();

private:
    void poll();
    void schedule(int delayMs);
    void onResponse(quint64 generation, const HttpResponse& r);
    void onParsed(quint64 generation, const ParsedLogs& parsed);
    void fail(const RequestError& e);

    HttpClient& m_http;
    ParseExecutor& m_parser;
    ClassifyOptions m_options;
    Clock m_clock;
    QTimer m_timer;

    SearchSpec m_spec;
    QDateTime m_cursor;
    int m_intervalMs = kDefaultIntervalMs;
    int m_delayMs = kDefaultIntervalMs;
    bool m_running = false;
    bool m_failing = false;
    int m_failures = 0;             // in a row
    quint64 m_generation = 0;
    QPointer<HttpCall> m_call;
};

// The live view's buffer: newest entries on top, capped, with a pause that
// keeps collecting but counts what the user has not seen yet.
class TailBuffer {
public:
    static constexpr int kDefaultCapacity = 10000;

    explicit TailBuffer(int capacity = kDefaultCapacity) : m_capacity(capacity) {}

    // Returns how many entries were new.
    int add(const LogEntries& entries);
    void setPaused(bool paused);
    bool isPaused() const { return m_paused; }
    // New entries that arrived while paused.
    int pending() const { return m_pending; }
    void clear();

    const LogStore& store() const { return m_store; }
    int capacity() const { return m_capacity; }

private:
    LogStore m_store;
    int m_capacity;
    bool m_paused = false;
    int m_pending = 0;
};

} // namespace lv
