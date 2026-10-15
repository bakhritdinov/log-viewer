#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QQmlEngine>
#include <QSet>
#include <QTimer>
#include <QtQml/qqmlregistration.h>
#include <memory>

#include "app/AppServices.h"
#include "app/EntryDetails.h"
#include "app/ErrorInfo.h"
#include "app/LogListModel.h"
#include "app/MapListModel.h"
#include "core/data/LabelDiscovery.h"
#include "core/features/Analysis.h"
#include "core/features/ChainedLoader.h"
#include "core/features/ShareLink.h"

namespace lv {

class FocusSession;
class LiveSession;

// The state of the log search shared by every design: environment, source
// (namespace/app), time range, search text, loaded entries and everything
// derived from them. QML only renders it and calls its invokables.
class Session : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Environment
    Q_PROPERTY(lv::MapListModel* environments READ environments CONSTANT)
    Q_PROPERTY(QString environmentId READ environmentId NOTIFY environmentChanged)
    Q_PROPERTY(QString environmentName READ environmentName NOTIFY environmentChanged)
    Q_PROPERTY(QString environmentColor READ environmentColor NOTIFY environmentChanged)
    Q_PROPERTY(bool secretsSecure READ secretsSecure CONSTANT)
    // Source
    Q_PROPERTY(bool discovering READ isDiscovering NOTIFY discoveringChanged)
    Q_PROPERTY(QStringList namespaces READ namespaces NOTIFY streamsChanged)
    Q_PROPERTY(QString namespaceName READ namespaceName NOTIFY sourceChanged)
    Q_PROPERTY(QString app READ app NOTIFY sourceChanged)
    Q_PROPERTY(QStringList apps READ apps NOTIFY sourceChanged)
    Q_PROPERTY(QString namespaceLabel READ namespaceLabel NOTIFY streamsChanged)
    Q_PROPERTY(QString appLabel READ appLabel NOTIFY streamsChanged)
    Q_PROPERTY(lv::MapListModel* recentSources READ recentSources CONSTANT)
    // Search
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    Q_PROPERTY(lv::MapListModel* chips READ chips CONSTANT)
    Q_PROPERTY(lv::MapListModel* suggestions READ suggestions CONSTANT)
    Q_PROPERTY(QStringList searchTerms READ searchTerms NOTIFY searchTextChanged)
    Q_PROPERTY(QStringList history READ history NOTIFY historyChanged)
    Q_PROPERTY(QString appliedSearchText READ appliedSearchText NOTIFY appliedSearchChanged)   // the text of the last search run
    Q_PROPERTY(QString searchError READ searchError NOTIFY searchErrorChanged)   // why search() refused the text
    // Time range
    Q_PROPERTY(QString timeRangeKey READ timeRangeKey NOTIFY timeRangeChanged)
    Q_PROPERTY(QString timeRangeLabel READ timeRangeLabel NOTIFY timeRangeChanged)
    Q_PROPERTY(QString timeRangeShortLabel READ timeRangeShortLabel NOTIFY timeRangeChanged)
    Q_PROPERTY(bool timeRangeAbsolute READ timeRangeAbsolute NOTIFY timeRangeChanged)
    Q_PROPERTY(QString absoluteFromText READ absoluteFromText NOTIFY timeRangeChanged)
    Q_PROPERTY(QString absoluteToText READ absoluteToText NOTIFY timeRangeChanged)
    Q_PROPERTY(QString rangeError READ rangeError NOTIFY rangeErrorChanged)
    Q_PROPERTY(QString timeZoneLabel READ timeZoneLabel NOTIFY timeRangeChanged)   // "UTC+5"
    // Loading
    Q_PROPERTY(bool loading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY loadingChanged)
    Q_PROPERTY(bool loadStopped READ loadStopped NOTIFY loadingChanged)   // stopped by the user, can continue
    Q_PROPERTY(int lastQueryMs READ lastQueryMs NOTIFY loadingChanged)
    Q_PROPERTY(lv::LogListModel* logs READ logs CONSTANT)
    Q_PROPERTY(int loadStep READ loadStep CONSTANT)   // entries per "load more"
    Q_PROPERTY(lv::ErrorInfo error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool needsSetup READ needsSetup NOTIFY errorChanged)
    Q_PROPERTY(bool hasError READ hasError NOTIFY errorChanged)
    // Histogram, fields, patterns or a filter are being computed in the background.
    Q_PROPERTY(bool analyzing READ isAnalyzing NOTIFY analyzingChanged)
    Q_PROPERTY(int autoRefreshSeconds READ autoRefreshSeconds WRITE setAutoRefreshSeconds NOTIFY autoRefreshChanged)
    // Histogram
    Q_PROPERTY(lv::MapListModel* histogram READ histogram CONSTANT)
    Q_PROPERTY(qint64 histogramBucketMs READ histogramBucketMs NOTIFY histogramChanged)
    Q_PROPERTY(qint64 manualBucketMs READ manualBucketMs WRITE setManualBucketMs NOTIFY histogramChanged)
    Q_PROPERTY(int histogramMax READ histogramMax NOTIFY histogramChanged)
    Q_PROPERTY(QStringList histogramAxis READ histogramAxis NOTIFY histogramChanged)   // 5 labels
    Q_PROPERTY(QVariantMap levelTotals READ levelTotals NOTIFY histogramChanged)
    Q_PROPERTY(bool histogramFilterActive READ histogramFilterActive NOTIFY histogramFilterChanged)
    // A time bucket or a pattern narrows the list (a level alone shows on the legend).
    Q_PROPERTY(bool histogramRangeOrPatternFilter READ histogramRangeOrPatternFilter NOTIFY histogramFilterChanged)
    Q_PROPERTY(QString histogramFilterLabel READ histogramFilterLabel NOTIFY histogramFilterChanged)
    Q_PROPERTY(qint64 histogramFilterFromMs READ histogramFilterFromMs NOTIFY histogramFilterChanged)   // 0: no interval
    Q_PROPERTY(QString activeLevel READ activeLevel NOTIFY histogramFilterChanged)
    Q_PROPERTY(bool levelServerSide READ levelServerSide NOTIFY histogramFilterChanged)
    // Fields, patterns
    Q_PROPERTY(lv::MapListModel* facets READ facets CONSTANT)
    Q_PROPERTY(QString facetFilterText READ facetFilterText WRITE setFacetFilterText NOTIFY facetsChanged)
    Q_PROPERTY(int fieldCount READ fieldCount NOTIFY facetsChanged)
    Q_PROPERTY(lv::MapListModel* patterns READ patterns CONSTANT)
    Q_PROPERTY(bool patternsEnabled READ patternsEnabled WRITE setPatternsEnabled NOTIFY patternsChanged)
    // Messages seen once are not listed as patterns, only counted.
    Q_PROPERTY(int hiddenSinglePatterns READ hiddenSinglePatterns NOTIFY patternsChanged)
    Q_PROPERTY(QString patternSort READ patternSort WRITE setPatternSort NOTIFY patternsChanged)
    Q_PROPERTY(bool showSinglePatterns READ showSinglePatterns WRITE setShowSinglePatterns NOTIFY patternsChanged)   // one-off messages listed too
    // Selection
    Q_PROPERTY(int selectedRow READ selectedRow NOTIFY selectionChanged)
    Q_PROPERTY(lv::EntryDetails selectedEntry READ selectedEntry NOTIFY selectionChanged)
    // Saved queries, sharing
    Q_PROPERTY(lv::MapListModel* savedQueries READ savedQueries CONSTANT)
    Q_PROPERTY(QString shareBaseUrl READ shareBaseUrl WRITE setShareBaseUrl NOTIFY shareBaseUrlChanged)
    Q_PROPERTY(bool openedFromLink READ openedFromLink NOTIFY openedFromLinkChanged)
    // Sub-sessions
    Q_PROPERTY(lv::FocusSession* focus READ focus CONSTANT)
    Q_PROPERTY(lv::LiveSession* live READ live CONSTANT)

public:
    explicit Session(AppServices& services, QObject* parent = nullptr);
    ~Session() override;

    // QML singleton: the instance registered by the platform layer.
    static void setInstance(Session* session);
    static Session* instance();
    static Session* create(QQmlEngine*, QJSEngine*);

    // Loads the current environment (discovery, then the first search).
    Q_INVOKABLE void start();

    // Environment / source
    Q_INVOKABLE void switchEnvironment(const QString& id);
    Q_INVOKABLE void rediscover();
    Q_INVOKABLE QStringList appsOf(const QString& namespaceName) const;
    Q_INVOKABLE void selectSource(const QString& namespaceName, const QString& app);
    Q_INVOKABLE void selectNamespace(const QString& namespaceName);   // first app of it
    Q_INVOKABLE void selectRecentSource(int index);
    // Rows for the source picker, see presenters::sourceMatches.
    Q_INVOKABLE QVariantList sourceMatches(const QString& query) const;
    // Environments were edited (settings): reload list, rediscover if needed.
    Q_INVOKABLE void environmentsEdited(const QString& changedId = {});

    // Search
    void setSearchText(const QString& text);
    Q_INVOKABLE void search();                       // new search with the current state
    Q_INVOKABLE void toggleFilter(const QString& field, const QString& value, bool exclude = false);
    Q_INVOKABLE void removeChip(int index);
    Q_INVOKABLE void clearSearch();
    Q_INVOKABLE void applySuggestion(int index, bool exclude = false);
    Q_INVOKABLE void clearHistory();

    // Time range
    Q_INVOKABLE void setPreset(const QString& key);
    Q_INVOKABLE bool setAbsoluteRange(const QString& fromText, const QString& toText);
    // Calendar helpers for "yyyy-MM-dd HH:mm" bounds (see presenters).
    Q_INVOKABLE QDate boundDate(const QString& boundText) const;
    Q_INVOKABLE QString boundOnDay(const QString& boundText, QDate day, bool endOfPeriod) const;
    void setRange(const TimeRange& range);   // C++: apply and search

    // Loading
    Q_INVOKABLE void loadMore();
    Q_INVOKABLE void stopLoading();
    Q_INVOKABLE void retry();
    Q_INVOKABLE void narrowRange();                  // error action: back to "last 1 hour"
    void setAutoRefreshSeconds(int seconds);

    // Histogram filter (client-side narrowing; level can be promoted by loadMore)
    void setManualBucketMs(qint64 ms);
    Q_INVOKABLE void applyBucketFilter(int bucketIndex, const QString& level = {});
    Q_INVOKABLE void applyLevelFilter(const QString& level);
    Q_INVOKABLE void clearHistogramFilter();

    // Fields
    void setFacetFilterText(const QString& text);
    Q_INVOKABLE void toggleFacetExpanded(const QString& field);
    void setPatternsEnabled(bool on);
    // Narrows the list to entries of the pattern (or hides them with exclude).
    Q_INVOKABLE void showPattern(int index, bool exclude = false);
    // "count" | "first" | "level"
    void setPatternSort(const QString& order);
    QString patternSort() const { return m_patternSort; }

    // `text` as StyledText with `terms` (usually searchTerms) emphasised in
    // `color`. Terms are a parameter so QML bindings track them.
    Q_INVOKABLE QString highlight(const QString& text, const QStringList& terms, const QString& color) const;
    // Indented JSON as coloured rich text (see presenters::jsonStyled). `colors`
    // maps key, string, number, boolean, null and punctuation to colour names.
    Q_INVOKABLE QString jsonStyled(const QString& json, const QVariantMap& colors) const;

    // Selection
    Q_INVOKABLE void selectRow(int row);
    Q_INVOKABLE void selectNext();
    Q_INVOKABLE void selectPrevious();
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE lv::EntryDetails detailsOf(lv::LogListModel* model, int row) const;

    // Saved queries
    // A default name for saving the current search ("app · search").
    Q_INVOKABLE QString suggestedQueryName() const;   // never a name already saved
    Q_INVOKABLE QString historySource(const QString& text) const;   // the app a recent search ran on
    Q_INVOKABLE void saveCurrentQuery(const QString& name);
    Q_INVOKABLE void runSavedQuery(const QString& id);
    Q_INVOKABLE void renameSavedQuery(const QString& id, const QString& name);
    Q_INVOKABLE void removeSavedQuery(const QString& id);
    Q_INVOKABLE void restoreSavedQuery();                       // undo the last removal
    Q_INVOKABLE void replaceSavedQuery(const QString& id);      // with the current search
    Q_INVOKABLE void moveSavedQueryUp(const QString& id);
    Q_INVOKABLE QString savedQueryIdByName(const QString& name) const;   // "" when none
    Q_INVOKABLE QString savedQueryLink(const QString& id) const;
    // Saved queries to / from a file; the number written or added, -1 on failure.
    Q_INVOKABLE int exportSavedQueries(const QUrl& file) const;
    Q_INVOKABLE int importSavedQueries(const QUrl& file, bool replace);

    // Sharing
    void setShareBaseUrl(const QString& url);
    // `fixedRange` freezes relative ranges at their current bounds.
    Q_INVOKABLE QString shareLink(bool fixedRange = true, bool includeSelection = true) const;
    Q_INVOKABLE bool openLink(const QString& url);
    Q_INVOKABLE void dismissLinkBanner();
    Q_INVOKABLE QString corsHint() const;

    // The UI language changed: rebuilds every text Session made in C++
    // (errors, range labels, model rows). QML bindings retranslate themselves.
    void retranslate();

    // ── getters ──
    MapListModel* environments() const { return m_environments; }
    QString environmentId() const;
    QString environmentName() const;
    QString environmentColor() const;
    bool secretsSecure() const;
    bool isDiscovering() const { return m_discovery->isRunning(); }
    QStringList namespaces() const { return m_streams.keys(); }
    QString namespaceName() const { return m_namespace; }
    QString app() const { return m_app; }
    QStringList apps() const { return appsOf(m_namespace); }
    QString namespaceLabel() const { return m_nsLabel; }
    QString appLabel() const { return m_appLabel; }
    MapListModel* recentSources() const { return m_recent; }
    QString searchText() const { return m_searchText; }
    MapListModel* chips() const { return m_chips; }
    MapListModel* suggestions() const { return m_suggestions; }
    QString appliedSearchText() const { return m_appliedSearch; }
    QString searchError() const { return m_searchError; }
    QStringList searchTerms() const;
    QStringList history() const;
    QString timeRangeKey() const;
    QString timeRangeLabel() const;
    QString timeRangeShortLabel() const;
    bool timeRangeAbsolute() const { return m_range.kind() == TimeRange::Kind::Absolute; }
    QString absoluteFromText() const;
    QString absoluteToText() const;
    QString rangeError() const { return m_rangeError; }
    bool isLoading() const { return m_loader->isLoading(); }
    bool hasMore() const { return m_loader->hasMore(); }
    bool loadStopped() const { return m_loader->wasStopped(); }
    int lastQueryMs() const { return m_lastQueryMs; }
    int loadStep() const { return ChainedLoader::kStep; }
    LogListModel* logs() const { return m_logs; }
    ErrorInfo error() const { return m_error; }
    bool hasError() const { return m_error.isActive(); }
    bool isAnalyzing() const { return m_analysisRunning || m_filtering; }
    int hiddenSinglePatterns() const { return m_hiddenSinglePatterns; }
    bool needsSetup() const { return m_error.kind == ErrorInfo::Kind::NotConfigured; }
    int autoRefreshSeconds() const { return m_autoRefreshSeconds; }
    MapListModel* histogram() const { return m_histogram; }
    qint64 histogramBucketMs() const { return m_bucketMs; }
    qint64 manualBucketMs() const { return m_manualBucketMs; }
    int histogramMax() const { return m_histogramMax; }
    QStringList histogramAxis() const;
    QString timeZoneLabel() const;
    QVariantMap levelTotals() const { return m_levelTotals; }
    bool histogramFilterActive() const { return m_store.filter().isActive(); }
    bool histogramRangeOrPatternFilter() const { return m_store.filter().toMs > 0 || !m_store.filter().messageTemplate.isEmpty(); }
    QString histogramFilterLabel() const { return m_histogramFilterLabel; }
    qint64 histogramFilterFromMs() const { return m_store.filter().toMs > 0 ? m_store.filter().fromMs : 0; }
    QString activeLevel() const { return levelName(m_activeLevel); }
    bool levelServerSide() const { return m_levelServerSide; }
    MapListModel* facets() const { return m_facets; }
    QString facetFilterText() const { return m_facetFilter; }
    int fieldCount() const { return int(m_facetCounts.size()); }
    MapListModel* patterns() const { return m_patterns; }
    bool patternsEnabled() const { return m_patternsEnabled; }
    bool showSinglePatterns() const { return m_showSinglePatterns; }
    void setShowSinglePatterns(bool on);
    int selectedRow() const { return m_selectedRow; }
    EntryDetails selectedEntry() const;
    MapListModel* savedQueries() const { return m_saved; }
    QString shareBaseUrl() const { return m_shareBaseUrl; }
    bool openedFromLink() const { return m_openedFromLink; }
    FocusSession* focus() const { return m_focus; }
    LiveSession* live() const { return m_live; }

    // For FocusSession / LiveSession.
    AppServices& services() const { return m_services; }
    SearchSpec currentSpec() const;
    void resolveConnection(std::function<void(const Connection&)> done);

signals:
    void environmentChanged();
    void discoveringChanged();
    void streamsChanged();
    void sourceChanged();
    void searchTextChanged();
    void appliedSearchChanged();
    void searchErrorChanged();
    void historyChanged();
    void timeRangeChanged();
    void rangeErrorChanged();
    void loadingChanged();
    void errorChanged();
    void autoRefreshChanged();
    void histogramChanged();
    void histogramFilterChanged();
    void facetsChanged();
    void patternsChanged();
    void analyzingChanged();
    void selectionChanged();
    void shareBaseUrlChanged();
    void openedFromLinkChanged();
    // A share link named an environment that does not exist here.
    void linkEnvironmentMissing(const QString& name);

private:
    void runSearch(bool keepSlice);
    void onDiscovered(const DiscoveryResult& result);
    void onBatch();
    void onLoadFinished();
    void setError(const ErrorInfo& error);
    void fail(const RequestError& error);
    QString patternFilterLabel(const LogStore::Filter& filter) const;
    void applyStoreFilter(const LogStore::Filter& filter, const QString& label);
    void setFiltering(bool on);
    void scheduleAnalysis();
    void markPatternsStale();
    void clearError();
    void rememberSource();
    void refreshDerived();          // histogram, facets, patterns after the store changed
    void refreshHistogram();
    void refreshFacets();
    void refreshPatterns();
    void refreshChipsAndSuggestions();
    void refreshEnvironments();
    void refreshSavedQueries();
    void refreshRecent();
    void setSelectedRow(int row);
    void applyRange(const TimeRange& range);
    void resetLevelFilter();

    AppServices& m_services;
    std::unique_ptr<LabelDiscovery> m_discovery;
    LogStore m_store;
    std::unique_ptr<ChainedLoader> m_loader;
    QTimer m_autoRefresh;
    QElapsedTimer m_queryTimer;

    // Connection of the current environment (secrets resolved), cached.
    std::optional<Connection> m_connection;
    quint64 m_connectionGeneration = 0;

    StreamMap m_streams;
    QString m_nsLabel;
    QString m_appLabel;
    QString m_namespace;
    QString m_app;
    QString m_searchText;
    TimeRange m_range;
    QString m_rangeError;
    ErrorInfo m_error;
    RequestError m_requestError;   // source of m_error, to rebuild its texts
    int m_lastQueryMs = 0;
    int m_autoRefreshSeconds = 0;

    qint64 m_bucketMs = 60000;
    qint64 m_manualBucketMs = 0;
    int m_histogramMax = 0;
    QVariantMap m_levelTotals;
    QList<HistogramBucket> m_buckets;
    Level m_activeLevel = Level::Unknown;
    bool m_levelServerSide = false;
    QString m_histogramFilterLabel;

    FieldValueCounts m_facetCounts;
    QString m_facetFilter;
    QSet<QString> m_expandedFacets;
    bool m_patternsEnabled = false;
    bool m_showSinglePatterns = false;
    bool m_patternsStale = true;
    QString m_patternSort = QStringLiteral("count");
    quint64 m_patternsEpoch = 0;
    int m_hiddenSinglePatterns = 0;
    bool m_analysisRunning = false;
    bool m_analysisPending = false;
    quint64 m_analyzedRevision = ~0ull;
    bool m_filtering = false;
    quint64 m_filterGeneration = 0;

    int m_selectedRow = -1;
    QString m_shareBaseUrl;
    bool m_openedFromLink = false;
    QString m_appliedSearch;
    QString m_searchError;
    SavedQuery m_removedQuery;        // for restoreSavedQuery()
    int m_removedQueryIndex = -1;
    qint64 m_pendingAnchorMs = 0;

    MapListModel* m_environments;
    MapListModel* m_recent;
    MapListModel* m_chips;
    MapListModel* m_suggestions;
    MapListModel* m_histogram;
    MapListModel* m_facets;
    MapListModel* m_patterns;
    MapListModel* m_saved;
    LogListModel* m_logs;
    FocusSession* m_focus;
    LiveSession* m_live;
};

} // namespace lv
