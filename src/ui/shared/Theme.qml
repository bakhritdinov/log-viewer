pragma Singleton
import QtQuick

// Design tokens shared by every design: colours (GitHub dark/light), type,
// spacing, radii and control sizes. Components read tokens only from here.
QtObject {
    id: theme

    property bool dark: true

    // ── Fonts ──
    readonly property FontLoader sansLoader: FontLoader { source: "fonts/IBMPlexSans.ttf" }
    readonly property FontLoader monoLoader: FontLoader { source: "fonts/JetBrainsMono.ttf" }
    readonly property string sans: sansLoader.status === FontLoader.Ready ? sansLoader.font.family : "sans-serif"
    readonly property string mono: monoLoader.status === FontLoader.Ready ? monoLoader.font.family : "monospace"

    readonly property int fontXs: 11
    readonly property int fontSm: 12
    readonly property int fontMd: 13
    readonly property int fontLg: 14
    readonly property int fontXl: 16
    readonly property int fontTitle: 18
    readonly property int fontHero: 22

    // ── Spacing / shape ──
    readonly property int sp1: 4
    readonly property int sp2: 8
    readonly property int sp3: 12
    readonly property int sp4: 16
    readonly property int sp5: 24
    readonly property int radiusSm: 4
    readonly property int radiusMd: 6
    readonly property int radiusLg: 10
    readonly property int radiusXl: 16

    // Control heights: pointer (desktop) and touch (≥ 44 px targets).
    readonly property int controlHeight: 32
    readonly property int touchHeight: 44
    readonly property int inputHeight: 36

    // ── Surfaces ──
    readonly property color bg: dark ? "#0d1117" : "#ffffff"
    readonly property color surface: dark ? "#161b22" : "#f6f8fa"
    readonly property color inputBg: dark ? "#010409" : "#ffffff"
    readonly property color subtle: dark ? "#21262d" : "#eaeef2"
    readonly property color hover: dark ? "#30363d" : "#d0d7de"
    readonly property color border: dark ? "#30363d" : "#d0d7de"
    readonly property color borderMuted: dark ? "#21262d" : "#eaeef2"
    readonly property color overlay: dark ? Qt.rgba(0.004, 0.016, 0.035, 0.72) : Qt.rgba(0.12, 0.14, 0.16, 0.45)

    // ── Text (≥ 4.5:1 on bg and surface) ──
    readonly property color text: dark ? "#c9d1d9" : "#1f2328"
    readonly property color textStrong: dark ? "#f0f6fc" : "#1f2328"
    readonly property color textMuted: dark ? "#8b949e" : "#59636e"
    readonly property color textOnAccent: "#ffffff"
    readonly property color textDisabled: dark ? "#6e7681" : "#8c959f"
    readonly property color hoverBorder: dark ? "#484f58" : "#afb8c1"     // hovered controls
    readonly property color tabIndicator: dark ? "#f78166" : "#fd8c73"    // selected tab underline

    // Tooltips: a dark chip in both themes.
    readonly property color tooltipBg: dark ? "#30363d" : "#1f2328"
    readonly property color tooltipBorder: dark ? "#484f58" : "#1f2328"
    readonly property color tooltipText: dark ? "#f0f6fc" : "#ffffff"

    // ── Accents ──
    readonly property color accent: dark ? "#58a6ff" : "#0969da"
    readonly property color accentStrong: dark ? "#1f6feb" : "#0969da"
    readonly property color accentText: dark ? "#a5d6ff" : "#0550ae"
    readonly property color accentSoft: dark ? Qt.rgba(0.22, 0.545, 0.992, 0.14) : Qt.rgba(0.035, 0.412, 0.855, 0.10)
    readonly property color accentBorder: dark ? Qt.rgba(0.22, 0.545, 0.992, 0.45) : Qt.rgba(0.035, 0.412, 0.855, 0.40)
    readonly property color focusRing: dark ? "#388bfd" : "#0969da"

    readonly property color success: dark ? "#3fb950" : "#1a7f37"
    readonly property color successStrong: dark ? "#238636" : "#1f883d"
    readonly property color successBorder: dark ? "#2ea043" : "#1a7f37"
    readonly property color successText: dark ? "#7ee787" : "#1a7f37"
    readonly property color successPressed: dark ? "#1a7f37" : "#1a7f37"
    readonly property color successSoft: dark ? Qt.rgba(0.18, 0.627, 0.263, 0.18) : Qt.rgba(0.102, 0.498, 0.216, 0.12)

    readonly property color danger: dark ? "#f85149" : "#cf222e"
    readonly property color dangerStrong: dark ? "#da3633" : "#cf222e"    // filled destructive button
    readonly property color dangerText: dark ? "#ff7b72" : "#a40e26"
    readonly property color dangerSoft: dark ? Qt.rgba(0.973, 0.318, 0.286, 0.12) : Qt.rgba(0.812, 0.133, 0.18, 0.08)
    readonly property color dangerBorder: dark ? Qt.rgba(0.973, 0.318, 0.286, 0.45) : Qt.rgba(0.812, 0.133, 0.18, 0.40)

    // Warnings are yellow in both themes (the usual WARN colour); text stays dark
    // enough to read on white.
    readonly property color warn: dark ? "#d29922" : "#d4a72c"
    readonly property color warnText: dark ? "#e3b341" : "#7d4e00"
    readonly property color warnSoft: dark ? Qt.rgba(0.824, 0.6, 0.133, 0.14) : Qt.rgba(0.831, 0.655, 0.173, 0.16)

    readonly property color variable: dark ? "#d2a8ff" : "#8250df"     // pattern placeholders
    readonly property color variableSoft: dark ? Qt.rgba(0.639, 0.443, 0.969, 0.15) : Qt.rgba(0.51, 0.314, 0.875, 0.10)
    readonly property color highlight: dark ? Qt.rgba(0.824, 0.6, 0.133, 0.35) : Qt.rgba(1, 0.827, 0.239, 0.55)

    // JSON syntax colours for message views.
    readonly property color jsonKey: dark ? "#e3b341" : "#9a6700"
    readonly property color jsonString: dark ? "#7ee787" : "#116329"
    readonly property color jsonNumber: dark ? "#79c0ff" : "#0550ae"
    readonly property color jsonBoolean: dark ? "#ff7b72" : "#cf222e"
    readonly property color jsonNull: dark ? "#d2a8ff" : "#8250df"
    readonly property color jsonPunctuation: dark ? "#8b949e" : "#6e7781"
    // The same as names, for Session.jsonStyled.
    readonly property var jsonColors: ({
        key: String(jsonKey), string: String(jsonString), number: String(jsonNumber),
        boolean: String(jsonBoolean), null: String(jsonNull), punctuation: String(jsonPunctuation)
    })

    // ── Log levels ──
    function levelColor(level) {          // stripes, bars, dots
        switch (level) {
        case "ERROR": return danger
        case "WARN": return warn
        case "INFO": return dark ? "#388bfd" : "#0969da"
        case "DEBUG": return dark ? "#6e7681" : "#8c959f"
        case "TRACE": return dark ? "#484f58" : "#afb8c1"
        }
        return border
    }
    function levelTextColor(level) {      // level names in text
        switch (level) {
        case "ERROR": return dangerText
        case "WARN": return warnText
        case "INFO": return dark ? "#79c0ff" : "#0550ae"
        case "DEBUG":
        case "TRACE": return textMuted
        }
        return textMuted
    }
    function levelSoft(level) {
        switch (level) {
        case "ERROR": return dangerSoft
        case "WARN": return warnSoft
        case "INFO": return accentSoft
        }
        return subtle
    }

    // Environment label colour → soft fill and text tint for badges.
    function tint(hex, alpha) {
        const c = Qt.color(hex)
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }
}
