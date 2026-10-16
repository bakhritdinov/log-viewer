#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QtQml/qqmlregistration.h>
#include <memory>

#include "app/ErrorInfo.h"
#include "app/LogListModel.h"
#include "core/features/LiveTail.h"

namespace lv {

class Session;

// Live tail of the current source and search: new entries on top, a pause
// while the user reads (new lines keep arriving and are counted), a capped
// buffer and an approximate rate.
class LiveSession : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Provided by Session")
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(bool paused READ isPaused WRITE setPaused NOTIFY bufferChanged)
    Q_PROPERTY(int pending READ pending NOTIFY bufferChanged)
    Q_PROPERTY(int bufferCount READ bufferCount NOTIFY bufferChanged)
    Q_PROPERTY(int capacity READ capacity NOTIFY bufferChanged)
    Q_PROPERTY(double ratePerSecond READ ratePerSecond NOTIFY bufferChanged)
    Q_PROPERTY(bool failing READ isFailing NOTIFY errorChanged)
    Q_PROPERTY(lv::ErrorInfo error READ error NOTIFY errorChanged)
    Q_PROPERTY(lv::LogListModel* logs READ logs CONSTANT)

public:
    LiveSession(Session& session, QObject* parent = nullptr);
    ~LiveSession() override;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    void setPaused(bool paused);
    // Leaves the pause and jumps to the newest entries.
    Q_INVOKABLE void resume() { setPaused(false); }
    // Tests use a short interval.
    // Fixed interval instead of the preference (tests use a short one); 0 = preference.
    void setIntervalMs(int ms) { m_intervalOverrideMs = ms; m_tail->setIntervalMs(ms); }

    bool isRunning() const { return m_tail->isRunning(); }
    bool isPaused() const { return m_buffer.isPaused(); }
    int pending() const { return m_buffer.pending(); }
    int bufferCount() const { return m_buffer.store().size(); }
    int capacity() const { return m_buffer.capacity(); }
    double ratePerSecond() const { return m_rate; }
    bool isFailing() const { return m_tail->isFailing(); }
    ErrorInfo error() const { return m_error; }
    LogListModel* logs() const { return m_logs; }

signals:
    void runningChanged();
    void bufferChanged();
    void errorChanged();

private:
    void onEntries(const LogEntries& entries);

    Session& m_session;
    std::unique_ptr<LiveTail> m_tail;
    TailBuffer m_buffer;
    LogListModel* m_logs;
    ErrorInfo m_error;
    QElapsedTimer m_rateClock;
    int m_rateCount = 0;
    int m_intervalOverrideMs = 0;
    double m_rate = 0;
};

} // namespace lv
