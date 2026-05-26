#pragma once

#include <QObject>
#include <QList>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// Single channel inside a FIFO group.
//
//   name       — exact polledChannelName from headers
//   rerouteTo  — channel to switch polledChannelName to before replay; empty
//                for queues that are already the "error" sink and don't need
//                a reroute step.
//
// Ordering inside a group is decided by failed_at ASC at query time —
// the errored message lands in the *_errors sink earlier than the main-queue
// follow-ups, so failed_at gives "errors first" naturally.
struct FifoChannel {
    QString name;
    QString rerouteTo;
};

// A logically connected family of FIFO channels — e.g. contract_update_state
// + contract_update_state_errors. Different groups can search by different
// header keys (contract_id, client_id, …) and show in their own tab.
struct FifoGroup {
    QString id;                 // stable identifier, e.g. "contract"
    QString label;              // tab title, e.g. "Contract"
    QString searchField;        // headers JSON key, e.g. "contract_id"
    QString searchPlaceholder;  // UI hint, e.g. "Contract ID (e.g. 1234567)"
    QList<FifoChannel> channels;
};

class FifoChannels : public QObject {
    Q_OBJECT
public:
    explicit FifoChannels(QObject* parent = nullptr);

    // QML-facing API.
    //
    // groups() returns a list of objects suitable for direct binding:
    //   [{ id, label, searchField, searchPlaceholder,
    //      channels: [{ name, rerouteTo, priority }, ...] }, ...]
    Q_INVOKABLE QVariantList groups() const;

    // Channel-level lookups — used by table delegate / Replay-by-… handlers.
    Q_INVOKABLE bool        isFifo(const QString& channel) const;
    Q_INVOKABLE QString     rerouteFor(const QString& channel) const;
    Q_INVOKABLE QString     groupIdFor(const QString& channel) const;
    Q_INVOKABLE QStringList allChannels() const;

    // C++ internal access.
    const QList<FifoGroup>& groupList() const { return m_groups; }
    const FifoGroup*        findGroup(const QString& id) const;

private:
    QList<FifoGroup> m_groups;
};
