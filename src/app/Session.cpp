#include "app/DeviceBridge.h"
#include "app/Session.h"

#include "app/Preferences.h"

#include <QCoreApplication>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>

#include "app/FocusSession.h"
#include "app/LiveSession.h"
#include "app/Presenters.h"
#include "core/query/Suggestions.h"

namespace lv {

namespace {

QPointer<Session> g_instance;
const QString kRecentKey = QStringLiteral("recent/sources");
constexpr int kRecentCapacity = 5;


} // namespace

// ── construction / singleton ────────────────────────────────────────────────

Session::Session(AppServices& services, QObject* parent)
    : QObject(parent), m_services(services),
      m_discovery(std::make_unique<LabelDiscovery>(services.http(), services.classifyOptions())),
      m_loader(std::make_unique<ChainedLoader>(services.http(), services.parser(), m_store,
                                               services.classifyOptions(), services.clock())),
      m_environments(new MapListModel(presenters::environmentRoles(), this)),
      m_recent(new MapListModel({ "environmentId", "environmentName", "environmentColor", "namespaceName", "app" }, this)),
      m_chips(new MapListModel(presenters::chipRoles(), this)),
      m_suggestions(new MapListModel(presenters::suggestionRoles(), this)),
      m_histogram(new MapListModel(presenters::histogramRoles(), this)),
      m_facets(new MapListModel(presenters::facetRoles(), this)),
      m_patterns(new MapListModel(presenters::patternRoles(), this)),
      m_saved(new MapListModel(presenters::savedQueryRoles(), this)),
      m_logs(new LogListModel(&m_store, this))
{
    m_prefs = new Preferences(services.settings(), this);
    m_logs->setPreferences(m_prefs);
    connect(m_prefs, &Preferences::changed, this, &Session::prefsChanged);
    connect(m_prefs, &Preferences::changed, this, &Session::selectionChanged);   // the details' time text
    // The period to start with: the last one used, or the one set in the preferences.
    m_range = services.selection().timeRange();
    if (const QString key = m_prefs->defaultRange(); key != u"last") {
        const TimeRange preset = TimeRange::fromKey(key);
        if (preset.key() == key) m_range = preset;
    }

    connect(m_discovery.get(), &LabelDiscovery::finished, this, &Session::onDiscovered);
    connect(m_discovery.get(), &LabelDiscovery::failed, this, [this](const RequestError& e) {
        emit discoveringChanged();
        fail(e);
    });
    connect(m_loader.get(), &ChainedLoader::batchAdded, this, &Session::onBatch);
    connect(m_loader.get(), &ChainedLoader::finished, this, &Session::onLoadFinished);
    connect(m_loader.get(), &ChainedLoader::loadingChanged, this, &Session::loadingChanged);
    connect(m_loader.get(), &ChainedLoader::failed, this, [this](const RequestError& e) {
        fail(e);
    });

    connect(&m_autoRefresh, &QTimer::timeout, this, [this] {
        if (!isLoading() && !m_app.isEmpty()) runSearch(true);
    });

    m_focus = new FocusSession(*this, this);
    m_live = new LiveSession(*this, this);
    m_device = new DeviceBridge(this);

    refreshEnvironments();
    refreshSavedQueries();
    refreshRecent();
    refreshChipsAndSuggestions();
}

Session::~Session()
{
    if (g_instance == this) g_instance = nullptr;
}

void Session::setInstance(Session* session)
{
    g_instance = session;
}

Session* Session::instance()
{
    return g_instance;
}

Session* Session::create(QQmlEngine*, QJSEngine* engine)
{
    Q_ASSERT_X(g_instance, "Session::create", "Session::setInstance() must be called before QML loads");
    QJSEngine::setObjectOwnership(g_instance, QJSEngine::CppOwnership);
    Q_UNUSED(engine);
    return g_instance;
}

// ── connection / discovery ──────────────────────────────────────────────────

void Session::resolveConnection(std::function<void(const Connection&)> done)
{
    if (m_connection) {
        done(*m_connection);
        return;
    }
    const Environment env = m_services.environments().current();
    const quint64 gen = m_connectionGeneration;
    auto password = std::make_shared<QString>();
    auto pending = std::make_shared<int>(2);
    QPointer<Session> self(this);
    auto finish = [self, env, gen, password, pending, done](const QString& token) {
        if (!self || gen != self->m_connectionGeneration) return;
        self->m_connection = env.connection(*password, token);
        done(*self->m_connection);
    };
    auto token = std::make_shared<QString>();
    auto step = [pending, token, finish] {
        if (--*pending == 0) finish(*token);
    };
    m_services.secrets().read(env.passwordKey(), [password, step](bool, const QString& v) { *password = v; step(); });
    m_services.secrets().read(env.tokenKey(), [token, step](bool, const QString& v) { *token = v; step(); });
}

void Session::start()
{
    clearError();
    const Environment env = m_services.environments().current();
    if (!env.isConfigured()) {
        fail({ RequestError::Kind::NotConfigured, 0, {} });
        return;
    }
    resolveConnection([this, env](const Connection& c) {
        m_discovery->start(c, env.nsLabel, env.appLabel);
        emit discoveringChanged();
    });
}

void Session::rediscover()
{
    m_streams.clear();
    emit streamsChanged();
    start();
}

void Session::onDiscovered(const DiscoveryResult& result)
{
    m_streams = result.streams;
    m_nsLabel = result.nsLabel;
    m_appLabel = result.appLabel;
    m_logs->setServiceField(m_appLabel);
    emit discoveringChanged();
    emit streamsChanged();

    // Keep a source chosen before discovery finished (link, saved query, recent)
    // if it exists; otherwise the remembered one; otherwise the first.
    QString ns = m_namespace;
    QString app = m_app;
    if (!m_streams.value(ns).contains(app)) {
        const Selection remembered = m_services.selection().selection(environmentId());
        ns = remembered.namespaceName;
        app = remembered.app;
    }
    if (!m_streams.value(ns).contains(app)) {
        ns = m_streams.isEmpty() ? QString() : m_streams.firstKey();
        app = appsOf(ns).value(0);
    }
    m_namespace.clear();   // force selectSource() to run the search
    m_app.clear();
    if (!ns.isEmpty() && !app.isEmpty()) selectSource(ns, app);
}

QStringList Session::appsOf(const QString& namespaceName) const
{
    QStringList apps = m_streams.value(namespaceName);
    apps.sort(Qt::CaseInsensitive);
    return apps;
}

void Session::selectSource(const QString& namespaceName, const QString& app)
{
    if (namespaceName == m_namespace && app == m_app) return;
    m_namespace = namespaceName;
    m_app = app;
    emit sourceChanged();
    rememberSource();
    resetLevelFilter();
    runSearch(false);
}

void Session::selectNamespace(const QString& namespaceName)
{
    selectSource(namespaceName, appsOf(namespaceName).value(0));
}

void Session::rememberSource()
{
    if (m_namespace.isEmpty() || m_app.isEmpty()) return;
    m_services.selection().setSelection(environmentId(), { m_namespace, m_app });
    QJsonArray list = QJsonDocument::fromJson(m_services.settings().value(kRecentKey).toByteArray()).array();
    const QJsonObject entry{ { "env", environmentId() }, { "ns", m_namespace }, { "app", m_app } };
    for (qsizetype i = list.size() - 1; i >= 0; --i)
        if (list.at(i).toObject() == entry) list.removeAt(i);
    list.prepend(entry);
    while (list.size() > kRecentCapacity) list.removeLast();
    m_services.settings().setValue(kRecentKey, QJsonDocument(list).toJson(QJsonDocument::Compact));
    refreshRecent();
}

QVariantList Session::sourceMatches(const QString& query) const
{
    QMap<QString, QStringList> apps;
    for (const QString& ns : namespaces()) apps.insert(ns, appsOf(ns));
    return presenters::sourceMatches(apps, query);
}

void Session::selectRecentSource(int index)
{
    const QVariantMap r = m_recent->get(index);
    if (r.isEmpty()) return;
    const QString env = r.value("environmentId").toString();
    if (env != environmentId()) {
        switchEnvironment(env);
        m_namespace = r.value("namespaceName").toString();   // picked up by onDiscovered
        m_app = r.value("app").toString();
        emit sourceChanged();
        return;
    }
    selectSource(r.value("namespaceName").toString(), r.value("app").toString());
}

void Session::switchEnvironment(const QString& id)
{
    if (!m_services.environments().find(id)) return;
    m_services.environments().setCurrent(id);
    m_connection.reset();
    ++m_connectionGeneration;
    m_discovery->cancel();
    m_loader->stop();
    m_live->stop();
    m_focus->close();
    m_store.clear();
    markPatternsStale();
    m_streams.clear();
    m_namespace.clear();
    m_app.clear();
    resetLevelFilter();
    m_logs->reload(true);
    setSelectedRow(-1);
    refreshDerived();
    refreshEnvironments();
    refreshRecent();
    emit environmentChanged();
    emit streamsChanged();
    emit sourceChanged();
    start();
}

void Session::environmentsEdited(const QString& changedId)
{
    refreshEnvironments();
    refreshSavedQueries();
    refreshRecent();
    const bool currentAffected = changedId.isEmpty() || changedId == environmentId()
                              || !m_services.environments().find(environmentId());
    emit environmentChanged();
    if (currentAffected) switchEnvironment(m_services.environments().current().id);
}

QString Session::environmentId() const { return m_services.environments().current().id; }
QString Session::environmentName() const { return m_services.environments().current().name; }
QString Session::environmentColor() const { return m_services.environments().current().color; }
bool Session::secretsSecure() const { return m_services.secrets().isSecure(); }

// ── search ──────────────────────────────────────────────────────────────────

SearchSpec Session::currentSpec() const
{
    SearchSpec s;
    if (m_connection) s.connection = *m_connection;
    s.stream = { m_nsLabel, m_namespace, m_appLabel, m_app };
    s.query = Query::parse(m_searchText);
    s.serverLevel = m_levelServerSide ? m_activeLevel : Level::Unknown;
    return s;
}

void Session::setSearchText(const QString& text)
{
    if (m_searchText == text) return;
    m_searchText = text;
    if (!m_searchError.isEmpty()) {
        m_searchError.clear();
        emit searchErrorChanged();
    }
    refreshChipsAndSuggestions();
    emit searchTextChanged();
}

QStringList Session::searchTerms() const
{
    return Query::parse(m_searchText).words();
}

int Session::loadStep() const
{
    return m_prefs->loadStep();
}

QStringList Session::history() const
{
    return m_services.history().items();
}

QString Session::historySource(const QString& text) const
{
    return m_services.history().source(text);
}

void Session::search()
{
    // A broken query is not sent: the results stay and the field says why.
    const QueryProblem problem = checkQuery(m_searchText);
    QString message;
    switch (problem.kind) {
    case QueryProblem::Kind::None: break;
    case QueryProblem::Kind::UnclosedQuote:
        message = problem.field.isEmpty()
            ? QCoreApplication::translate("Session", "A quote is not closed — the search was not run")
            : QCoreApplication::translate("Session", "A quote after %1: is not closed — the search was not run").arg(problem.field);
        break;
    case QueryProblem::Kind::BadRegex:
        message = QCoreApplication::translate("Session", "The regular expression for %1 is not valid — the search was not run").arg(problem.field);
        break;
    case QueryProblem::Kind::EmptyValue:
        message = QCoreApplication::translate("Session", "%1: has no value — the search was not run").arg(problem.field);
        break;
    }
    if (m_searchError != message) {
        m_searchError = message;
        emit searchErrorChanged();
    }
    if (!message.isEmpty()) return;
    m_services.history().add(m_searchText, m_app);
    emit historyChanged();
    runSearch(false);
}

void Session::runSearch(bool keepSlice)
{
    if (m_namespace.isEmpty() || m_app.isEmpty()) {
        if (m_streams.isEmpty() && !isDiscovering()) start();
        return;
    }
    clearError();
    if (m_appliedSearch != m_searchText) {
        m_appliedSearch = m_searchText;
        emit appliedSearchChanged();
    }
    if (!keepSlice) setSelectedRow(-1);
    ++m_filterGeneration;   // a filter computed for the previous result is void
    setFiltering(false);
    // A new search drops a client-side histogram filter; a level promoted into
    // the query stays until the user clears it.
    if (m_levelServerSide) m_store.setFilter({ 0, 0, m_activeLevel });
    else resetLevelFilter();

    resolveConnection([this, keepSlice](const Connection&) {
        m_queryTimer.start();
        m_lastQueryMs = 0;
        m_loader->setStep(m_prefs->loadStep());
        // The same search again (refresh, pull to refresh, auto refresh): the
        // shown entries stay until the new ones come.
        const QString key = QStringList{ environmentId(), m_namespace, m_app, m_searchText,
                                         encodeTimeRange(m_range), levelName(m_activeLevel),
                                         m_levelServerSide ? QStringLiteral("s") : QString() }.join(QChar(0x1f));
        m_loader->start(currentSpec(), m_range, key == m_loadedSearchKey);
        m_loadedSearchKey = key;
        m_logs->reload(!keepSlice);
        markPatternsStale();
        refreshDerived();
    });
}

void Session::toggleFilter(const QString& field, const QString& value, bool exclude)
{
    setSearchText(toggleFilterInText(m_searchText, { field, value, false, exclude }));
    search();
}

void Session::removeChip(int index)
{
    setSearchText(removeQueryTerm(m_searchText, index));
    search();
}

void Session::clearSearch()
{
    setSearchText({});
    search();
}

void Session::applySuggestion(int index, bool exclude)
{
    const QVariantMap s = m_suggestions->get(index);
    if (s.isEmpty()) return;
    if (s.value("kind").toString() == u"field") {
        setSearchText(s.value("completedText").toString());
        return;
    }
    QStringList parts = splitQueryParts(m_searchText);
    const FieldFilter f{ s.value("field").toString(), s.value("value").toString(), false, exclude };
    if (parts.isEmpty()) parts << QString();
    parts.last() = f.toText();
    setSearchText(parts.join(QStringLiteral(" AND ")));
    search();
}

void Session::clearHistory()
{
    m_services.history().clear();
    emit historyChanged();
}

// ── time range ──────────────────────────────────────────────────────────────

void Session::applyRange(const TimeRange& range)
{
    m_range = range;
    m_services.selection().setTimeRange(range);
    if (!m_rangeError.isEmpty()) {
        m_rangeError.clear();
        emit rangeErrorChanged();
    }
    emit timeRangeChanged();
}

void Session::setPreset(const QString& key)
{
    applyRange(TimeRange::fromKey(key));
    runSearch(false);
}

void Session::setRange(const TimeRange& range)
{
    applyRange(range);
    runSearch(false);
}

bool Session::setAbsoluteRange(const QString& fromText, const QString& toText)
{
    const auto r = TimeRange::absolute(TimeRange::parseBound(fromText), TimeRange::parseBound(toText));
    if (!r) {
        m_rangeError = QCoreApplication::translate("Session", "Check the dates: both are required and the start must be before the end.");
        emit rangeErrorChanged();
        return false;
    }
    applyRange(*r);
    runSearch(false);
    return true;
}

QString Session::timeRangeKey() const { return encodeTimeRange(m_range); }
QString Session::timeRangeLabel() const { return presenters::timeRangeLabel(m_range); }
QString Session::timeRangeShortLabel() const { return presenters::timeRangeShortLabel(m_range); }

QString Session::absoluteFromText() const
{
    const TimeRange::Window w = m_range.resolve(m_services.clock()());
    return w.from.toLocalTime().toString(QStringLiteral("yyyy-MM-dd HH:mm"));
}

QString Session::absoluteToText() const
{
    const TimeRange::Window w = m_range.resolve(m_services.clock()());
    return w.to.toLocalTime().toString(QStringLiteral("yyyy-MM-dd HH:mm"));
}

// ── loading ─────────────────────────────────────────────────────────────────

void Session::onBatch()
{
    if (m_lastQueryMs == 0) m_lastQueryMs = int(m_queryTimer.elapsed());
    m_logs->reload(false);
    markPatternsStale();
    refreshDerived();
}

void Session::onLoadFinished()
{
    refreshDerived();
    emit loadingChanged();
    if (m_pendingAnchorMs > 0) {
        for (int row = 0; row < m_logs->rowCount(); ++row) {
            if (m_logs->entryAt(row)->timeMs() != m_pendingAnchorMs) continue;
            setSelectedRow(row);
            break;
        }
        m_pendingAnchorMs = 0;
    }
}

void Session::loadMore()
{
    if (isLoading()) return;
    // A level picked on the histogram is still a client-side view over a mix of
    // levels: "load more" means more entries *of that level*, so the level goes
    // into the query and the whole range is reloaded.
    if (m_activeLevel != Level::Unknown && !m_levelServerSide) {
        m_levelServerSide = true;
        m_store.setFilter({ 0, 0, m_activeLevel });
        m_histogramFilterLabel = levelName(m_activeLevel);
        emit histogramFilterChanged();
        runSearch(false);
        return;
    }
    // A time-bucket filter would hide everything older that comes next.
    if (m_activeLevel == Level::Unknown && m_store.filter().isActive()) resetLevelFilter();
    if (!hasMore()) return;
    m_loader->setStep(m_prefs->loadStep());
    m_loader->loadMore();
}

void Session::stopLoading()
{
    m_loader->stop();
    refreshDerived();
    emit loadingChanged();
}

void Session::retry()
{
    if (m_streams.isEmpty()) start();
    else runSearch(false);
}

void Session::narrowRange()
{
    setPreset(QStringLiteral("1h"));
}

void Session::setAutoRefreshSeconds(int seconds)
{
    seconds = std::max(0, seconds);
    if (m_autoRefreshSeconds == seconds) return;
    m_autoRefreshSeconds = seconds;
    if (seconds > 0) m_autoRefresh.start(seconds * 1000);
    else m_autoRefresh.stop();
    emit autoRefreshChanged();
}

void Session::setError(const ErrorInfo& error)
{
    if (m_error == error) return;
    m_error = error;
    emit errorChanged();
}

void Session::clearError()
{
    setError({});
}

void Session::fail(const RequestError& error)
{
    m_requestError = error;
    setError(ErrorInfo::from(error, environmentName(), m_services.environments().current().url.host()));
    // In the browser: CORS or no connection? Asked of the server; the answer
    // replaces the error if it is still the one shown.
    const quint64 failure = ++m_failureGeneration;
    m_services.refineBrowserError(error, m_services.environments().current().url, this, [this, failure](const RequestError& refined) {
        if (failure != m_failureGeneration || !m_error.isActive() || refined.kind == m_requestError.kind) return;
        m_requestError = refined;
        setError(ErrorInfo::from(refined, environmentName(), m_services.environments().current().url.host()));
    });
}

void Session::retranslate()
{
    if (m_error.isActive()) {
        m_error = ErrorInfo::from(m_requestError, environmentName(), m_services.environments().current().url.host());
        emit errorChanged();
    }
    if (!m_rangeError.isEmpty()) {
        m_rangeError = QCoreApplication::translate("Session", "Check the dates: both are required and the start must be before the end.");
        emit rangeErrorChanged();
    }
    if (!m_store.filter().messageTemplate.isEmpty()) {
        m_histogramFilterLabel = patternFilterLabel(m_store.filter());
        emit histogramFilterChanged();
    }
    refreshHistogram();
    refreshSavedQueries();
    emit timeRangeChanged();
}

// ── histogram ───────────────────────────────────────────────────────────────

void Session::setManualBucketMs(qint64 ms)
{
    ms = std::max<qint64>(0, ms);
    if (m_manualBucketMs == ms) return;
    m_manualBucketMs = ms;
    refreshHistogram();
}

QStringList Session::histogramAxis() const
{
    const QList<QVariantMap> rows = m_histogram->rows();
    if (rows.isEmpty()) return {};
    return presenters::histogramAxis(rows.first().value("startMs").toLongLong(),
                                     rows.last().value("startMs").toLongLong() + m_bucketMs, 5);
}

QString Session::timeZoneLabel() const
{
    return presenters::utcOffsetLabel(QDateTime::currentDateTime().offsetFromUtc());
}

QDate Session::boundDate(const QString& boundText) const
{
    return presenters::boundDate(boundText, QDate::currentDate());
}

QString Session::boundOnDay(const QString& boundText, QDate day, bool endOfPeriod) const
{
    return presenters::boundOnDay(boundText, day, endOfPeriod);
}

void Session::refreshHistogram()
{
    scheduleAnalysis();
}

void Session::applyBucketFilter(int bucketIndex, const QString& level, bool problemsOnly)
{
    if (bucketIndex < 0 || bucketIndex >= m_buckets.size()) return;
    const qint64 from = m_buckets.at(bucketIndex).startMs;
    m_activeLevel = levelFromName(level);
    m_levelServerSide = false;
    const auto fmt = [](qint64 ms) { return QDateTime::fromMSecsSinceEpoch(ms).toLocalTime().toString(QStringLiteral("HH:mm:ss")); };
    QString label = QStringLiteral("%1 → %2").arg(fmt(from), fmt(from + m_bucketMs));
    LogStore::Filter filter{ from, from + m_bucketMs, m_activeLevel };
    if (m_activeLevel != Level::Unknown) label += QStringLiteral(" · ") + level;
    else if (problemsOnly) {
        filter.problemsOnly = true;
        label += QStringLiteral(" · ERROR + WARN");
    }
    applyStoreFilter(filter, label);
}

void Session::applyLevelFilter(const QString& level)
{
    // Picking the active level again turns the filter off (no extra chip needed).
    const LogStore::Filter& current = m_store.filter();
    if (!m_levelServerSide && current.toMs == 0 && current.messageTemplate.isEmpty()
        && current.level != Level::Unknown && current.level == levelFromName(level)) {
        clearHistogramFilter();
        return;
    }
    m_activeLevel = levelFromName(level);
    m_levelServerSide = false;
    applyStoreFilter({ 0, 0, m_activeLevel }, level);
}

void Session::applyStoreFilter(const LogStore::Filter& filter, const QString& label)
{
    // Filtering (template matching especially) runs off the UI thread; the
    // list keeps showing the previous view until the new one is ready.
    const LogEntries all = m_store.all();
    const quint64 revision = m_store.revision();
    const quint64 generation = ++m_filterGeneration;
    setFiltering(true);
    m_services.parser().run(this, [this, all, revision, generation, filter, label]() -> ParseExecutor::Apply {
        LogEntries visible = LogStore::filterEntries(all, filter);
        return [this, revision, generation, filter, label, visible = std::move(visible)]() mutable {
            if (generation != m_filterGeneration) return;            // superseded
            if (revision != m_store.revision()) {                    // entries arrived meanwhile
                applyStoreFilter(filter, label);
                return;
            }
            m_store.setFilter(filter, std::move(visible));
            m_histogramFilterLabel = label;
            setFiltering(false);
            m_logs->reload(true);
            setSelectedRow(-1);
            markPatternsStale();
            scheduleAnalysis();
            emit histogramFilterChanged();
        };
    });
}

void Session::setFiltering(bool on)
{
    if (m_filtering == on) return;
    m_filtering = on;
    emit analyzingChanged();
}

void Session::resetLevelFilter()
{
    const bool changed = m_store.filter().isActive() || m_activeLevel != Level::Unknown || m_levelServerSide;
    m_store.clearFilter();
    m_activeLevel = Level::Unknown;
    m_levelServerSide = false;
    m_histogramFilterLabel.clear();
    if (changed) emit histogramFilterChanged();
}

void Session::clearHistogramFilter()
{
    const bool wasServerSide = m_levelServerSide;
    ++m_filterGeneration;   // drop a filter still being computed
    setFiltering(false);
    resetLevelFilter();
    m_logs->reload(true);
    setSelectedRow(-1);
    markPatternsStale();
    scheduleAnalysis();
    // The loaded set only holds that level: going back to all levels needs a query.
    if (wasServerSide) runSearch(false);
}

// ── facets / patterns / chips ───────────────────────────────────────────────

void Session::refreshDerived()
{
    scheduleAnalysis();
}

void Session::markPatternsStale()
{
    m_patternsStale = true;
    ++m_patternsEpoch;
}

void Session::scheduleAnalysis()
{
    // One analysis at a time; changes meanwhile are picked up by one more run.
    if (m_analysisRunning) {
        m_analysisPending = true;
        return;
    }
    const qint64 span = m_loader->window().seconds() > 0 ? m_loader->window().seconds()
                                                         : m_range.resolve(m_services.clock()()).seconds();
    const qint64 bucketMs = m_manualBucketMs > 0 ? m_manualBucketMs : autoBucketMs(span);
    const quint64 revision = m_store.revision();
    const bool wantCounts = revision != m_analyzedRevision || bucketMs != m_bucketMs || m_buckets.isEmpty() != m_store.all().isEmpty();
    // Kept current even while the list is shown: the "Patterns N" switch counts them.
    const bool wantPatterns = m_patternsStale;
    if (!wantCounts && !wantPatterns) return;

    m_analysisRunning = true;
    m_analysisPending = false;
    emit analyzingChanged();

    const LogEntries all = m_store.all();
    const LogEntries visible = m_store.visible();
    const LogStore::Filter filter = m_store.filter();
    const quint64 patternsEpoch = m_patternsEpoch;
    const QString patternSort = m_patternSort;
    const bool keepSingles = m_showSinglePatterns;
    m_services.parser().run(this, [=, this]() -> ParseExecutor::Apply {
        QList<HistogramBucket> buckets;
        FieldValueCounts facets;
        if (wantCounts) {
            buckets = aggregateHistogram(all, bucketMs);
            facets = computeFacets(all);
        }
        QList<QVariantMap> patternRows;
        int singles = 0;
        if (wantPatterns) {
            // Grouping is for problems: WARN and every kind of error only.
            // Showing the entries of one pattern must not shrink the patterns to it:
            // they are built from the view without the pattern filter.
            LogStore::Filter withoutTemplate = filter;
            withoutTemplate.messageTemplate.clear();
            withoutTemplate.excludeTemplate = false;
            withoutTemplate.templateProblemsOnly = false;
            const LogEntries source = filter.messageTemplate.isEmpty() ? visible
                                    : withoutTemplate.isActive()       ? LogStore::filterEntries(all, withoutTemplate)
                                                                       : all;
            LogEntries problems;
            for (const LogEntry& e : source)
                if (e.level == Level::Warn || e.level == Level::Error) problems.append(e);
            QList<MessagePattern> patterns = extractPatterns(problems);
            // One-off messages are noise in this view: they are counted, not listed.
            const auto single = [](const MessagePattern& p) { return p.count < 2; };
            if (!keepSingles) {
                singles = int(std::count_if(patterns.cbegin(), patterns.cend(), single));
                patterns.removeIf(single);
            }
            presenters::sortPatterns(patterns, patternSort);
            patternRows = presenters::patternRows(patterns);
        }
        QList<QVariantMap> histogramRows = wantCounts ? presenters::histogramRows(buckets, bucketMs) : QList<QVariantMap>();
        return [=, this, buckets = std::move(buckets), facets = std::move(facets),
                histogramRows = std::move(histogramRows), patternRows = std::move(patternRows)]() {
            m_analysisRunning = false;
            if (wantCounts) {
                m_analyzedRevision = revision;
                m_bucketMs = bucketMs;
                m_buckets = buckets;
                m_histogramMax = 0;
                // As in 2.8: the chart shows WARN and ERROR, scaled to them.
                for (const HistogramBucket& b : m_buckets) m_histogramMax = std::max(m_histogramMax, b.counts[0] + b.counts[1]);
                m_levelTotals = presenters::levelTotals(m_buckets);
                m_histogram->setRows(histogramRows);
                emit histogramChanged();
                m_facetCounts = facets;
                refreshFacets();
            }
            if (wantPatterns && patternsEpoch == m_patternsEpoch) {
                m_patterns->setRows(patternRows);
                m_hiddenSinglePatterns = singles;
                m_patternsStale = false;
                emit patternsChanged();
            }
            if (m_analysisPending || m_patternsStale || m_analyzedRevision != m_store.revision()) {
                m_analysisPending = false;
                scheduleAnalysis();
            }
            if (!m_analysisRunning) emit analyzingChanged();
        };
    });
}

void Session::refreshFacets()
{
    // Rows only, from the counts the background analysis produced.
    m_facets->setRows(presenters::facetRows(m_facetCounts, m_facetFilter, m_expandedFacets,
                                            Query::parse(m_searchText).filters()));
    m_suggestions->setRows(presenters::suggestionRows(suggest(m_searchText, m_facetCounts)));
    emit facetsChanged();
}

void Session::setFacetFilterText(const QString& text)
{
    if (m_facetFilter == text) return;
    m_facetFilter = text;
    refreshFacets();
}

void Session::toggleFacetExpanded(const QString& field)
{
    if (!m_expandedFacets.remove(field)) m_expandedFacets.insert(field);
    refreshFacets();
}

void Session::setPatternsEnabled(bool on)
{
    if (m_patternsEnabled == on) return;
    m_patternsEnabled = on;
    refreshPatterns();
    emit patternsChanged();
}

void Session::refreshPatterns()
{
    scheduleAnalysis();
}

void Session::setShowSinglePatterns(bool on)
{
    if (m_showSinglePatterns == on) return;
    m_showSinglePatterns = on;
    markPatternsStale();
    refreshPatterns();
    emit patternsChanged();
}

void Session::setPatternSort(const QString& order)
{
    if (m_patternSort == order) return;
    m_patternSort = order;
    markPatternsStale();
    refreshPatterns();
    emit patternsChanged();
}

QString Session::jsonStyled(const QString& json, const QVariantMap& colors) const
{
    const auto c = [&](const char* kind) { return colors.value(QLatin1String(kind)).toString(); };
    return presenters::jsonStyled(json, { c("key"), c("string"), c("number"), c("boolean"), c("null"), c("punctuation") });
}

QString Session::highlight(const QString& text, const QStringList& terms, const QString& color) const
{
    return presenters::highlightStyled(text, terms, color);
}

void Session::showPattern(int index, bool exclude)
{
    const QVariantMap p = m_patterns->get(index);
    if (p.isEmpty()) return;
    LogStore::Filter f = m_store.filter();
    f.messageTemplate = p.value("templateText").toString();
    f.excludeTemplate = exclude;
    f.templateProblemsOnly = true;
    applyStoreFilter(f, patternFilterLabel(f));
}

QString Session::patternFilterLabel(const LogStore::Filter& f) const
{
    return (f.excludeTemplate ? QCoreApplication::translate("Session", "Without pattern: %1")
                              : QCoreApplication::translate("Session", "Pattern: %1")).arg(f.messageTemplate);
}

void Session::refreshChipsAndSuggestions()
{
    m_chips->setRows(presenters::chipRows(m_searchText));
    m_suggestions->setRows(presenters::suggestionRows(suggest(m_searchText, m_facetCounts)));
}

// ── selection ───────────────────────────────────────────────────────────────

void Session::setSelectedRow(int row)
{
    if (row >= m_logs->rowCount()) row = -1;
    if (m_selectedRow == row) return;
    m_selectedRow = row;
    emit selectionChanged();
}

void Session::selectRow(int row) { setSelectedRow(row); }
void Session::clearSelection() { setSelectedRow(-1); }

void Session::selectNext()
{
    if (m_selectedRow + 1 < m_logs->rowCount()) setSelectedRow(m_selectedRow + 1);
}

void Session::selectPrevious()
{
    if (m_selectedRow > 0) setSelectedRow(m_selectedRow - 1);
}

EntryDetails Session::selectedEntry() const
{
    return detailsOf(m_logs, m_selectedRow);
}

EntryDetails Session::detailsOf(LogListModel* model, int row) const
{
    const LogEntry* e = model ? model->entryAt(row) : nullptr;
    if (!e) return {};
    EntryDetails d = EntryDetails::from(*e);
    d.dateTimeText = m_prefs->dateTimeText(e->timestamp);
    return d;
}

// ── environments, saved queries, recent ─────────────────────────────────────

void Session::refreshEnvironments()
{
    m_environments->setRows(presenters::environmentRows(m_services.environments().environments(), environmentId()));
}

void Session::refreshSavedQueries()
{
    m_saved->setRows(presenters::savedQueryRows(m_services.savedQueries().all(),
                                                m_services.environments().environments()));
}

void Session::refreshRecent()
{
    QList<QVariantMap> rows;
    const QJsonArray list = QJsonDocument::fromJson(m_services.settings().value(kRecentKey).toByteArray()).array();
    for (const QJsonValue& v : list) {
        const QJsonObject o = v.toObject();
        const auto env = m_services.environments().find(o.value("env").toString());
        if (!env) continue;
        rows << QVariantMap{ { "environmentId", env->id }, { "environmentName", env->name },
                             { "environmentColor", env->color }, { "namespaceName", o.value("ns").toString() },
                             { "app", o.value("app").toString() } };
    }
    m_recent->setRows(rows);
}

QString Session::suggestedQueryName() const
{
    const QString base = m_searchText.trimmed().isEmpty() ? m_app
                       : m_app.isEmpty() ? m_searchText.trimmed()
                                         : QStringLiteral("%1 · %2").arg(m_app, m_searchText.trimmed());
    // Not a name already taken: saving with the suggestion adds a query, it
    // does not silently overwrite one.
    QString name = base;
    for (int n = 2; !savedQueryIdByName(name).isEmpty(); ++n) name = QStringLiteral("%1 (%2)").arg(base).arg(n);
    return name;
}

void Session::saveCurrentQuery(const QString& name)
{
    SavedQuery q;
    q.name = name.trimmed().isEmpty() ? m_searchText : name.trimmed();
    q.environmentId = environmentId();
    q.namespaceName = m_namespace;
    q.app = m_app;
    q.searchText = m_searchText;
    q.range = m_range;
    m_services.savedQueries().add(q);
    refreshSavedQueries();
}

void Session::runSavedQuery(const QString& id)
{
    for (const SavedQuery& q : m_services.savedQueries().all()) {
        if (q.id != id) continue;
        setSearchText(q.searchText);
        applyRange(q.range);
        if (q.environmentId != environmentId()) {
            switchEnvironment(q.environmentId);
            m_namespace = q.namespaceName;   // picked up by onDiscovered
            m_app = q.app;
            emit sourceChanged();
            return;
        }
        if (q.namespaceName == m_namespace && q.app == m_app) runSearch(false);
        else selectSource(q.namespaceName, q.app);
        return;
    }
}

void Session::renameSavedQuery(const QString& id, const QString& name)
{
    if (m_services.savedQueries().rename(id, name)) refreshSavedQueries();
}

void Session::removeSavedQuery(const QString& id)
{
    const QList<SavedQuery> all = m_services.savedQueries().all();
    for (int i = 0; i < all.size(); ++i) {
        if (all.at(i).id != id) continue;
        m_removedQuery = all.at(i);
        m_removedQueryIndex = i;
        break;
    }
    if (m_services.savedQueries().remove(id)) refreshSavedQueries();
}

void Session::restoreSavedQuery()
{
    if (m_removedQueryIndex < 0) return;
    m_services.savedQueries().insert(m_removedQueryIndex, m_removedQuery);
    m_removedQueryIndex = -1;
    refreshSavedQueries();
}

void Session::replaceSavedQuery(const QString& id)
{
    SavedQuery q;
    q.id = id;
    q.environmentId = environmentId();
    q.namespaceName = m_namespace;
    q.app = m_app;
    q.searchText = m_searchText;
    q.range = m_range;
    if (m_services.savedQueries().update(q)) refreshSavedQueries();
}

void Session::moveSavedQueryUp(const QString& id)
{
    const QList<SavedQuery> all = m_services.savedQueries().all();
    for (int i = 1; i < all.size(); ++i) {
        if (all.at(i).id != id) continue;
        if (m_services.savedQueries().move(id, i - 1)) refreshSavedQueries();
        return;
    }
}

QString Session::savedQueryIdByName(const QString& name) const
{
    const QString wanted = name.trimmed();
    for (const SavedQuery& q : m_services.savedQueries().all())
        if (q.name.compare(wanted, Qt::CaseInsensitive) == 0) return q.id;
    return {};
}

int Session::exportSavedQueries(const QUrl& file) const
{
    QFile out(file.isLocalFile() ? file.toLocalFile() : file.toString());
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) return -1;
    if (out.write(m_services.savedQueries().exportJson()) < 0) return -1;
    return int(m_services.savedQueries().all().size());
}

int Session::importSavedQueries(const QUrl& file, bool replace)
{
    QFile in(file.isLocalFile() ? file.toLocalFile() : file.toString());
    if (!in.open(QIODevice::ReadOnly)) return -1;
    const int added = m_services.savedQueries().importJson(in.readAll(), replace);
    if (added >= 0) refreshSavedQueries();
    return added;
}

QString Session::savedQueriesJson() const
{
    return QString::fromUtf8(m_services.savedQueries().exportJson());
}

int Session::importSavedQueriesJson(const QString& json, bool replace)
{
    const int added = m_services.savedQueries().importJson(json.toUtf8(), replace);
    if (added >= 0) refreshSavedQueries();
    return added;
}

QString Session::savedQueryLink(const QString& id) const
{
    for (const SavedQuery& q : m_services.savedQueries().all()) {
        if (q.id != id) continue;
        const auto env = m_services.environments().find(q.environmentId);
        SharedView v;
        v.environment = env ? env->name : QString();
        v.namespaceName = q.namespaceName;
        v.app = q.app;
        v.searchText = q.searchText;
        v.range = q.range;
        const QUrl url = m_shareBaseUrl.isEmpty() ? desktopShareUrl(v) : webShareUrl(QUrl(m_shareBaseUrl), v);
        return url.toString(QUrl::FullyEncoded);
    }
    return {};
}

// ── sharing ─────────────────────────────────────────────────────────────────

void Session::setShareBaseUrl(const QString& url)
{
    if (m_shareBaseUrl == url) return;
    m_shareBaseUrl = url;
    emit shareBaseUrlChanged();
}

QString Session::shareLink(bool fixedRange, bool includeSelection) const
{
    SharedView v;
    v.environment = environmentName();
    v.namespaceName = m_namespace;
    v.app = m_app;
    v.searchText = m_searchText;
    v.range = m_range;
    if (fixedRange && m_range.kind() != TimeRange::Kind::Absolute) {
        const TimeRange::Window w = m_loader->window().seconds() > 0 ? m_loader->window()
                                                                     : m_range.resolve(m_services.clock()());
        if (const auto abs = TimeRange::absolute(w.from, w.to)) v.range = *abs;
    }
    if (includeSelection) {
        if (const LogEntry* e = m_logs->entryAt(m_selectedRow)) v.anchorMs = e->timeMs();
    }
    const QUrl url = m_shareBaseUrl.isEmpty() ? desktopShareUrl(v) : webShareUrl(QUrl(m_shareBaseUrl), v);
    return url.toString(QUrl::FullyEncoded);
}

bool Session::openLink(const QString& url)
{
    const auto view = parseShareUrl(QUrl(url));
    if (!view) return false;
    const auto env = m_services.environments().findByName(view->environment);
    if (!env) {
        emit linkEnvironmentMissing(view->environment);
        return false;
    }
    m_openedFromLink = true;
    emit openedFromLinkChanged();
    m_pendingAnchorMs = view->anchorMs;
    setSearchText(view->searchText);
    applyRange(view->range);
    if (env->id != environmentId() || m_streams.isEmpty()) {
        if (env->id != environmentId()) switchEnvironment(env->id);
        else start();
        m_namespace = view->namespaceName;   // picked up by onDiscovered
        m_app = view->app;
        emit sourceChanged();
        return true;
    }
    if (view->namespaceName == m_namespace && view->app == m_app) runSearch(false);
    else selectSource(view->namespaceName, view->app);
    return true;
}

void Session::dismissLinkBanner()
{
    if (!m_openedFromLink) return;
    m_openedFromLink = false;
    emit openedFromLinkChanged();
}

QString Session::corsHint() const
{
    const QUrl base(m_shareBaseUrl);
    return corsHintForDevOps(base.isValid() && !base.isEmpty() ? base.adjusted(QUrl::RemovePath | QUrl::RemoveFragment | QUrl::RemoveQuery).toString() : QString());
}

} // namespace lv
