pragma Singleton
import QtQuick

QtObject {
    id: theme

    // Mode toggle. Bound to ConfigManager.darkTheme from Main.qml at startup.
    property bool dark: true

    // ── Backgrounds ───────────────────────────────────────
    readonly property color bg:           dark ? "#0d1117" : "#ffffff"
    readonly property color bgRaised:     dark ? "#161b22" : "#f6f8fa"
    readonly property color bgInput:      dark ? "#010409" : "#ffffff"
    readonly property color bgSubtle:     dark ? "#21262d" : "#eaeef2"
    readonly property color bgHover:      dark ? "#30363d" : "#d0d7de"

    // ── Borders ───────────────────────────────────────────
    readonly property color border:       dark ? "#30363d" : "#d0d7de"
    readonly property color borderMuted:  dark ? "#21262d" : "#eaeef2"
    readonly property color borderFocus:  dark ? "#58a6ff" : "#0969da"

    // ── Text ──────────────────────────────────────────────
    readonly property color text:         dark ? "#c9d1d9" : "#1f2328"
    readonly property color textMuted:    dark ? "#8b949e" : "#57606a"
    readonly property color textDim:      dark ? "#484f58" : "#8c959f"
    readonly property color textOnAccent: "#ffffff"

    // ── Accents ───────────────────────────────────────────
    readonly property color accent:       dark ? "#58a6ff" : "#0969da"
    readonly property color success:      dark ? "#3fb950" : "#1a7f37"
    readonly property color successDim:   dark ? "#238636" : "#2da44e"
    readonly property color warn:         dark ? "#d29922" : "#bf8700"
    readonly property color warnDim:      dark ? "#e3b341" : "#9a6700"
    readonly property color danger:       dark ? "#f85149" : "#cf222e"

    // ── Spacing — 4px grid ────────────────────────────────
    readonly property int sp1: 4
    readonly property int sp2: 8
    readonly property int sp3: 12
    readonly property int sp4: 16
    readonly property int sp5: 24
    readonly property int sp6: 32

    // ── Radii ─────────────────────────────────────────────
    readonly property int rSm: 4
    readonly property int rMd: 6
    readonly property int rLg: 8

    // ── Font sizes ────────────────────────────────────────
    readonly property int fsXs: 11
    readonly property int fsSm: 12
    readonly property int fsMd: 13
    readonly property int fsLg: 14
    readonly property int fsXl: 16
    readonly property int fs2xl: 18

    // ── Heights of common controls ───────────────────────
    readonly property int hButton: 32
    readonly property int hInput: 36
    readonly property int hRow: 28
    readonly property int hHeader: 32
    readonly property int hToolbar: 38

    // ── Animation ─────────────────────────────────────────
    readonly property int dFast: 100
    readonly property int dBase: 150
    readonly property int dSlow: 220
}
