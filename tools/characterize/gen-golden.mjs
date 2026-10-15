#!/usr/bin/env node
// Characterization of the pre-rewrite query logic.
//
// Extracts the query-building JavaScript straight out of AppContent.qml at a
// given git revision (default: the last pre-rewrite master commit), runs it in
// Node against a fixed set of inputs and writes the results as golden files.
// The rewritten C++ core must reproduce them, except for documented, intended
// changes. Re-run only to (re)capture the old behaviour — never to "fix" a test.
//
//   node tools/characterize/gen-golden.mjs [git-rev]

import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const REV = process.argv[2] ?? "1e4c728";
const QML_PATH = "src/logs/qml/AppContent.qml";
const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const outDir = join(root, "tests", "fixtures", "characterization");

const qml = execFileSync("git", ["show", `${REV}:${QML_PATH}`], { cwd: root, encoding: "utf8" });

// Returns the balanced `{ … }` block that starts at or after `from`.
function blockAt(src, from) {
    const start = src.indexOf("{", from);
    let depth = 0;
    for (let i = start; i < src.length; i++) {
        if (src[i] === "{") depth++;
        else if (src[i] === "}" && --depth === 0) return src.slice(start, i + 1);
    }
    throw new Error("unbalanced block");
}
function fn(name) {
    const at = qml.indexOf(`function ${name}(`);
    if (at < 0) throw new Error(`function ${name} not found`);
    const params = qml.slice(qml.indexOf("(", at) + 1, qml.indexOf(")", at));
    return { params, body: blockAt(qml, at) };
}
// `readonly property <type> <name>: <expr or block>`
function prop(name) {
    const at = qml.search(new RegExp(`readonly property \\w+ ${name}:`));
    if (at < 0) throw new Error(`property ${name} not found`);
    const colon = qml.indexOf(":", at) + 1;
    const rest = qml.slice(colon).trimStart();
    if (rest.startsWith("{")) return { block: blockAt(qml, colon) };
    if (rest.startsWith("(")) {
        // `({ ... })` object literal
        const blk = blockAt(qml, colon);
        return { expr: `(${blk})` };
    }
    return { expr: rest.slice(0, rest.indexOf("\n")) };
}

// One sloppy-mode scope that mirrors the QML component's names.
function makeScope(state) {
    const scope = { ...state };
    const define = (name, src) => {
        // eslint-disable-next-line no-new-func
        scope[name] = new Function("scope", `with (scope) { return ${src} }`)(scope);
    };
    define("_levelSynonyms", prop("_levelSynonyms").expr);
    define("_levelFields", prop("_levelFields").expr);
    for (const name of ["_escapeLogsQL", "_levelFilterExpr", "_buildLogsQL", "toggleFilter"]) {
        const f = fn(name);
        define(name, `function ${name}(${f.params}) ${f.body}`);
    }
    const terms = prop("searchTerms").block;
    const range = prop("timeRangeSec").block;
    scope.__searchTerms = new Function("scope", `with (scope) { return function () ${terms} }`)(scope);
    scope.__timeRangeSec = new Function("scope", `with (scope) { return function () ${range} }`)(scope);
    return scope;
}

const baseState = () => ({
    nsLabelName: "_namespace",
    appLabelName: "_appName",
    currentNamespace: "prod-core",
    currentApp: "billing-api",
    _levelServerSide: false,
    activeLevel: "",
    header: { searchText: "", timeRange: "1h", customFrom: "", customTo: "" },
    logModel: { formatValue: v => String(v) },
    searchDebounce: { stop() {} },
    refreshLogs() {},
});

// ── LogsQL ───────────────────────────────────────────────────────────────────
const TF = "_time:3600s offset 0s";
const logsqlCases = [
    ["empty query", ""],
    ["star", "*"],
    ["whitespace only", "   "],
    ["single word", "timeout"],
    ["two words AND", "timeout AND retry"],
    ["lowercase and", "timeout and retry"],
    ["mixed case And", "timeout And retry"],
    ["key value", "service:billing-api"],
    ["key quoted value", "service:\"billing-api\""],
    ["key value with spaces around colon", "service : billing-api"],
    ["value containing colon (url)", "url:https://example.org:8443/path"],
    ["regex filter", "http_status:~5.."],
    ["regex filter quoted", "http_status:~\"5..\""],
    ["regex with backslash", "msg:~\\d+ ms"],
    ["single tilde is not regex", "op:~"],
    ["word with double quote", "say \"hi\""],
    ["word with backslash", "C:\\path"],
    ["leading and trailing spaces", "  timeout  "],
    ["empty middle part", "timeout AND  AND retry"],
    ["trailing AND", "timeout AND "],
    ["mixed words and filters", "timeout AND level:error AND order_id:\"48213\""],
    ["dash prefixed key (exclude not supported yet)", "-level:debug"],
    ["unicode word", "ошибка оплаты"],
    ["regex special chars in word", "a.b*c(d)"],
    ["AND inside word is not a separator", "BRAND"],
].map(([name, query]) => ({ name, query, timeFilter: TF }));

const logsqlExtra = [
    { name: "no time filter", query: "timeout", timeFilter: "" },
    { name: "offset time filter", query: "timeout", timeFilter: "_time:3600s offset 1834s" },
    { name: "level ERROR server side", query: "timeout", timeFilter: TF, levelServerSide: true, activeLevel: "ERROR" },
    { name: "level WARN server side", query: "", timeFilter: TF, levelServerSide: true, activeLevel: "WARN" },
    { name: "level INFO server side", query: "", timeFilter: TF, levelServerSide: true, activeLevel: "INFO" },
    { name: "level DEBUG server side", query: "", timeFilter: TF, levelServerSide: true, activeLevel: "DEBUG" },
    { name: "level TRACE server side", query: "", timeFilter: TF, levelServerSide: true, activeLevel: "TRACE" },
    { name: "unknown level ignored", query: "", timeFilter: TF, levelServerSide: true, activeLevel: "FATAL" },
    { name: "level not server side ignored", query: "", timeFilter: TF, levelServerSide: false, activeLevel: "ERROR" },
    { name: "custom label names", query: "x", timeFilter: TF, nsLabel: "namespace", appLabel: "app" },
    { name: "namespace with quote", query: "", timeFilter: TF, namespace: "we\"ird", app: "a" },
];

const logsql = [...logsqlCases, ...logsqlExtra].map(c => {
    const s = makeScope({
        ...baseState(),
        nsLabelName: c.nsLabel ?? "_namespace",
        appLabelName: c.appLabel ?? "_appName",
        currentNamespace: c.namespace ?? "prod-core",
        currentApp: c.app ?? "billing-api",
        _levelServerSide: !!c.levelServerSide,
        activeLevel: c.activeLevel ?? "",
    });
    return {
        name: c.name,
        input: {
            query: c.query, timeFilter: c.timeFilter,
            nsLabel: s.nsLabelName, appLabel: s.appLabelName,
            namespace: s.currentNamespace, app: s.currentApp,
            levelServerSide: s._levelServerSide, activeLevel: s.activeLevel,
        },
        expected: s._buildLogsQL(c.query, c.timeFilter),
    };
});

// ── toggleFilter ─────────────────────────────────────────────────────────────
const toggle = [
    ["add to empty", "", "service", "billing-api"],
    ["add to star", "*", "service", "billing-api"],
    ["append to words", "timeout", "service", "billing-api"],
    ["remove existing", "timeout AND service:\"billing-api\"", "service", "billing-api"],
    ["remove only filter", "service:\"billing-api\"", "service", "billing-api"],
    ["remove with lowercase and", "timeout and service:\"billing-api\"", "service", "billing-api"],
    ["unquoted existing is not matched", "service:billing-api", "service", "billing-api"],
    ["number value", "", "order_id", 48213],
    ["boolean value", "", "retry", true],
    ["empty string value ignored", "timeout", "service", ""],
    ["null value ignored", "timeout", "service", null],
    ["empty key ignored", "timeout", "", "x"],
    ["trims surrounding spaces", "  timeout  ", "level", "error"],
].map(([name, searchText, key, value]) => {
    const s = makeScope({ ...baseState(), header: { ...baseState().header, searchText } });
    s.toggleFilter(key, value);
    return { name, input: { searchText, key, value }, expected: s.header.searchText };
});

// ── searchTerms ──────────────────────────────────────────────────────────────
const terms = [
    "", "*", "timeout", "timeout AND retry", "timeout and level:error",
    "  a  AND  b  ", "service:\"x\"", "a AND  AND b", "url:http://x",
].map(searchText => {
    const s = makeScope({ ...baseState(), header: { ...baseState().header, searchText } });
    return { input: { searchText }, expected: s.__searchTerms() };
});

// ── timeRangeSec ─────────────────────────────────────────────────────────────
const ranges = [
    ["5m"], ["15m"], ["1h"], ["24h"], ["7d"], ["90s"], ["bogus"],
    ["Custom", "2026-10-15T09:00:00Z", "2026-10-15T12:00:00Z"],
    ["Custom", "2026-10-15T12:00:00Z", "2026-10-15T09:00:00Z"],
    ["Custom", "", "2026-10-15T12:00:00Z"],
].map(([timeRange, customFrom = "", customTo = ""]) => {
    const s = makeScope({ ...baseState(), header: { searchText: "", timeRange, customFrom, customTo } });
    return { input: { timeRange, customFrom, customTo }, expected: s.__timeRangeSec() };
});

mkdirSync(outDir, { recursive: true });
const meta = { source: `${QML_PATH}@${REV}`, generator: "tools/characterize/gen-golden.mjs" };
const write = (file, cases) =>
    writeFileSync(join(outDir, file), JSON.stringify({ ...meta, cases }, null, 2) + "\n");
write("logsql.json", logsql);
write("toggle_filter.json", toggle);
write("search_terms.json", terms);
write("time_range.json", ranges);
console.log(`golden files written to ${outDir} from ${REV}: ` +
    `${logsql.length} logsql, ${toggle.length} toggle, ${terms.length} terms, ${ranges.length} ranges`);
