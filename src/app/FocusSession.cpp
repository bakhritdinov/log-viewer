#include "app/FocusSession.h"

#include "app/Session.h"

namespace lv {

FocusSession::FocusSession(Session& session, QObject* parent)
    : QObject(parent), m_session(session),
      m_loader(std::make_unique<ChainedLoader>(session.services().http(), session.services().parser(), m_store,
                                               session.services().classifyOptions(), session.services().clock())),
      m_logs(new LogListModel(&m_store, this))
{
    m_logs->setPageSize(ChainedLoader::kStep);   // one page: the whole window
    connect(m_loader.get(), &ChainedLoader::loadingChanged, this, &FocusSession::loadingChanged);
    connect(m_loader.get(), &ChainedLoader::batchAdded, this, [this] {
        m_logs->reload(false);
        locateAnchor();
    });
    connect(m_loader.get(), &ChainedLoader::failed, this, [this](const RequestError& e) {
        m_error = ErrorInfo::from(e, m_session.environmentName());
        emit changed();
    });
}

FocusSession::~FocusSession() = default;

void FocusSession::openContext(LogListModel* model, int row, int seconds)
{
    const LogEntry* e = model ? model->entryAt(row) : nullptr;
    if (!e) return;
    m_anchor = *e;
    m_seconds = std::max(1, seconds);
    m_mode = Mode::Context;
    load();
}

void FocusSession::openTrace(LogListModel* model, int row)
{
    const LogEntry* e = model ? model->entryAt(row) : nullptr;
    if (!e || traceIdOf(*e).isEmpty()) return;
    m_anchor = *e;
    m_mode = Mode::Trace;
    load();
}

void FocusSession::showContext()
{
    if (m_mode == Mode::None) return;
    m_mode = Mode::Context;
    load();
}

void FocusSession::showTrace()
{
    if (m_mode == Mode::None || !canShowTrace()) return;
    m_mode = Mode::Trace;
    load();
}

void FocusSession::setWindowSeconds(int seconds)
{
    seconds = std::max(1, seconds);
    if (m_seconds == seconds) return;
    m_seconds = seconds;
    if (m_mode != Mode::None) load();
    else emit changed();
}

void FocusSession::load()
{
    m_error = {};
    m_anchorRow = -1;
    const SearchSpec base = m_session.currentSpec();
    const FocusRequest req = m_mode == Mode::Trace ? traceRequest(base, m_anchor)
                                                   : contextRequest(base, m_anchor, m_seconds);
    m_range = req.range;
    m_session.resolveConnection([this, req](const Connection& c) {
        SearchSpec spec = req.spec;
        spec.connection = c;
        m_loader->start(spec, req.range);
        m_logs->reload(true);
    });
    emit changed();
}

void FocusSession::locateAnchor()
{
    const qint64 key = entryKey(m_anchor);
    for (int row = 0; row < m_logs->rowCount(); ++row) {
        if (entryKey(*m_logs->entryAt(row)) != key) continue;
        if (m_anchorRow != row) {
            m_anchorRow = row;
            emit changed();
        }
        return;
    }
}

void FocusSession::close()
{
    if (m_mode == Mode::None) return;
    m_loader->stop();
    m_store.clear();
    m_logs->reload(true);
    m_mode = Mode::None;
    m_anchorRow = -1;
    m_error = {};
    emit changed();
}

void FocusSession::openAsSearch()
{
    if (m_mode == Mode::None) return;
    const QString text = m_mode == Mode::Trace ? FieldFilter{ QStringLiteral("trace_id"), traceId() }.toText()
                                               : QString();
    const TimeRange range = m_range;
    close();
    m_session.setSearchText(text);
    m_session.setRange(range);
}

QString FocusSession::anchorTimeText() const
{
    return m_mode == Mode::None ? QString()
                                : m_anchor.timestamp.toLocalTime().toString(QStringLiteral("HH:mm:ss.zzz"));
}

QString FocusSession::traceId() const
{
    return traceIdOf(m_anchor);
}

QString FocusSession::windowText() const
{
    if (m_mode == Mode::None) return {};
    const auto fmt = [](const QDateTime& t) { return t.toLocalTime().toString(QStringLiteral("HH:mm:ss")); };
    return QStringLiteral("%1 → %2").arg(fmt(m_range.absoluteFrom()), fmt(m_range.absoluteTo()));
}

} // namespace lv
