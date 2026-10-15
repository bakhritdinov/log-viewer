#include "app/EntryDetails.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include "core/features/Focus.h"
#include "core/query/Query.h"

namespace lv {

EntryDetails EntryDetails::from(const LogEntry& e)
{
    EntryDetails d;
    d.valid = true;
    d.timeMs = e.timeMs();
    d.dateTimeText = e.timestamp.toLocalTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss.zzz"));
    d.level = levelName(e.level);
    d.message = e.message;
    d.traceId = traceIdOf(e);

    const QString trimmed = e.message.trimmed();
    QJsonDocument messageDoc;
    if (trimmed.startsWith(u'{') || trimmed.startsWith(u'[')) {
        QJsonParseError err;
        messageDoc = QJsonDocument::fromJson(trimmed.toUtf8(), &err);
        if (err.error == QJsonParseError::NoError && !messageDoc.isNull()) {
            d.isJson = true;
            d.prettyMessage = QString::fromUtf8(messageDoc.toJson(QJsonDocument::Indented)).trimmed();
        }
    }
    if (!d.isJson) d.prettyMessage = e.message;

    // The entry as it came from Grafana, as in 2.8: { timestamp, message, fields }
    // in that order. A JSON message is embedded as data, not as an escaped string.
    const auto nested = [](const QJsonDocument& doc) {
        return QString::fromUtf8(doc.toJson(QJsonDocument::Indented)).trimmed().replace(u'\n', QStringLiteral("\n    "));
    };
    const auto quoted = [](const QString& text) {
        const QString array = QString::fromUtf8(QJsonDocument(QJsonArray{ text }).toJson(QJsonDocument::Compact));
        return array.mid(1, array.size() - 2);
    };
    d.rawJson = QStringLiteral("{\n    \"timestamp\": %1,\n    \"message\": %2,\n    \"fields\": %3\n}")
                    .arg(quoted(e.timestamp.toUTC().toString(Qt::ISODateWithMs)),
                         d.isJson ? nested(messageDoc) : quoted(e.message),
                         nested(QJsonDocument(QJsonObject::fromVariantMap(e.fields))));

    for (auto it = e.fields.cbegin(); it != e.fields.cend(); ++it) {   // key-sorted
        if (it.key() == u"Line" || it.key() == u"message") continue;
        d.fields << QVariantMap{ { "key", it.key() }, { "value", formatFieldValue(it.value()) } };
    }
    return d;
}

} // namespace lv
