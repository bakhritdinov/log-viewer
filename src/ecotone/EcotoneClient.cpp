#include "EcotoneClient.h"
#include "FifoChannels.h"

#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QtConcurrent/QtConcurrent>
#include <QDebug>
#include <QFutureWatcher>
#include <QHash>
#include <QStringList>
#include <QUuid>
#include <QVariant>

namespace {
QString uniqueConnectionName(const char* tag) {
    return QStringLiteral("ecotone-%1-%2")
        .arg(QString::fromLatin1(tag),
             QUuid::createUuid().toString(QUuid::WithoutBraces));
}

QString verifyCredentials(const QString& host, int port, const QString& database,
                          const QString& user, const QString& password) {
    const QString name = uniqueConnectionName("verify");
    QString error;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase("QPSQL", name);
        db.setHostName(host);
        db.setPort(port);
        db.setDatabaseName(database);
        db.setUserName(user);
        db.setPassword(password);
        if (!db.open()) {
            error = db.lastError().text();
        } else {
            QSqlQuery q(db);
            if (!q.exec("SELECT 1")) {
                error = q.lastError().text();
            }
            db.close();
        }
    }
    QSqlDatabase::removeDatabase(name);
    return error;
}

// Routing map for FIFO channels: the main queue's main_channel must be
// rewritten to its sibling _error queue before replay so the replayed
// message doesn't block the main queue again. Keep tiny — when new FIFO
// channels appear, add an entry here.
} // namespace

EcotoneClient::EcotoneClient(QObject* parent) : QObject(parent) {
    qRegisterMetaType<DlqEntry>("DlqEntry");
    qRegisterMetaType<QList<DlqEntry>>("QList<DlqEntry>");
}

EcotoneClient::~EcotoneClient() = default;

void EcotoneClient::setConnected(bool c) {
    if (m_connected == c) return;
    m_connected = c;
    emit connectedChanged();
}

void EcotoneClient::setLoading(bool l) {
    if (m_loading == l) return;
    m_loading = l;
    emit loadingChanged();
}

void EcotoneClient::connectDb(const QString& host, int port, const QString& database,
                              const QString& user, const QString& password) {
    const QString error = verifyCredentials(host, port, database, user, password);
    if (!error.isEmpty()) {
        setConnected(false);
        emit connectionFailed(error);
        return;
    }
    m_host     = host;
    m_port     = port;
    m_database = database;
    m_user     = user;
    m_password = password;
    setConnected(true);
    emit connectionEstablished();
}

void EcotoneClient::testConnection(const QString& host, int port, const QString& database,
                                   const QString& user, const QString& password) {
    const QString error = verifyCredentials(host, port, database, user, password);
    emit testConnectionResult(error.isEmpty(), error);
}

namespace {
struct ReplayResult {
    int     firstId = 0;
    int     count   = 0;
    QString error;
};

// Build an UPDATE statement that sets headers.polledChannelName to the
// reroute target for any FifoChannel that has a non-empty rerouteTo.
// Channels without a reroute (e.g. the *_errors sinks themselves) are skipped.
// Empty channels list ⇒ returns an SQL that updates 0 rows (no FIFO declared).
QString buildRerouteUpdate(const QString& whereExtra,
                           const QList<FifoChannel>& channels) {
    QStringList whens;
    QStringList fromKeys;
    for (const auto& c : channels) {
        if (c.rerouteTo.isEmpty()) continue;
        whens << QStringLiteral(
            "WHEN headers::jsonb->>'polledChannelName' = '%1' THEN to_jsonb('%2'::text)")
            .arg(c.name, c.rerouteTo);
        fromKeys << QStringLiteral("'%1'").arg(c.name);
    }
    if (whens.isEmpty()) {
        return QStringLiteral(
            "UPDATE public.ecotone_error_messages "
            "SET headers = headers WHERE %1 AND FALSE").arg(whereExtra);
    }
    // headers column is `text`, so the jsonb_set() result has to be cast back
    // to text before assignment (PostgreSQL doesn't implicit-cast jsonb→text).
    return QStringLiteral(
        "UPDATE public.ecotone_error_messages "
        "SET headers = jsonb_set(headers::jsonb, '{polledChannelName}', "
        "    CASE %1 END)::text "
        "WHERE %2 "
        "  AND headers::jsonb->>'polledChannelName' IN (%3)")
        .arg(whens.join(' '), whereExtra, fromKeys.join(','));
}
} // namespace

void EcotoneClient::replayOne(const QString& messageId) {
    if (!m_connected) {
        emit replayFailed(tr("Not connected to Ecotone database"));
        return;
    }
    setLoading(true);

    const QString host = m_host;
    const int     port = m_port;
    const QString db   = m_database;
    const QString user = m_user;
    const QString pass = m_password;
    // Snapshot every FIFO channel across all groups — replayOne doesn't know
    // which group the message belongs to, so we use the union for reroute
    // matching. Worker lambda only reads this; no concurrent mutation.
    QList<FifoChannel> fifoChannels;
    if (m_fifoChannels) {
        for (const auto& g : m_fifoChannels->groupList())
            fifoChannels << g.channels;
    }

    auto* watcher = new QFutureWatcher<ReplayResult>(this);
    connect(watcher, &QFutureWatcher<ReplayResult>::finished, this,
            [this, watcher]() {
                const ReplayResult res = watcher->result();
                watcher->deleteLater();
                setLoading(false);
                if (!res.error.isEmpty()) { emit replayFailed(res.error); return; }
                emit replayQueued(res.firstId, res.count);
            });

    auto future = QtConcurrent::run([host, port, db, user, pass, messageId, fifoChannels]() -> ReplayResult {
        ReplayResult result;
        const QString connName = uniqueConnectionName("replay-one");
        qWarning() << ">>> replayOne start mid=" << messageId;
        {
            QSqlDatabase d = QSqlDatabase::addDatabase("QPSQL", connName);
            d.setHostName(host);
            d.setPort(port);
            d.setDatabaseName(db);
            d.setUserName(user);
            d.setPassword(pass);
            if (!d.open()) {
                result.error = d.lastError().text();
                qWarning() << ">>> replayOne open failed:" << result.error;
            } else if (!d.transaction()) {
                result.error = d.lastError().text();
                qWarning() << ">>> replayOne transaction failed:" << result.error;
            } else {
                QSqlQuery upd(d);
                const QString updSql = buildRerouteUpdate(
                    QStringLiteral("message_id = :mid"), fifoChannels);
                qWarning() << ">>> replayOne UPDATE SQL:" << updSql;
                upd.prepare(updSql);
                upd.bindValue(":mid", messageId);
                if (!upd.exec()) {
                    result.error = upd.lastError().text();
                    qWarning() << ">>> replayOne UPDATE failed:" << result.error;
                    d.rollback();
                } else {
                    QSqlQuery ins(d);
                    // First try to revive a previously failed request in
                    // place — keeps the original id (and thus its position in
                    // the worker's ORDER BY id ASC). If none, fall through to
                    // INSERT a brand-new row.
                    ins.prepare(
                        "WITH reset AS ( "
                        "    UPDATE public.ecotone_replay_requests "
                        "    SET status='pending', error_text=NULL, processed_at=NULL "
                        "    WHERE message_id = :mid AND status='failed' "
                        "    RETURNING id "
                        "), inserted AS ( "
                        "    INSERT INTO public.ecotone_replay_requests (message_id, failed_at) "
                        "    SELECT em.message_id, em.failed_at "
                        "    FROM public.ecotone_error_messages em "
                        "    WHERE em.message_id = :mid "
                        "      AND NOT EXISTS ( "
                        "          SELECT 1 FROM public.ecotone_replay_requests "
                        "          WHERE message_id = :mid "
                        "            AND status IN ('pending','processing','done','failed') "
                        "      ) "
                        "    RETURNING id "
                        ") "
                        "SELECT id FROM reset UNION ALL SELECT id FROM inserted");
                    ins.bindValue(":mid", messageId);
                    if (!ins.exec()) {
                        result.error = ins.lastError().text();
                        qWarning() << ">>> replayOne reset/insert exec failed:" << result.error;
                        d.rollback();
                    } else if (!ins.next()) {
                        result.error = QObject::tr("Already queued (pending or processing) — skipped");
                        qWarning() << ">>> replayOne already in-flight";
                        d.rollback();
                    } else {
                        result.firstId = ins.value(0).toInt();
                        result.count   = 1;
                        if (!d.commit()) {
                            result.error = d.lastError().text();
                            qWarning() << ">>> replayOne commit failed:" << result.error;
                        } else {
                            qWarning() << ">>> replayOne SUCCESS id=" << result.firstId;
                        }
                    }
                }
                d.close();
            }
        }
        QSqlDatabase::removeDatabase(connName);
        return result;
    });
    watcher->setFuture(future);
}

void EcotoneClient::replayFifoGroup(const QString& groupId,
                                    const QString& searchValue) {
    if (!m_connected) {
        emit replayFailed(tr("Not connected to Ecotone database"));
        return;
    }
    const FifoGroup* group = m_fifoChannels ? m_fifoChannels->findGroup(groupId) : nullptr;
    if (!group) {
        emit replayFailed(tr("Unknown FIFO group: %1").arg(groupId));
        return;
    }
    if (searchValue.trimmed().isEmpty()) {
        emit replayFailed(tr("Search value is empty"));
        return;
    }
    setLoading(true);

    const QString host  = m_host;
    const int     port  = m_port;
    const QString db    = m_database;
    const QString user  = m_user;
    const QString pass  = m_password;
    const QString searchField = group->searchField;
    // Snapshot the group's channels — used for both the WHERE channel filter
    // and the reroute UPDATE inside the same transaction.
    const QList<FifoChannel> groupChannels = group->channels;
    QStringList channelNames;
    for (const auto& c : groupChannels) channelNames << c.name;

    auto* watcher = new QFutureWatcher<ReplayResult>(this);
    connect(watcher, &QFutureWatcher<ReplayResult>::finished, this,
            [this, watcher]() {
                const ReplayResult res = watcher->result();
                watcher->deleteLater();
                setLoading(false);
                if (!res.error.isEmpty()) { emit replayFailed(res.error); return; }
                emit replayQueued(res.firstId, res.count);
            });

    auto future = QtConcurrent::run(
        [host, port, db, user, pass, groupId, searchValue, searchField, channelNames, groupChannels]() -> ReplayResult {
        ReplayResult result;
        const QString connName = uniqueConnectionName("replay-group");

        // Wrap all SQL work in an inner lambda so its locals (QSqlDatabase,
        // QSqlQuery objects) are guaranteed to go out of scope BEFORE we call
        // QSqlDatabase::removeDatabase below. Otherwise the QPSQL driver
        // warns "connection still in use, all queries will cease to work"
        // and silently aborts the transaction.
        const auto runSql = [&]() {
            QSqlDatabase d = QSqlDatabase::addDatabase("QPSQL", connName);
            d.setHostName(host);
            d.setPort(port);
            d.setDatabaseName(db);
            d.setUserName(user);
            d.setPassword(pass);
            qWarning() << ">>> replayFifoGroup start group=" << groupId
                       << "val=" << searchValue;
            if (!d.open()) {
                result.error = d.lastError().text();
                qWarning() << ">>> replayFifoGroup open failed:" << result.error;
                return;
            }

            QStringList quoted;
            for (const auto& n : channelNames) {
                quoted << QStringLiteral("'%1'").arg(QString(n).replace('\'', "''"));
            }
            const QString channelsIn = quoted.isEmpty() ? QStringLiteral("''")
                                                       : quoted.join(',');
            const QString escapedSearchField = QString(searchField).replace('\'', "''");

            QStringList messageIds;
            {
                QSqlQuery q(d);
                q.prepare(QStringLiteral(
                    "SELECT em.message_id FROM public.ecotone_error_messages em "
                    "WHERE em.headers::jsonb->>'%1' = :val "
                    "  AND em.headers::jsonb->>'polledChannelName' IN (%2) "
                    "  AND NOT EXISTS ( "
                    "       SELECT 1 FROM public.ecotone_replay_requests r "
                    "       WHERE r.message_id = em.message_id "
                    "         AND r.status IN ('pending','processing','done') "
                    "  ) "
                    "ORDER BY em.failed_at ASC, em.message_id ASC")
                    .arg(escapedSearchField, channelsIn));
                q.bindValue(":val", searchValue);
                if (!q.exec()) {
                    result.error = q.lastError().text();
                    qWarning() << ">>> replayFifoGroup pre-fetch failed:" << result.error;
                    return;
                }
                while (q.next()) messageIds << q.value(0).toString();
            }
            qWarning() << ">>> replayFifoGroup messageIds.count=" << messageIds.size();
            if (messageIds.isEmpty()) {
                result.error = QObject::tr("%1 = %2: nothing to queue (no messages or all already pending)")
                                  .arg(searchField, searchValue);
                return;
            }

            // QPSQL's QStringList → text[] binding has been flaky on Qt 6.11
            // when used inside INSERT … SELECT contexts. Inline-quote the
            // message_ids into a literal IN(…) list instead — same approach
            // as channelNames above.
            QStringList midQuoted;
            midQuoted.reserve(messageIds.size());
            for (const auto& m : messageIds) {
                midQuoted << QStringLiteral("'%1'").arg(QString(m).replace('\'', "''"));
            }
            const QString midsIn = midQuoted.join(',');

            if (!d.transaction()) {
                result.error = d.lastError().text();
                qWarning() << ">>> replayFifoGroup BEGIN failed:" << result.error;
                return;
            }

            {
                QSqlQuery upd(d);
                upd.prepare(buildRerouteUpdate(
                    QStringLiteral("message_id IN (%1)").arg(midsIn), groupChannels));
                if (!upd.exec()) {
                    result.error = upd.lastError().text();
                    qWarning() << ">>> replayFifoGroup reroute UPDATE failed:" << result.error;
                    d.rollback();
                    return;
                }
                qWarning() << ">>> replayFifoGroup reroute UPDATE rows=" << upd.numRowsAffected();
            }

            int firstId = 0;
            int totalCount = 0;

            {
                QSqlQuery resetQ(d);
                resetQ.prepare(QStringLiteral(
                    "UPDATE public.ecotone_replay_requests "
                    "SET status = 'pending', error_text = NULL, processed_at = NULL "
                    "WHERE message_id IN (%1) AND status = 'failed' "
                    "RETURNING id").arg(midsIn));
                if (!resetQ.exec()) {
                    result.error = resetQ.lastError().text();
                    qWarning() << ">>> replayFifoGroup reset UPDATE failed:" << result.error;
                    d.rollback();
                    return;
                }
                while (resetQ.next()) {
                    const int id = resetQ.value(0).toInt();
                    if (firstId == 0 || id < firstId) firstId = id;
                    ++totalCount;
                }
                qWarning() << ">>> replayFifoGroup reset count=" << totalCount;
            }

            {
                QSqlQuery insQ(d);
                insQ.prepare(QStringLiteral(
                    "INSERT INTO public.ecotone_replay_requests (message_id, failed_at) "
                    "SELECT em.message_id, em.failed_at "
                    "FROM public.ecotone_error_messages em "
                    "WHERE em.message_id IN (%1) "
                    "  AND NOT EXISTS ( "
                    "    SELECT 1 FROM public.ecotone_replay_requests r "
                    "    WHERE r.message_id = em.message_id "
                    "  ) "
                    "ORDER BY em.failed_at ASC, em.message_id ASC "
                    "RETURNING id").arg(midsIn));
                if (!insQ.exec()) {
                    result.error = insQ.lastError().text();
                    qWarning() << ">>> replayFifoGroup INSERT failed:" << result.error;
                    d.rollback();
                    return;
                }
                int inserted = 0;
                while (insQ.next()) {
                    const int id = insQ.value(0).toInt();
                    if (firstId == 0 || id < firstId) firstId = id;
                    ++totalCount;
                    ++inserted;
                }
                qWarning() << ">>> replayFifoGroup insert count=" << inserted;
            }

            if (totalCount == 0) {
                result.error = QObject::tr("%1 = %2: nothing to queue (race with worker?)")
                                  .arg(searchField, searchValue);
                d.rollback();
                return;
            }

            if (!d.commit()) {
                result.error = d.lastError().text();
                qWarning() << ">>> replayFifoGroup COMMIT failed:" << result.error;
                return;
            }
            result.firstId = firstId;
            result.count   = totalCount;
            qWarning() << ">>> replayFifoGroup SUCCESS firstId=" << firstId
                       << "count=" << totalCount;
            d.close();
        };

        runSql();
        QSqlDatabase::removeDatabase(connName);
        return result;
    });
    watcher->setFuture(future);
}

void EcotoneClient::fetchErrors(int limit, int offset,
                                const QString& channelFilter,
                                const QString& searchText) {
    if (!m_connected) {
        emit errorOccurred(tr("Not connected to Ecotone database"));
        return;
    }
    setLoading(true);

    struct FetchResult {
        QList<DlqEntry> rows;
        int total = 0;
        QString error;
    };

    const QString host = m_host;
    const int     port = m_port;
    const QString db   = m_database;
    const QString user = m_user;
    const QString pass = m_password;

    auto* watcher = new QFutureWatcher<FetchResult>(this);
    connect(watcher, &QFutureWatcher<FetchResult>::finished, this,
            [this, watcher]() {
                const FetchResult res = watcher->result();
                watcher->deleteLater();
                setLoading(false);
                if (!res.error.isEmpty()) {
                    emit errorOccurred(res.error);
                    return;
                }
                emit errorsReceived(res.rows, res.total);
            });

    auto future = QtConcurrent::run(
        [host, port, db, user, pass, limit, offset, channelFilter, searchText]() -> FetchResult {
            FetchResult result;
            const QString connName = uniqueConnectionName("fetch");
            {
                QSqlDatabase d = QSqlDatabase::addDatabase("QPSQL", connName);
                d.setHostName(host);
                d.setPort(port);
                d.setDatabaseName(db);
                d.setUserName(user);
                d.setPassword(pass);
                if (!d.open()) {
                    result.error = d.lastError().text();
                    QSqlDatabase::removeDatabase(connName);
                    return result;
                }

                // Search priority lives in WHERE — match payload only. Numeric
                // terms (e.g. "709") use a word-boundary regex so the term
                // matches as a whole number anywhere inside the JSON value —
                // covering "id":709, "contract_id":709, "id":"709" alike, but
                // excluding 1709 / 7090. Free-text terms fall back to ILIKE.
                const QString trimmedSearch = searchText.trimmed();
                bool numericSearch = false;
                if (!trimmedSearch.isEmpty()) {
                    trimmedSearch.toLongLong(&numericSearch);
                }

                QStringList where;
                if (!channelFilter.isEmpty())
                    where << QStringLiteral("headers::jsonb->>'polledChannelName' = :channel");
                if (!searchText.isEmpty()) {
                    if (numericSearch) {
                        // Numeric searches: most numbers users care about are
                        // contract IDs, which Ecotone stores in headers for
                        // ~99.98% of rows. Match that exactly first, plus a
                        // word-boundary regex on payload to also catch nested
                        // refs like "contract":{"id":16}.
                        where << QStringLiteral(
                            "(headers::jsonb->>'contract_id' = :num "
                            " OR payload ~ ('\\m' || :num || '\\M'))");
                    } else {
                        where << QStringLiteral("payload ILIKE :search");
                    }
                }
                const QString whereSql = where.isEmpty()
                                         ? QString()
                                         : QStringLiteral(" WHERE ") + where.join(" AND ");

                auto bindFilters = [&](QSqlQuery& q) {
                    if (!channelFilter.isEmpty()) q.bindValue(":channel", channelFilter);
                    if (!searchText.isEmpty()) {
                        if (numericSearch) q.bindValue(":num", trimmedSearch);
                        else               q.bindValue(":search", "%" + searchText + "%");
                    }
                };

                QSqlQuery countQ(d);
                countQ.prepare("SELECT count(*) FROM public.ecotone_error_messages" + whereSql);
                bindFilters(countQ);
                if (!countQ.exec()) {
                    result.error = countQ.lastError().text();
                    d.close();
                    QSqlDatabase::removeDatabase(connName);
                    return result;
                }
                if (countQ.next()) result.total = countQ.value(0).toInt();

                // LEFT JOIN LATERAL pulls the most recent replay request per
                // message_id (if any). If a message has never been queued, both
                // replay_* columns come back NULL.
                QSqlQuery q(d);
                q.prepare("SELECT em.message_id, em.failed_at, em.payload, em.headers, "
                          "       em.headers::jsonb->>'polledChannelName' AS channel, "
                          "       em.headers::jsonb->>'contract_id'        AS contract_id, "
                          "       rr.status                                  AS replay_status, "
                          "       COALESCE(rr.id, 0)                         AS replay_request_id "
                          "FROM public.ecotone_error_messages em "
                          "LEFT JOIN LATERAL ( "
                          "    SELECT r.id, r.status FROM public.ecotone_replay_requests r "
                          "    WHERE r.message_id = em.message_id "
                          "    ORDER BY r.id DESC LIMIT 1 "
                          ") rr ON TRUE "
                          + whereSql + " "
                          "ORDER BY (em.headers::jsonb->>'polledChannelName') ASC NULLS LAST, "
                          "         em.failed_at ASC, em.message_id ASC "
                          "LIMIT :limit OFFSET :offset");
                bindFilters(q);
                q.bindValue(":limit", limit);
                q.bindValue(":offset", offset);
                if (!q.exec()) {
                    result.error = q.lastError().text();
                    d.close();
                    QSqlDatabase::removeDatabase(connName);
                    return result;
                }
                while (q.next()) {
                    DlqEntry e;
                    e.messageId       = q.value(0).toString();
                    e.failedAt        = q.value(1).toDateTime();
                    e.payload         = q.value(2).toString();
                    e.headers         = q.value(3).toString();
                    e.channel         = q.value(4).toString();
                    e.contractId      = q.value(5).toString();
                    e.replayStatus    = q.value(6).toString();
                    e.replayRequestId = q.value(7).toInt();
                    result.rows.push_back(std::move(e));
                }
                d.close();
            }
            QSqlDatabase::removeDatabase(connName);
            return result;
        });
    watcher->setFuture(future);
}

void EcotoneClient::fetchChannels() {
    if (!m_connected) {
        emit errorOccurred(tr("Not connected to Ecotone database"));
        return;
    }

    struct ChannelsResult {
        QStringList channels;
        QString error;
    };

    const QString host = m_host;
    const int     port = m_port;
    const QString db   = m_database;
    const QString user = m_user;
    const QString pass = m_password;

    auto* watcher = new QFutureWatcher<ChannelsResult>(this);
    connect(watcher, &QFutureWatcher<ChannelsResult>::finished, this,
            [this, watcher]() {
                const ChannelsResult res = watcher->result();
                watcher->deleteLater();
                if (!res.error.isEmpty()) {
                    emit errorOccurred(res.error);
                    return;
                }
                emit channelsReceived(res.channels);
            });

    auto future = QtConcurrent::run([host, port, db, user, pass]() -> ChannelsResult {
        ChannelsResult result;
        const QString connName = uniqueConnectionName("channels");
        {
            QSqlDatabase d = QSqlDatabase::addDatabase("QPSQL", connName);
            d.setHostName(host);
            d.setPort(port);
            d.setDatabaseName(db);
            d.setUserName(user);
            d.setPassword(pass);
            if (!d.open()) {
                result.error = d.lastError().text();
                QSqlDatabase::removeDatabase(connName);
                return result;
            }

            QSqlQuery q(d);
            if (!q.exec("SELECT DISTINCT headers::jsonb->>'polledChannelName' AS channel "
                        "FROM public.ecotone_error_messages "
                        "WHERE headers::jsonb->>'polledChannelName' IS NOT NULL "
                        "ORDER BY channel")) {
                result.error = q.lastError().text();
                d.close();
                QSqlDatabase::removeDatabase(connName);
                return result;
            }
            while (q.next()) {
                const QString c = q.value(0).toString();
                if (!c.isEmpty()) result.channels << c;
            }
            d.close();
        }
        QSqlDatabase::removeDatabase(connName);
        return result;
    });
    watcher->setFuture(future);
}

void EcotoneClient::fetchReplayStatusSummary() {
    if (!m_connected) return;  // silent — this is a polling call

    struct SummaryResult {
        QVariantMap counts;
        QString error;
    };

    const QString host = m_host;
    const int     port = m_port;
    const QString db   = m_database;
    const QString user = m_user;
    const QString pass = m_password;

    auto* watcher = new QFutureWatcher<SummaryResult>(this);
    connect(watcher, &QFutureWatcher<SummaryResult>::finished, this,
            [this, watcher]() {
                const SummaryResult res = watcher->result();
                watcher->deleteLater();
                if (!res.error.isEmpty()) return;  // silent on poll errors
                emit replayStatusSummaryReceived(res.counts);
            });

    auto future = QtConcurrent::run([host, port, db, user, pass]() -> SummaryResult {
        SummaryResult result;
        // Pre-fill so the UI always sees the same keys.
        result.counts["pending"]    = 0;
        result.counts["processing"] = 0;
        result.counts["done"]       = 0;
        result.counts["failed"]     = 0;

        const QString connName = uniqueConnectionName("summary");
        {
            QSqlDatabase d = QSqlDatabase::addDatabase("QPSQL", connName);
            d.setHostName(host);
            d.setPort(port);
            d.setDatabaseName(db);
            d.setUserName(user);
            d.setPassword(pass);
            if (!d.open()) {
                result.error = d.lastError().text();
                QSqlDatabase::removeDatabase(connName);
                return result;
            }
            QSqlQuery q(d);
            if (!q.exec("SELECT status, count(*) FROM public.ecotone_replay_requests "
                        "GROUP BY status")) {
                result.error = q.lastError().text();
                d.close();
                QSqlDatabase::removeDatabase(connName);
                return result;
            }
            while (q.next()) {
                result.counts[q.value(0).toString()] = q.value(1).toInt();
            }
            d.close();
        }
        QSqlDatabase::removeDatabase(connName);
        return result;
    });
    watcher->setFuture(future);
}

void EcotoneClient::previewFifoGroup(const QString& groupId,
                                     const QString& searchValue) {
    if (!m_connected) {
        emit errorOccurred(tr("Not connected to Ecotone database"));
        return;
    }
    const FifoGroup* group = m_fifoChannels ? m_fifoChannels->findGroup(groupId) : nullptr;
    if (!group) {
        emit errorOccurred(tr("Unknown FIFO group: %1").arg(groupId));
        return;
    }
    if (searchValue.trimmed().isEmpty()) {
        emit fifoGroupPreviewReceived(groupId, searchValue, {});
        return;
    }

    struct PreviewResult {
        QString groupId;
        QString searchValue;
        QList<DlqEntry> rows;
        QString error;
    };

    const QString host  = m_host;
    const int     port  = m_port;
    const QString db    = m_database;
    const QString user  = m_user;
    const QString pass  = m_password;
    const QString searchField = group->searchField;
    QStringList channelNames;
    for (const auto& c : group->channels) channelNames << c.name;

    auto* watcher = new QFutureWatcher<PreviewResult>(this);
    connect(watcher, &QFutureWatcher<PreviewResult>::finished, this,
            [this, watcher]() {
                const PreviewResult res = watcher->result();
                watcher->deleteLater();
                if (!res.error.isEmpty()) {
                    emit errorOccurred(res.error);
                    return;
                }
                emit fifoGroupPreviewReceived(res.groupId, res.searchValue, res.rows);
            });

    auto future = QtConcurrent::run(
        [host, port, db, user, pass, groupId, searchValue, searchField, channelNames]() -> PreviewResult {
            PreviewResult result;
            result.groupId     = groupId;
            result.searchValue = searchValue;
            const QString connName = uniqueConnectionName("preview");
            {
                QSqlDatabase d = QSqlDatabase::addDatabase("QPSQL", connName);
                d.setHostName(host);
                d.setPort(port);
                d.setDatabaseName(db);
                d.setUserName(user);
                d.setPassword(pass);
                if (!d.open()) {
                    result.error = d.lastError().text();
                    QSqlDatabase::removeDatabase(connName);
                    return result;
                }
                // Build IN-list literally from the group's channel names so we
                // don't need positional bindings for them.
                QStringList quoted;
                for (const auto& n : channelNames) {
                    quoted << QStringLiteral("'%1'").arg(QString(n).replace('\'', "''"));
                }
                const QString channelsIn = quoted.isEmpty() ? QStringLiteral("''")
                                                           : quoted.join(',');
                QSqlQuery q(d);
                q.prepare(
                    QStringLiteral(
                    "SELECT em.message_id, em.failed_at, em.payload, em.headers, "
                    "       em.headers::jsonb->>'polledChannelName' AS channel, "
                    "       em.headers::jsonb->>'contract_id'        AS contract_id, "
                    "       rr.status                                  AS replay_status, "
                    "       COALESCE(rr.id, 0)                         AS replay_request_id "
                    "FROM public.ecotone_error_messages em "
                    "LEFT JOIN LATERAL ( "
                    "    SELECT r.id, r.status FROM public.ecotone_replay_requests r "
                    "    WHERE r.message_id = em.message_id "
                    "    ORDER BY r.id DESC LIMIT 1 "
                    ") rr ON TRUE "
                    "WHERE em.headers::jsonb->>'%1' = :val "
                    "  AND em.headers::jsonb->>'polledChannelName' IN (%2) "
                    "ORDER BY em.failed_at ASC, em.message_id ASC")
                        .arg(QString(searchField).replace('\'', "''"), channelsIn));
                q.bindValue(":val", searchValue);
                if (!q.exec()) {
                    result.error = q.lastError().text();
                    d.close();
                    QSqlDatabase::removeDatabase(connName);
                    return result;
                }
                while (q.next()) {
                    DlqEntry e;
                    e.messageId       = q.value(0).toString();
                    e.failedAt        = q.value(1).toDateTime();
                    e.payload         = q.value(2).toString();
                    e.headers         = q.value(3).toString();
                    e.channel         = q.value(4).toString();
                    e.contractId      = q.value(5).toString();
                    e.replayStatus    = q.value(6).toString();
                    e.replayRequestId = q.value(7).toInt();
                    result.rows.push_back(std::move(e));
                }
                d.close();
            }
            QSqlDatabase::removeDatabase(connName);
            return result;
        });
    watcher->setFuture(future);
}
