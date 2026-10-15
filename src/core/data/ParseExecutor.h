#pragma once

#include <QByteArray>
#include <QObject>
#include <functional>
#include <memory>

#include "core/data/GrafanaApi.h"

namespace lv {

// Runs response parsing away from the caller so a 1000-row batch never blocks
// the UI. `done` is called on `context`'s thread, and not at all if `context`
// is destroyed first.
class ParseExecutor {
public:
    virtual ~ParseExecutor() = default;
    virtual void parseLogs(QByteArray body, QObject* context, std::function<void(ParsedLogs)> done) = 0;
};

// Parses on the global thread pool (inline when Qt is built without threads).
std::unique_ptr<ParseExecutor> makeThreadedParseExecutor();
// Parses on the caller's thread at the next event-loop iteration (single-threaded
// WebAssembly; also handy in tests).
std::unique_ptr<ParseExecutor> makeInlineParseExecutor();
// The right executor for this build: threaded where Qt has threads.
std::unique_ptr<ParseExecutor> makeDefaultParseExecutor();

} // namespace lv
