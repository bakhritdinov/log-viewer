#pragma once

#include <QObject>
#include <QPointer>
#include <QString>

class QLocalServer;
class QWindow;

namespace lv {

class Session;

// logviewer://open?… links on the desktop. One app at a time: a second start
// hands its link (if any) to the running one and quits. The link comes from
// the command line (Windows, Linux) or the system's open-URL event (macOS);
// on Windows the scheme is registered for the current user at start (no
// installer or admin rights needed, the portable build too).
class LinkHandler : public QObject {
    Q_OBJECT
public:
    explicit LinkHandler(QObject* parent = nullptr);

    // True when another LogViewer runs: `link` (may be empty) went to it and
    // this process should quit.
    bool handedToRunningApp(const QString& link);
    // Takes links from later starts and the system from now on.
    void listen(Session& session, QWindow* window);

    // The first logviewer:// argument, if any.
    static QString linkFromArguments(const QStringList& arguments);
    static void registerScheme();

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;

private:
    void open(const QString& link);

    QLocalServer* m_server = nullptr;
    Session* m_session = nullptr;
    QPointer<QWindow> m_window;
};

} // namespace lv
