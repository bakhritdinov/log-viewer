#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include "core/domain/LogEntry.h"

namespace lv {

// Everything the details pane / screen shows about one entry.
class EntryDetails {
    Q_GADGET
    QML_VALUE_TYPE(entryDetails)
    Q_PROPERTY(bool valid MEMBER valid)
    Q_PROPERTY(qint64 timeMs MEMBER timeMs)
    Q_PROPERTY(QString dateTimeText MEMBER dateTimeText)
    Q_PROPERTY(QString level MEMBER level)
    Q_PROPERTY(QString message MEMBER message)
    Q_PROPERTY(bool isJson MEMBER isJson)
    Q_PROPERTY(QString prettyMessage MEMBER prettyMessage)
    Q_PROPERTY(QString rawJson MEMBER rawJson)   // { timestamp, message, fields } as in 2.8
    Q_PROPERTY(QVariantList fields MEMBER fields)
    Q_PROPERTY(QString traceId MEMBER traceId)

public:
    bool valid = false;
    qint64 timeMs = 0;
    QString dateTimeText;     // local "yyyy-MM-dd HH:mm:ss.zzz"
    QString level;
    QString message;
    bool isJson = false;      // the message is a JSON object/array
    QString prettyMessage;    // indented JSON, or the message as is
    QString rawJson;          // the whole entry (time, message, fields) as JSON
    QVariantList fields;      // [{key, value}], sorted by key, message/time columns excluded
    QString traceId;

    bool operator==(const EntryDetails& other) const = default;
    static EntryDetails from(const LogEntry& entry);
};

} // namespace lv
