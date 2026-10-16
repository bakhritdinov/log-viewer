#include "LinkHandler.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileOpenEvent>
#include <QGuiApplication>
#include <QLocalServer>
#include <QLocalSocket>
#include <QWindow>
#include <QSettings>

#include "app/Session.h"

namespace lv {

namespace {

// One name per user: two users on one machine each have their own app. Tests
// use a name of their own (LOGVIEWER_INSTANCE_NAME) so a running LogViewer
// is left alone.
QString serverName()
{
    if (const QString name = qEnvironmentVariable("LOGVIEWER_INSTANCE_NAME"); !name.isEmpty()) return name;
    QString user = qEnvironmentVariable("USERNAME");
    if (user.isEmpty()) user = qEnvironmentVariable("USER");
    return QStringLiteral("LogViewer-") + user;
}

} // namespace

LinkHandler::LinkHandler(QObject* parent) : QObject(parent) {}

QString LinkHandler::linkFromArguments(const QStringList& arguments)
{
    for (const QString& a : arguments.mid(1))
        if (a.startsWith(QStringLiteral("logviewer:"), Qt::CaseInsensitive)) return a;
    return {};
}

bool LinkHandler::handedToRunningApp(const QString& link)
{
    QLocalSocket socket;
    socket.connectToServer(serverName());
    if (!socket.waitForConnected(300)) return false;
    // An empty message just brings the running window forward. Wait for the
    // running app's "ok": closing at once could lose the unread line.
    socket.write(link.toUtf8() + '\n');
    socket.flush();
    socket.waitForBytesWritten(1000);
    socket.waitForReadyRead(2000);
    socket.disconnectFromServer();
    return true;
}

void LinkHandler::listen(Session& session, QWindow* window)
{
    m_session = &session;
    m_window = window;
    m_server = new QLocalServer(this);
    m_server->setSocketOptions(QLocalServer::UserAccessOption);
    if (!m_server->listen(serverName())) {
        // A name left by a crashed run (Unix sockets stay behind).
        QLocalServer::removeServer(serverName());
        m_server->listen(serverName());
    }
    connect(m_server, &QLocalServer::newConnection, this, [this] {
        while (QLocalSocket* socket = m_server->nextPendingConnection()) {
            // The line may be there already (or arrive with the disconnect).
            auto consume = [this, socket] {
                if (socket->property("done").toBool() || !socket->canReadLine()) return;
                socket->setProperty("done", true);
                const QString link = QString::fromUtf8(socket->readLine()).trimmed();
                socket->write("ok\n");
                socket->flush();
                open(link);
            };
            connect(socket, &QLocalSocket::readyRead, socket, consume);
            connect(socket, &QLocalSocket::disconnected, socket, [socket, consume] {
                consume();
                socket->deleteLater();
            });
            consume();
        }
    });
    // macOS hands URLs to the running app as an event, not arguments.
    qApp->installEventFilter(this);
}

bool LinkHandler::eventFilter(QObject* watched, QEvent* event)
{
    if (event->type() == QEvent::FileOpen) {
        const QUrl url = static_cast<QFileOpenEvent*>(event)->url();
        if (url.scheme() == u"logviewer") {
            open(url.toString(QUrl::FullyEncoded));
            return true;
        }
    }
    return QObject::eventFilter(watched, event);
}

void LinkHandler::open(const QString& link)
{
    if (m_window) {
        if (m_window->visibility() == QWindow::Minimized) m_window->showNormal();
        m_window->raise();
        m_window->requestActivate();
    }
    if (m_session && !link.isEmpty()) m_session->openLink(link);
}

void LinkHandler::registerScheme()
{
#ifdef Q_OS_WIN
    // HKCU\Software\Classes\logviewer → this executable (kept in step with it,
    // so a moved portable build still opens links).
    const QString exe = QDir::toNativeSeparators(QCoreApplication::applicationFilePath());
    const QString command = QStringLiteral("\"%1\" \"%2\"").arg(exe, QStringLiteral("%1"));
    QSettings classes(QStringLiteral("HKEY_CURRENT_USER\\Software\\Classes\\logviewer"), QSettings::NativeFormat);
    if (classes.value(QStringLiteral("shell/open/command/Default")).toString() == command) return;
    classes.setValue(QStringLiteral("Default"), QStringLiteral("URL:LogViewer link"));
    classes.setValue(QStringLiteral("URL Protocol"), QString());
    classes.setValue(QStringLiteral("DefaultIcon/Default"), QStringLiteral("\"%1\",0").arg(exe));
    classes.setValue(QStringLiteral("shell/open/command/Default"), command);
#endif
}

} // namespace lv
