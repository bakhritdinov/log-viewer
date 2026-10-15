#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>
#include <memory>

#include "app/ErrorInfo.h"
#include "app/LogListModel.h"
#include "core/features/ChainedLoader.h"
#include "core/features/Focus.h"

namespace lv {

class Session;

// Temporary view around one entry: its neighbours (context) or the entries of
// its trace. Has its own store and loader so the main search stays intact.
class FocusSession : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Provided by Session")
    Q_PROPERTY(Mode mode READ mode NOTIFY changed)
    Q_PROPERTY(bool active READ isActive NOTIFY changed)
    Q_PROPERTY(int windowSeconds READ windowSeconds WRITE setWindowSeconds NOTIFY changed)
    Q_PROPERTY(QString anchorTimeText READ anchorTimeText NOTIFY changed)
    Q_PROPERTY(int anchorRow READ anchorRow NOTIFY changed)
    Q_PROPERTY(QString traceId READ traceId NOTIFY changed)
    Q_PROPERTY(bool canShowTrace READ canShowTrace NOTIFY changed)
    Q_PROPERTY(QString windowText READ windowText NOTIFY changed)
    Q_PROPERTY(bool loading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(ErrorInfo error READ error NOTIFY changed)
    Q_PROPERTY(LogListModel* logs READ logs CONSTANT)

public:
    enum class Mode { None, Context, Trace };
    Q_ENUM(Mode)

    FocusSession(Session& session, QObject* parent = nullptr);
    ~FocusSession() override;

    // Opens around the entry at `row` of `model` (the main list or another).
    Q_INVOKABLE void openContext(LogListModel* model, int row, int seconds = 60);
    Q_INVOKABLE void openTrace(LogListModel* model, int row);
    Q_INVOKABLE void showContext();   // switch modes for the same anchor
    Q_INVOKABLE void showTrace();
    void setWindowSeconds(int seconds);
    Q_INVOKABLE void close();
    // Turns the focus into a normal search (its range and query) and closes it.
    Q_INVOKABLE void openAsSearch();

    Mode mode() const { return m_mode; }
    bool isActive() const { return m_mode != Mode::None; }
    int windowSeconds() const { return m_seconds; }
    QString anchorTimeText() const;
    int anchorRow() const { return m_anchorRow; }
    QString traceId() const;
    bool canShowTrace() const { return !traceId().isEmpty(); }
    QString windowText() const;
    bool isLoading() const { return m_loader->isLoading(); }
    ErrorInfo error() const { return m_error; }
    LogListModel* logs() const { return m_logs; }

signals:
    void changed();
    void loadingChanged();

private:
    void load();
    void locateAnchor();

    Session& m_session;
    LogStore m_store;
    std::unique_ptr<ChainedLoader> m_loader;
    LogListModel* m_logs;
    Mode m_mode = Mode::None;
    int m_seconds = 60;
    LogEntry m_anchor;
    int m_anchorRow = -1;
    ErrorInfo m_error;
    TimeRange m_range;      // window of the current focus (for openAsSearch)
};

} // namespace lv
