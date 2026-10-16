#include "WebShell.h"

#include <QQuickWindow>

#include "app/DeviceBridge.h"
#include "app/LiveSession.h"
#include "app/LogListModel.h"
#include "app/Session.h"

#ifdef Q_OS_WASM
#include <QMetaObject>
#include <emscripten/bind.h>
#include <emscripten/val.h>
#endif

namespace lv::webshell {

#ifdef Q_OS_WASM

namespace {

Session* g_session = nullptr;

QString pageAddress()
{
    return QString::fromStdString(emscripten::val::global("location")["href"].as<std::string>());
}

// A function the page defines (index.html), called if it is there.
void callPage(const char* name, const emscripten::val& arg = emscripten::val::undefined())
{
    const emscripten::val fn = emscripten::val::global(name);
    if (fn.typeOf().as<std::string>() == "function") fn(arg);
}

// From the page: the network is back — repeat what failed.
void onOnline()
{
    if (g_session && g_session->hasError())
        QMetaObject::invokeMethod(g_session, [] { g_session->retry(); }, Qt::QueuedConnection);
}

// From the page: the text of the file the user picked (after logviewerOpenFile).
void onFileOpened(std::string content)
{
    if (!g_session) return;
    const QString text = QString::fromStdString(content);
    QMetaObject::invokeMethod(g_session, [text] { g_session->device()->deliverFile(text); }, Qt::QueuedConnection);
}

bool pageHas(const char* name)
{
    return emscripten::val::global(name).typeOf().as<std::string>() == "function";
}

// From the page: another share link was opened (the address after # changed).
void onOpenLink(std::string url)
{
    if (!g_session) return;
    const QString link = QString::fromStdString(url);
    QMetaObject::invokeMethod(g_session, [link] { g_session->openLink(link); }, Qt::QueuedConnection);
}

} // namespace

void attach(QQuickWindow* window, Session& session)
{
    g_session = &session;
    // Links point at this page: its address without the part after #.
    QString base = pageAddress();
    if (const qsizetype hash = base.indexOf(u'#'); hash >= 0) base.truncate(hash);
    session.setShareBaseUrl(base);

    // The browser bar and the page behind the app follow its theme (the bar
    // colour of the dark and light designs).
    if (window) {
        const auto paint = [window] {
            const bool dark = window->color().lightness() < 128;
            callPage("logviewerThemeColor", emscripten::val(dark ? "#161b22" : "#f6f8fa"));
        };
        QObject::connect(window, &QQuickWindow::colorChanged, window, paint);
        paint();
    }

    // The system share sheet where the browser has one (phones), and files the
    // user saves or picks through the page.
    DeviceBridge* device = session.device();
    if (!emscripten::val::global("navigator")["share"].isUndefined()) {
        device->setShareHandler([](const QString& title, const QString& url) {
            emscripten::val data = emscripten::val::object();
            data.set("title", title.toStdString());
            data.set("url", url.toStdString());
            callPage("logviewerShare", data);
        });
    }
    if (pageHas("logviewerSaveFile") && pageHas("logviewerOpenFile")) {
        device->setFileHandlers(
            [](const QString& name, const QString& content) {
                emscripten::val file = emscripten::val::object();
                file.set("name", name.toStdString());
                file.set("content", content.toStdString());
                callPage("logviewerSaveFile", file);
            },
            [] { callPage("logviewerOpenFile"); });
    }

    // The screen stays on while live tail runs (the page holds a wake lock).
    QObject::connect(session.live(), &LiveSession::runningChanged, &session, [&session] {
        callPage("logviewerKeepAwake", emscripten::val(session.live()->isRunning()));
    });

    // Successful searches: the page offers installing after the second one.
    QObject::connect(&session, &Session::loadingChanged, &session, [&session] {
        if (!session.isLoading() && !session.hasError() && session.logs()->totalCount() > 0)
            callPage("logviewerSearchSucceeded");
    });
}

bool openInitialLink(Session& session)
{
    const QString address = pageAddress();
    return address.contains(QStringLiteral("#/open?")) && session.openLink(address);
}

EMSCRIPTEN_BINDINGS(logviewer_webshell)
{
    emscripten::function("logviewerOnline", &onOnline);
    emscripten::function("logviewerOpenLink", &onOpenLink);
    emscripten::function("logviewerFileOpened", &onFileOpened);
}

#else

void attach(QQuickWindow*, Session&) {}
bool openInitialLink(Session&) { return false; }

#endif

} // namespace lv::webshell
