# Characterization fixtures

Golden files capturing the behaviour of the pre-rewrite query logic in
`src/logs/qml/AppContent.qml` (master `1e4c728`). They are generated, not
hand-written:

```bash
node tools/characterize/gen-golden.mjs 1e4c728
```

The generator pulls the JavaScript functions (`_buildLogsQL`, `_levelFilterExpr`,
`_escapeLogsQL`, `toggleFilter`, `searchTerms`, `timeRangeSec`) out of the QML at
that revision and runs them in Node, so the expectations are the old code's real
output. Regenerate only to re-capture old behaviour, never to make a new test pass.

| File | What it pins down |
|---|---|
| `logsql.json` | search text + selection → LogsQL string |
| `toggle_filter.json` | clicking a field value → new search text |
| `search_terms.json` | free-text terms used for highlighting |
| `time_range.json` | time range preset / custom bounds → window in seconds |

The new `core` must reproduce every case, except the intended changes below.
Each one is asserted explicitly in the core tests next to the golden check.

## Intended changes

| # | Area | Old behaviour (golden) | New behaviour |
|---|---|---|---|
| 1 | LogsQL labels | namespace/app values are not escaped: `_namespace="we"ird"` is invalid LogsQL | label values escaped like filter values |
| 2 | LogsQL empty parts | `timeout AND  AND retry`, `timeout AND ` emit an empty `~"(?i)"` term | empty parts are skipped |
| 3 | Quoted values | `key:"a \"b\""` loses inner quotes (all `"` are stripped) | quoted values are parsed, inner escaped quotes kept |
| 4 | toggleFilter | an existing unquoted `service:billing-api` is not recognized, a duplicate quoted filter is appended | quoted and unquoted forms are treated as the same filter |
| 5 | Exclusion | `-key:value` already yields `-key:"value"` by accident | kept, but as an explicit exclude filter (−chips in the UI) |
| 6 | Custom range | reversed or invalid bounds silently become 24h | rejected as a validation error shown to the user |

Legacy `LogModel` quirks (asserted in `tests/characterization/tst_legacy_logmodel.cpp`, marked `QUIRK`):

| # | Old behaviour | New behaviour |
|---|---|---|
| 7 | `formatValue(3.7)` → `"4"` (doubles lose their fraction) | numbers keep their textual form |
| 8 | overlapping batches keep duplicate entries | entries de-duplicated across batches |
| 9 | an out-of-range page silently shows page 0 | page clamped to the last page |
