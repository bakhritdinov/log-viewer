#include "app/LiveSession.h"

#include "app/Session.h"

namespace lv {

LiveSession::LiveSession(Session& session, QObject* parent)
    : QObject(parent), m_session(session),
      m_tail(std::make_unique<LiveTail>(session.services().http(), session.services().parser(),
                                        session.services().classifyOptions(), session.services().clock())),
      m_logs(new LogListModel(&m_buffer.store(), this))
{
    m_logs->setPageSize(m_buffer.capacity());   // the buffer is one page
    m_logs->setPreferences(&session.prefs());
    connect(m_tail.get(), &LiveTail::entriesArrived, this, &LiveSession::onEntries);
    connect(m_tail.get(), &LiveTail::failed, this, [this](const RequestError& e) {
        m_error = ErrorInfo::from(e, m_session.environmentName());
        emit errorChanged();
    });
    connect(m_tail.get(), &LiveTail::recovered, this, [this] {
        m_error = {};
        emit errorChanged();
    });
}

LiveSession::~LiveSession() = default;

void LiveSession::start()
{
    stop();
    // Interval and buffer size as set in the preferences, read at each start
    // (unless an interval was fixed with setIntervalMs()).
    m_tail->setIntervalMs(m_intervalOverrideMs > 0 ? m_intervalOverrideMs : m_session.prefs().liveIntervalMs());
    m_buffer.setCapacity(m_session.prefs().liveBuffer());
    m_logs->setPageSize(m_buffer.capacity());
    m_buffer.clear();
    m_buffer.setPaused(false);
    m_logs->reload(true);
    m_rate = 0;
    m_rateCount = 0;
    m_rateClock.start();
    const QDateTime since = m_session.services().clock()().addSecs(-60);   // a minute of context
    m_session.resolveConnection([this, since](const Connection& c) {
        SearchSpec spec = m_session.currentSpec();
        spec.connection = c;
        m_tail->start(spec, since);
        emit runningChanged();
    });
    emit bufferChanged();
}

void LiveSession::stop()
{
    if (!m_tail->isRunning()) return;
    m_tail->stop();
    emit runningChanged();
}

void LiveSession::setPaused(bool paused)
{
    if (m_buffer.isPaused() == paused) return;
    m_buffer.setPaused(paused);
    if (!paused) m_logs->reload(true);   // jump to the newest entries
    emit bufferChanged();
}

void LiveSession::onEntries(const LogEntries& entries)
{
    const int added = m_buffer.add(entries);
    m_rateCount += added;
    const qint64 elapsed = m_rateClock.elapsed();
    if (elapsed >= 1000) {
        m_rate = m_rateCount * 1000.0 / elapsed;
        if (elapsed > 10000) {   // sliding-ish window: restart every 10 s
            m_rateCount = 0;
            m_rateClock.restart();
        }
    }
    // While paused the visible rows stay put; only the pending counter moves.
    if (!m_buffer.isPaused() && added > 0) m_logs->reload(false);
    emit bufferChanged();
}

} // namespace lv
