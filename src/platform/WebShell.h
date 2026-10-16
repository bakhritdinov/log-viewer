#pragma once

class QQuickWindow;

namespace lv {

class Session;

// The browser page around the app (WebAssembly / PWA, src/platform/wasm): the
// page's address is the base of share links and may carry one to open; the
// browser bar takes the app's theme colour; the screen stays on in live tail;
// the page hears about successful searches (to offer installing) and tells
// the app when the network is back or another link was opened. Does nothing
// outside the browser.
namespace webshell {

// Wires the window and the session to the page.
void attach(QQuickWindow* window, Session& session);
// Opens the share link in the page's address, if any; false: start normally.
bool openInitialLink(Session& session);

} // namespace webshell
} // namespace lv
