import QtQuick
import QtTest
import LogViewer.Ui

// Every component instantiates in both densities without QML warnings, and
// every icon name resolves to a path.
Item {
    id: host
    width: 800
    height: 600

    Component { id: icon; Icon { } }

    TestCase {
        name: "Smoke"
        when: windowShown

        function init() { failOnWarning(/.*/) }

        function test_components_data() {
            const rows = []
            const specs = [
                ["AppButton", "AppButton { text: \"OK\"; iconName: \"search\" }"],
                ["IconButton", "IconButton { label: \"Close\"; iconName: \"close\" }"],
                ["AppTextField", "AppTextField { text: \"x\"; invalid: true }"],
                ["FilterChip", "FilterChip { text: \"level:error\"; exclude: true }"],
                ["FilterChipBar", "FilterChipBar { model: ListModel { ListElement { text: \"a\"; exclude: false } } }"],
                ["SegmentedControl", "SegmentedControl { model: [\"a\", \"b\"]; value: \"a\" }"],
                ["LevelBadge", "LevelBadge { level: \"ERROR\" }"],
                ["EnvironmentBadge", "EnvironmentBadge { name: \"PROD\"; tint: \"#f85149\" }"],
                ["SectionLabel", "SectionLabel { text: \"Fields\" }"],
                ["Surface", "Surface { width: 100; height: 100; elevated: true }"],
                ["SearchBox", "SearchBox { width: 400; history: [\"timeout\"]; suggestions: ListModel { } }"],
                ["TimePresetGrid", "TimePresetGrid { width: 300; currentKey: \"1h\" }"],
                ["AbsoluteRangeForm", "AbsoluteRangeForm { width: 400; errorText: \"bad\"; timeZoneNote: \"UTC+5\" }"],
                ["HistogramView", "HistogramView { width: 400; height: 120; maxTotal: 5; model: ListModel { ListElement { startMs: 0; timeText: \"10:00\"; error: 1; warn: 1; info: 2; debug: 1; trace: 0; other: 0; total: 5 } } }"],
                ["LevelLegend", "LevelLegend { totals: ({ ERROR: 1 }); activeLevel: \"ERROR\" }"],
                ["ErrorBanner", "ErrorBanner { width: 400 }"],
                ["FieldRow", "FieldRow { width: 400; key: \"k\"; value: \"v\" }"],
                ["MessageView", "MessageView { width: 400; text: '{\"a\": 1, \"b\": \"x\"}' }"],
                ["FacetList", "FacetList { width: 300; height: 200 }"],
                ["Sparkline", "Sparkline { width: 60; height: 16; values: [1, 3, 2]; maxValue: 3 }"],
                ["EmptyState", "EmptyState { width: 400; title: \"T\"; message: \"M\" }"],
                ["Clipboard", "Clipboard { }"],
            ]
            for (const [tag, body] of specs)
                for (const touch of [false, true])
                    rows.push({ tag: tag + (touch ? "/touch" : ""), body: body, touch: touch })
            return rows
        }

        function test_components(data) {
            const obj = Qt.createQmlObject("import QtQuick; import LogViewer.Ui; " + data.body, host, data.tag)
            verify(obj)
            if (obj.hasOwnProperty("touch")) obj.touch = data.touch
            waitForRendering(obj)
            verify(obj.implicitWidth >= 0)
            obj.destroy()
        }

        function test_iconsResolve() {
            const names = Object.keys(Icons.paths)
            verify(names.length > 20)
            for (const n of names) {
                verify(Icons.paths[n].length > 0, n)
                const i = createTemporaryObject(icon, host, { name: n, size: 20 })
                compare(i.implicitWidth, 20)
            }
        }

        function test_themeLevelColors() {
            const colors = ["ERROR", "WARN", "INFO"].map(l => String(Theme.levelColor(l)))
            compare(new Set(colors).size, 3)
            compare(String(Theme.levelColor("ERROR")), "#f85149")
            compare(String(Theme.bg), "#0d1117")
        }
    }
}
