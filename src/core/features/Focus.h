#pragma once

#include "core/features/ChainedLoader.h"

namespace lv {

// "Focus" views around one entry: its neighbours in the stream (context) or the
// entries sharing its trace id.

// Trace id of an entry (`trace_id` or `traceId` field); empty if none.
QString traceIdOf(const LogEntry& entry);

struct FocusRequest {
    SearchSpec spec;
    TimeRange range;
};

// All entries of the same stream within ±`seconds` of the anchor, ignoring the
// search terms and the server-side level.
FocusRequest contextRequest(const SearchSpec& base, const LogEntry& anchor, int seconds);

// Entries with the anchor's trace id within ±`seconds` (default ±5 min). If the
// anchor has no trace id the query is empty — check traceIdOf() first.
FocusRequest traceRequest(const SearchSpec& base, const LogEntry& anchor, int seconds = 300);

} // namespace lv
