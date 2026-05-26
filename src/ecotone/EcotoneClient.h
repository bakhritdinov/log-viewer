#pragma once

#include <QObject>
#include <QDateTime>
#include <QList>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class FifoChannels;

// Q_GADGET so QML can read fields off a DlqEntry instance that arrives
// through a JS-bound signal (e.g. ReplayByContractDialog's preview list).
// Without this, modelData.failedAt etc. resolve to undefined in QML.
struct DlqEntry {
    Q_GADGET
    Q_PROPERTY(QString   messageId       MEMBER messageId)
    Q_PROPERTY(QDateTime failedAt        MEMBER failedAt)
    Q_PROPERTY(QString   payload         MEMBER payload)
    Q_PROPERTY(QString   headers         MEMBER headers)
    Q_PROPERTY(QString   channel         MEMBER channel)
    Q_PROPERTY(QString   contractId      MEMBER contractId)
    Q_PROPERTY(QString   replayStatus    MEMBER replayStatus)
    Q_PROPERTY(int       replayRequestId MEMBER replayRequestId)

public:
    QString   messageId;
    QDateTime failedAt;
    QString   payload;
    QString   headers;
    QString   channel;          // polledChannelName from headers
    QString   contractId;       // contract_id from headers (may be empty)
    QString   replayStatus;     // latest status from ecotone_replay_requests, "" if never queued
    int       replayRequestId = 0;  // latest request id, 0 if never queued
};

Q_DECLARE_METATYPE(DlqEntry)
Q_DECLARE_METATYPE(QList<DlqEntry>)

class EcotoneClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(bool loading READ isLoading NOTIFY loadingChanged)

public:
    explicit EcotoneClient(QObject* parent = nullptr);
    ~EcotoneClient() override;

    bool isConnected() const { return m_connected; }
    bool isLoading() const { return m_loading; }

    // Inject the FIFO channel registry. Must be called before any replay*().
    void setFifoChannels(FifoChannels* f) { m_fifoChannels = f; }

    Q_INVOKABLE void connectDb(const QString& host, int port, const QString& database,
                               const QString& user, const QString& password);
    Q_INVOKABLE void testConnection(const QString& host, int port, const QString& database,
                                    const QString& user, const QString& password);

    // Fetches a page of rows ordered by channel ASC, failed_at ASC so the
    // UI can render section headers per channel.
    //   channelFilter — exact polledChannelName, "" means all channels
    //   searchText    — substring matched (ILIKE) against message_id, payload,
    //                   headers and contract_id; "" means no search
    Q_INVOKABLE void fetchErrors(int limit, int offset,
                                 const QString& channelFilter,
                                 const QString& searchText);

    // Returns distinct polledChannelName values present in the DLQ table.
    // Used to populate the channel-filter dropdown.
    Q_INVOKABLE void fetchChannels();

    // Aggregate replay-request counts across the whole ecotone_replay_requests
    // table. Result arrives via replayStatusSummaryReceived.
    Q_INVOKABLE void fetchReplayStatusSummary();

    // Single-message replay — only for non-FIFO channels.
    Q_INVOKABLE void replayOne(const QString& messageId);

    // Preview which messages would be replayed for a FIFO group. groupId
    // identifies the group; searchValue is the value matched against the
    // group's searchField (e.g. contract_id). Filters to the group's channel
    // list, sorts by failed_at ASC. Result arrives via fifoGroupPreviewReceived.
    Q_INVOKABLE void previewFifoGroup(const QString& groupId,
                                      const QString& searchValue);

    // Queue a FIFO-group replay. Pre-fetches every message_id matching the
    // group's searchField=searchValue across the group's channels, ordered
    // by failed_at ASC, then INSERTs them in one transaction into
    // ecotone_replay_requests; FIFO is captured by the BIGSERIAL id. Also
    // applies the group's channel reroutes (main → *_errors) in the same
    // transaction so the worker doesn't need any FIFO/routing knowledge.
    Q_INVOKABLE void replayFifoGroup(const QString& groupId,
                                     const QString& searchValue);

signals:
    // Real connection lifecycle — emitted only by connectDb. connectionEstablished
    // signals "creds verified AND cached, m_connected == true".
    void connectionEstablished();
    void connectionFailed(const QString& reason);

    // Separate signal for the Settings dialog's Test Connection button so it
    // doesn't trigger the main window's auto-fetch path.
    void testConnectionResult(bool ok, const QString& reason);

    void errorsReceived(const QList<DlqEntry>& entries, int total);
    void channelsReceived(const QStringList& channels);
    // groupId + the searchValue that produced these rows so a polling dialog
    // can ignore stale responses if the user switched tabs / inputs.
    void fifoGroupPreviewReceived(const QString& groupId,
                                  const QString& searchValue,
                                  const QList<DlqEntry>& entries);
    // counts: { "pending": N, "processing": N, "done": N, "failed": N }
    void replayStatusSummaryReceived(const QVariantMap& counts);
    void errorOccurred(const QString& message);

    // Successful queue: firstRequestId is the lowest id INSERTed; messageCount
    // is the number of rows added (1 for replayOne, N for replayByContract).
    void replayQueued(int firstRequestId, int messageCount);
    // SQL error or empty result for replayByContract.
    void replayFailed(const QString& reason);

    void connectedChanged();
    void loadingChanged();

private:
    void setConnected(bool c);
    void setLoading(bool l);

    QString m_host;
    int     m_port = 5432;
    QString m_database;
    QString m_user;
    QString m_password;

    bool m_connected = false;
    bool m_loading = false;

    FifoChannels* m_fifoChannels = nullptr;
};
