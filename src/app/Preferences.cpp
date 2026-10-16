#include "app/Preferences.h"

#include <QDateTime>
#include <QLocale>
#include <QTimeZone>
#include <algorithm>

#include "core/storage/KeyValueStore.h"

namespace lv {

namespace {

const QString kPrefix = QStringLiteral("prefs/");
// Written by the desktop window before preferences existed (QML Settings).
const QString kLegacyDark = QStringLiteral("ui.desktop/dark");
const QString kLegacyPrettyJson = QStringLiteral("ui.desktop/prettyJson");

const QStringList kThemes{ "dark", "light", "system" };
const QStringList kDensities{ "compact", "normal", "comfortable" };
const QStringList kTimeFormats{ "ms", "s", "date" };
const QList<int> kLoadSteps{ 1000, 5000, 10000, 20000 };
const QList<int> kLiveIntervals{ 1000, 2000, 5000 };
const QList<int> kLiveBuffers{ 5000, 10000, 20000, 50000 };

QString oneOf(const QString& v, const QStringList& allowed, const QString& fallback)
{
    return allowed.contains(v) ? v : fallback;
}
int oneOf(int v, const QList<int>& allowed, int fallback)
{
    return allowed.contains(v) ? v : fallback;
}

Preferences::Defaults& currentDefaults()
{
    static Preferences::Defaults defaults;
    return defaults;
}

} // namespace

void Preferences::setDefaults(const Defaults& defaults) { currentDefaults() = defaults; }
const Preferences::Defaults& Preferences::defaults() { return currentDefaults(); }

Preferences::Preferences(KeyValueStore& store, QObject* parent) : QObject(parent), m_store(store) {}

QVariant Preferences::value(const QString& key, const QVariant& fallback) const
{
    return m_store.value(kPrefix + key, fallback);
}

void Preferences::set(const QString& key, const QVariant& v)
{
    if (m_store.contains(kPrefix + key) && m_store.value(kPrefix + key) == v) return;
    m_store.setValue(kPrefix + key, v);
    emit changed();
}

// ── appearance ──────────────────────────────────────────────────────────────

QString Preferences::theme() const
{
    const QString legacy = m_store.contains(kLegacyDark) && !m_store.value(kLegacyDark).toBool() ? "light" : "dark";
    return oneOf(value("theme", legacy).toString(), kThemes, "dark");
}
void Preferences::setTheme(const QString& v) { set("theme", oneOf(v, kThemes, "dark")); }

QString Preferences::density() const { return oneOf(value("density", "normal").toString(), kDensities, "normal"); }
void Preferences::setDensity(const QString& v) { set("density", oneOf(v, kDensities, "normal")); }

int Preferences::rowHeight() const
{
    const QString d = density();
    return d == u"compact" ? 22 : d == u"comfortable" ? 34 : 28;
}

int Preferences::logFontSize() const { return std::clamp(value("logFontSize", defaults().logFontSize).toInt(), 11, 15); }
void Preferences::setLogFontSize(int v) { set("logFontSize", std::clamp(v, 11, 15)); }

int Preferences::messageLines() const { return std::clamp(value("messageLines", defaults().messageLines).toInt(), 1, 3); }
void Preferences::setMessageLines(int v) { set("messageLines", std::clamp(v, 1, 3)); }

bool Preferences::tintRows() const { return value("tintRows", false).toBool(); }
void Preferences::setTintRows(bool v) { set("tintRows", v); }

bool Preferences::prettyJson() const { return value("prettyJson", m_store.value(kLegacyPrettyJson, true)).toBool(); }
void Preferences::setPrettyJson(bool v) { set("prettyJson", v); }

// ── table ───────────────────────────────────────────────────────────────────

QString Preferences::timeFormat() const { return oneOf(value("timeFormat", "ms").toString(), kTimeFormats, "ms"); }
void Preferences::setTimeFormat(const QString& v) { set("timeFormat", oneOf(v, kTimeFormats, "ms")); }

bool Preferences::utc() const { return value("utc", false).toBool(); }
void Preferences::setUtc(bool v) { set("utc", v); }

bool Preferences::showLevel() const { return value("showLevel", true).toBool(); }
void Preferences::setShowLevel(bool v) { set("showLevel", v); }

// Off by default: the list shows the one app picked in the source, so the column
// repeats it on every row. Still available in the table settings.
bool Preferences::showService() const { return value("showService", false).toBool(); }
void Preferences::setShowService(bool v) { set("showService", v); }

QStringList Preferences::extraColumns() const { return value("extraColumns", QStringList()).toStringList(); }
void Preferences::setExtraColumns(const QStringList& v)
{
    QStringList clean;
    for (const QString& f : v) {
        const QString t = f.trimmed();
        if (!t.isEmpty() && !clean.contains(t)) clean << t;
    }
    set("extraColumns", clean);
}

void Preferences::addColumn(const QString& field)
{
    setExtraColumns(extraColumns() << field);
}

void Preferences::removeColumn(const QString& field)
{
    QStringList list = extraColumns();
    list.removeAll(field.trimmed());
    setExtraColumns(list);
}

// ── behaviour ───────────────────────────────────────────────────────────────

int Preferences::loadStep() const { return oneOf(value("loadStep", defaults().loadStep).toInt(), kLoadSteps, defaults().loadStep); }
void Preferences::setLoadStep(int v) { set("loadStep", oneOf(v, kLoadSteps, defaults().loadStep)); }

QString Preferences::defaultRange() const { return value("defaultRange", "last").toString(); }
void Preferences::setDefaultRange(const QString& v) { set("defaultRange", v.isEmpty() ? QStringLiteral("last") : v); }

int Preferences::liveIntervalMs() const { return oneOf(value("liveIntervalMs", defaults().liveIntervalMs).toInt(), kLiveIntervals, defaults().liveIntervalMs); }
void Preferences::setLiveIntervalMs(int v) { set("liveIntervalMs", oneOf(v, kLiveIntervals, defaults().liveIntervalMs)); }

int Preferences::liveBuffer() const { return oneOf(value("liveBuffer", defaults().liveBuffer).toInt(), kLiveBuffers, defaults().liveBuffer); }
void Preferences::setLiveBuffer(int v) { set("liveBuffer", oneOf(v, kLiveBuffers, defaults().liveBuffer)); }

// ── formatting ──────────────────────────────────────────────────────────────

QString Preferences::timeText(const QDateTime& t) const
{
    const QDateTime shown = utc() ? t.toUTC() : t.toLocalTime();
    const QString f = timeFormat();
    if (f == u"s") return shown.toString(QStringLiteral("HH:mm:ss"));
    if (f == u"date") return QLocale().toString(shown, QStringLiteral("d MMM HH:mm:ss"));
    return shown.toString(QStringLiteral("HH:mm:ss.zzz"));
}

QString Preferences::dateTimeText(const QDateTime& t) const
{
    const QDateTime shown = utc() ? t.toUTC() : t.toLocalTime();
    return shown.toString(QStringLiteral("yyyy-MM-dd HH:mm:ss.zzz")) + (utc() ? QStringLiteral(" UTC") : QString());
}

void Preferences::reset()
{
    for (const QString& key : m_store.allKeys())
        if (key.startsWith(kPrefix)) m_store.remove(key);
    emit changed();
}

} // namespace lv
