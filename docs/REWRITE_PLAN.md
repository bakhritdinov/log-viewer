# LogViewer rewrite plan

Branch: `rewrite` (from `master` @ `1e4c728`). Exploratory work that preceded the
rewrite (WASM/PWA build, first mobile design, C++ `LogController`) is kept on
`wip/mobile-pwa` for reference only.

Approved UI mockups (desktop + mobile): https://claude.ai/artifact/YB39M32jP3QiR4T6mBdjXe

## Principle: logic and design are strictly separated

```
ui/desktop ─┐
            ├─► ui/shared ─► app (view-models) ─► core (logic)
ui/mobile ──┘
```

- **core** — plain C++ on Qt Core + Network. Knows nothing about QML, screens or
  platforms. All decisions live here: LogsQL, loading, patterns, live tail,
  share links, error classification, storage.
- **app** — view-models (`QML_ELEMENT` / `QML_SINGLETON`): translate core into
  properties, models and invokables. No visual code.
- **ui/shared** — design tokens, SVG icons, primitives and composite components.
  Display data and forward user intent; no business logic.
- **ui/desktop**, **ui/mobile** — layout and navigation only. One design is
  compiled in, chosen by `-DLOGVIEWER_UI=desktop|mobile` (mobile is the default
  for WASM/Android/iOS). No runtime width/platform switches in QML.

Enforced by: `core` does not link Qt Qml/Quick; `qmllint` in CI; a layer check
that rejects networking, query building and parsing in QML.

## Decisions

| Topic | Decision |
|---|---|
| Ecotone | removed |
| Minimum Qt | 6.8 LTS (applied when new code lands). Ubuntu system-Qt PPA builds are replaced by bundled-Qt AppImage/.deb |
| QML registration | typed `QML_ELEMENT` / `QML_SINGLETON` instead of context properties |
| Secrets | QtKeychain (Keychain / Credential Manager / Secret Service); PWA falls back to browser storage with a warning |
| Environments | arbitrary list with name + colour; DEV and PROD by default; old `DEV/*`, `PROD/*` settings migrated |
| Desktop paging | pages kept (`[` `]`, page input) + "Load 5 000 more" |
| Mobile fields search | no separate screen: field/value suggestions in the search field |
| Live tail | polling every 2 s with a "newer than last entry" cursor, dedupe, 10 000-line buffer, pause on scroll |
| Share links | PWA: `https://<pwa-host>/#/…`; desktop: `logviewer://` registered by installers |
| Parsing | off the UI thread (worker thread on desktop, chunked on WASM) |
| Search trigger | Enter (no search-as-you-type); suggestions update while typing |
| Languages | Russian (default), Uzbek (Latin), English. Source strings are English in `tr`/`qsTr`/`QCoreApplication::translate`; `i18n/logviewer_{ru,uz}.ts` via `qt_add_translations` (lupdate/lrelease), `.qm` embedded as resources. `Language` singleton (`LogViewer.App`) persists `ui/language`, installs the `QTranslator`, sets the default `QLocale` and calls `QQmlEngine::retranslate()`. Language picker in Settings on every platform. No hard-coded UI texts |

New features in scope: exclude filter (−), context ±N min, trace view, connection
test, Keychain, "Yesterday" preset, stop loading, SVG icons, share links, saved
queries, live tail, message patterns, typed errors.

## Layout

```
src/core/{domain,query,data,features,storage}
src/app/            view-models
src/ui/{shared,desktop,mobile}
src/platform/       main.cpp, URL scheme, single instance, WASM full screen
pwa/                PWA shell
tests/{characterization,core,app,qml}, tests/fixtures/
```

## Status

| Stage | State |
|---|---|
| 0 Preparation | done |
| 1 core/domain + query | done |
| 2 core/data | done |
| 3 core/features + storage | done (QtKeychain adapter moves to stage 8) |
| 4 app view-models | done — `LogViewer.App`; core + app line coverage 93 % |
| 5 ui/shared + i18n | done — `LogViewer.Ui` (25 components, Qt Quick tests), `Language`, ru/uz + en plurals; translations to be reviewed by native speakers |
| 6 ui/desktop | done — `LogViewer.Desktop`, `logviewer-next` executable (`src/platform`), scenario tests over a fake Grafana, qmllint clean |
| 7 ui/mobile + PWA | done — `LogViewer.Mobile` (feed, search, sheets, details / focus, chart, live, patterns, settings), phone preference defaults, scenario tests; WebAssembly build with a PWA shell (`src/platform/wasm`: page, manifest, service worker, update and install notices, wake lock in live tail) and a page ↔ app bridge (`WebShell`). Left for stage 8: system "Send…", file export/import on the phone, the last result kept offline |
| 8 Platforms and release | in progress — LogViewer 3.0.0 with 2.x's settings (environments and passwords taken once, 2.x keys kept, Ecotone's dropped); legacy code removed; passwords in the system keychain (QtKeychain); `logviewer://` links with one app at a time; the phone's share sheet and file export / import; Linux as AppImage only (PPA / DEB dropped: the distributions' Qt is older than 6.8); CI on Windows / macOS / Linux, the mobile design and WebAssembly; the PWA published to GitHub Pages on release (docs/PWA.md) |
| 9 | pending |

## Stages

Each stage ends with a green build, green tests and a commit.

0. Preparation — branch, Ecotone removal, test infrastructure + CI,
   characterization tests of the old logic.
1. core/domain + query — models, query parser, LogsQL builder, suggestions.
2. core/data — HTTP abstraction, Grafana API, off-thread parsing, label
   discovery, error classifier; response fixtures.
3. core/features + storage — chained loader, paging, histogram, facets,
   patterns, live tail, context, share links, environments, Keychain, saved
   queries, settings migration.
4. app — view-models with scenario tests over a fake HTTP client.
5. ui/shared + i18n — tokens, icons, primitives, components + Qt Quick tests;
   `Language` singleton, ru/uz translations, `update_translations` target.
6. ui/desktop per mockups (incl. language picker in Settings; Session rebuilds
   its presented strings when the language changes).
7. ui/mobile per mockups (incl. language picker) + PWA shell. Translations must
   keep covering both designs: lupdate has to scan `src/ui/desktop` and
   `src/ui/mobile` whichever design is built (otherwise `-no-obsolete` drops
   the other design's strings).
8. Platforms and release — switch the app's settings name from "LogViewerNext" to
   "LogViewer" (enables the legacy migration), URL scheme, installers, PWA hosting, CI matrix,
   removal of legacy code (and of the characterization tests that target it).
9. Stabilization — checklist run against live Grafana (DEV/PROD), 5 000-row
   performance, accessibility.

## Tests

| Level | Tool | Scope |
|---|---|---|
| characterization | Qt Test + Node generator | old behaviour, see `tests/fixtures/characterization/README.md` |
| core | Qt Test | parser/builder (golden), time ranges, parsing fixtures, loader guardrails, paging, histogram, facets, patterns, live tail, link codec round-trip, error classifier, settings migration |
| app | Qt Test + fake HTTP | view-model scenarios |
| qml | Qt Quick Test (offscreen) | shared components; smoke load of both `Main.qml` |

Target: core line coverage ≥ 85 %. Run: `cmake -B build -DLOGVIEWER_TESTS=ON && cmake --build build && ctest --test-dir build`.
