#pragma once

#include <QObject>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

namespace lv {

class KeyValueStore;

// User preferences for how the app looks and behaves, stored in settings and
// shared by the view-models (time format, load size, live tail) and QML
// (Session.prefs). Every setter keeps the value inside its allowed set.
class Preferences : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use Session.prefs")

    // Appearance
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY changed)              // dark, light, system
    Q_PROPERTY(QString density READ density WRITE setDensity NOTIFY changed)        // compact, normal, comfortable
    Q_PROPERTY(int rowHeight READ rowHeight NOTIFY changed)                         // from density
    Q_PROPERTY(int logFontSize READ logFontSize WRITE setLogFontSize NOTIFY changed)
    Q_PROPERTY(int messageLines READ messageLines WRITE setMessageLines NOTIFY changed)   // 1 = one line, elided
    Q_PROPERTY(bool tintRows READ tintRows WRITE setTintRows NOTIFY changed)        // ERROR/WARN rows tinted
    Q_PROPERTY(bool prettyJson READ prettyJson WRITE setPrettyJson NOTIFY changed)
    // Table
    Q_PROPERTY(QString timeFormat READ timeFormat WRITE setTimeFormat NOTIFY changed)   // ms, s, date
    Q_PROPERTY(bool utc READ utc WRITE setUtc NOTIFY changed)
    Q_PROPERTY(bool showLevel READ showLevel WRITE setShowLevel NOTIFY changed)
    Q_PROPERTY(bool showService READ showService WRITE setShowService NOTIFY changed)
    Q_PROPERTY(QStringList extraColumns READ extraColumns WRITE setExtraColumns NOTIFY changed)
    // Behaviour
    Q_PROPERTY(int loadStep READ loadStep WRITE setLoadStep NOTIFY changed)
    Q_PROPERTY(QString defaultRange READ defaultRange WRITE setDefaultRange NOTIFY changed)   // "last" or a preset key
    Q_PROPERTY(int liveIntervalMs READ liveIntervalMs WRITE setLiveIntervalMs NOTIFY changed)
    Q_PROPERTY(int liveBuffer READ liveBuffer WRITE setLiveBuffer NOTIFY changed)

public:
    static constexpr int kDefaultLoadStep = 5000;

    explicit Preferences(KeyValueStore& store, QObject* parent = nullptr);

    QString theme() const;
    void setTheme(const QString& v);
    QString density() const;
    void setDensity(const QString& v);
    int rowHeight() const;
    int logFontSize() const;
    void setLogFontSize(int v);
    int messageLines() const;
    void setMessageLines(int v);
    bool tintRows() const;
    void setTintRows(bool v);
    bool prettyJson() const;
    void setPrettyJson(bool v);

    QString timeFormat() const;
    void setTimeFormat(const QString& v);
    bool utc() const;
    void setUtc(bool v);
    bool showLevel() const;
    void setShowLevel(bool v);
    bool showService() const;
    void setShowService(bool v);
    QStringList extraColumns() const;
    void setExtraColumns(const QStringList& v);
    Q_INVOKABLE void addColumn(const QString& field);
    Q_INVOKABLE void removeColumn(const QString& field);

    int loadStep() const;
    void setLoadStep(int v);
    QString defaultRange() const;
    void setDefaultRange(const QString& v);
    int liveIntervalMs() const;
    void setLiveIntervalMs(int v);
    int liveBuffer() const;
    void setLiveBuffer(int v);

    // The table's time column and the details' full time, as set above.
    QString timeText(const QDateTime& t) const;
    QString dateTimeText(const QDateTime& t) const;

    // Everything back to the defaults.
    Q_INVOKABLE void reset();

signals:
    void changed();

private:
    QVariant value(const QString& key, const QVariant& fallback) const;
    void set(const QString& key, const QVariant& v);

    KeyValueStore& m_store;
};

} // namespace lv
