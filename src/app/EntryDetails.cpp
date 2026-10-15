#include "app/EntryDetails.h"

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
    if (trimmed.startsWith(u'{') || trimmed.startsWith(u'[')) {
        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(trimmed.toUtf8(), &err);
        if (err.error == QJsonParseError::NoError && !doc.isNull()) {
            d.isJson = true;
            d.prettyMessage = QString::fromUtf8(doc.toJson(QJsonDocument::Indented)).trimmed();
        }
    }
    if (!d.isJson) d.prettyMessage = e.message;

    QJsonObject raw = QJsonObject::fromVariantMap(e.fields);
    raw.insert(QStringLiteral("_time"), e.timestamp.toUTC().toString(Qt::ISODateWithMs));
    raw.insert(QStringLiteral("_msg"), e.message);
    d.rawJson = QString::fromUtf8(QJsonDocument(raw).toJson(QJsonDocument::Indented)).trimmed();

    for (auto it = e.fields.cbegin(); it != e.fields.cend(); ++it) {   // key-sorted
        if (it.key() == u"Line" || it.key() == u"message") continue;
        d.fields << QVariantMap{ { "key", it.key() }, { "value", formatFieldValue(it.value()) } };
    }
    return d;
}

} // namespace lv
