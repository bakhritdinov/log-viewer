import QtQuick
import QtTest
import LogViewer.Ui

// Behaviour of the shared components: they only report intent through
// signals, so each test drives input and checks the emitted signal.
Item {
    id: host
    width: 800
    height: 600

    function findItem(item, predicate) {
        if (predicate(item)) return item
        const kids = item.children ?? []
        for (let i = 0; i < kids.length; ++i) {
            const found = findItem(kids[i], predicate)
            if (found) return found
        }
        if (item.contentItem && item.contentItem !== item) {
            const found = findItem(item.contentItem, predicate)
            if (found) return found
        }
        return null
    }
    function findAll(item, predicate, out) {
        out = out ?? []
        if (predicate(item)) out.push(item)
        const kids = item.children ?? []
        for (let i = 0; i < kids.length; ++i) findAll(kids[i], predicate, out)
        return out
    }

    Component { id: searchBox; SearchBox { width: 480; history: ["timeout"]; suggestions: ListModel { } } }
    Component { id: chipBar; FilterChipBar { width: 600 } }
    Component { id: chipModel; ListModel {
        ListElement { text: "level:error"; exclude: false }
        ListElement { text: "-app:billing"; exclude: true }
    } }
    Component { id: segmented; SegmentedControl { model: [{ label: "A", value: "a" }, { label: "B", value: "b" }, "c"]; value: "a" } }
    Component { id: presets; TimePresetGrid { width: 300 } }
    Component { id: legend; LevelLegend { totals: ({ ERROR: 3, WARN: 1 }) } }
    Component { id: rangeForm; AbsoluteRangeForm { width: 500 } }
    Component { id: fieldRow; FieldRow { width: 500; key: "trace_id"; value: "abc" } }

    Component {
        id: menuComponent
        AppMenu {
            id: menu
            property string picked
            AppMenuItem { text: "First"; onTriggered: menu.picked = "first" }
            Repeater {
                model: ["A", "B"]
                delegate: AppMenuItem {
                    required property string modelData
                    text: modelData
                    dotColor: "#f85149"
                    checkedMark: modelData === "B"
                    onTriggered: menu.picked = modelData
                }
            }
            AppMenuSeparator { }
            AppMenuItem { text: "Last"; onTriggered: menu.picked = "last" }
        }
    }
    Component { id: radio; AppRadioButton { text: "Option" } }
    Component { id: check; AppCheckBox { text: "Option" } }
    Component { id: toggle; AppSwitch { } }
    Component { id: confirm; ConfirmDialog { title: "Delete?" } }
    Component { id: facets; FacetList { width: 236; height: 300 } }
    Component { id: facetModel; ListModel {
        ListElement { field: "context.account_number.with.a.really.long.name"; distinct: 27; total: 40; expanded: false; values: [] }
        ListElement { field: "level"; distinct: 3; total: 40; expanded: false; values: [] }
    } }
    Component { id: histogram; HistogramView { width: 400; height: 80; maxTotal: 4 } }
    Component { id: sparseModel; ListModel {
        ListElement { startMs: 0; timeText: "10:00"; error: 0; warn: 2; info: 0; debug: 0; trace: 0; other: 0; total: 2 }
        ListElement { startMs: 60000; timeText: "10:01"; error: 0; warn: 0; info: 7; debug: 0; trace: 0; other: 0; total: 7 }
    } }
    Component { id: longField; FieldRow { width: 300; key: "headers.traceparent.very.long.name"; value: "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01-and-some-more-text" } }
    Component { id: histogramModel; ListModel {
        ListElement { startMs: 0; timeText: "10:00"; error: 1; warn: 3; info: 50; debug: 9; trace: 0; other: 0; total: 63 }
    } }

    SignalSpy { id: spy }

    TestCase {
        name: "Components"
        when: windowShown

        function init() { spy.clear(); spy.target = null; spy.signalName = "" }

        function test_searchSubmitsOnEnterOnly() {
            const box = createTemporaryObject(searchBox, host)
            spy.target = box; spy.signalName = "submitted"
            box.focusInput()
            keyClick(Qt.Key_T); keyClick(Qt.Key_O)
            compare(box.text, "to")
            compare(spy.count, 0)
            tryCompare(box, "popupOpen", true)
            keyClick(Qt.Key_Return)
            compare(spy.count, 1)
            tryCompare(box, "popupOpen", false)
        }

        function test_chipRemoveReportsIndex() {
            const bar = createTemporaryObject(chipBar, host, { model: createTemporaryObject(chipModel, host) })
            spy.target = bar; spy.signalName = "removeRequested"
            const chips = findAll(bar, it => it.hasOwnProperty("exclude") && it.hasOwnProperty("removeRequested"))
            compare(chips.length, 2)
            compare(chips[1].exclude, true)
            waitForRendering(bar)
            mouseClick(chips[1], chips[1].width - 10, chips[1].height / 2)
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], 1)
        }

        function test_segmentedKeyboardAndValues() {
            const control = createTemporaryObject(segmented, host)
            spy.target = control; spy.signalName = "activated"
            control.forceActiveFocus()
            keyClick(Qt.Key_Right)
            compare(control.value, "b")
            keyClick(Qt.Key_Right)
            compare(control.value, "c")
            keyClick(Qt.Key_Right)          // stays at the last option
            compare(control.value, "c")
            control.select(2)               // same value: no signal
            compare(spy.count, 2)
            compare(spy.signalArguments[1][0], "c")
        }

        function test_presetsPick() {
            const grid = createTemporaryObject(presets, host, { currentKey: "1h" })
            spy.target = grid; spy.signalName = "picked"
            compare(grid.presets.length, 12)
            const buttons = findAll(grid, it => it.hasOwnProperty("current"))
            compare(buttons.length, 12)
            compare(buttons.filter(b => b.current).length, 1)
            waitForRendering(grid)
            mouseClick(buttons[11])
            compare(spy.signalArguments[0][0], "yesterday")
        }

        function test_presetsCompactLabels() {
            const grid = createTemporaryObject(presets, host, { touch: true })
            compare(grid.columns, 3)
            const buttons = findAll(grid, it => it.hasOwnProperty("current"))
            verify(buttons[0].text.length < grid.presets[0].long.length)
        }

        function test_legendToggles() {
            const l = createTemporaryObject(legend, host)
            spy.target = l; spy.signalName = "toggled"
            // WARN and above only, as in 2.8.
            const chips = findAll(l, it => it.hasOwnProperty("count") && it.hasOwnProperty("active"))
            compare(chips.length, 2)
            compare(chips[0].count, 3)
            compare(chips[1].count, 1)
            waitForRendering(l)
            mouseClick(chips[1])
            compare(spy.signalArguments[0][0], "WARN")
            l.activeLevel = "WARN"
            verify(chips[1].active)
            l.totals = { ERROR: 0, WARN: 2 }
            verify(!chips[0].visible)                  // no entries: hidden
        }

        function test_rangeFormApply() {
            const form = createTemporaryObject(rangeForm, host, { fromText: "2026-01-01 10:00", toText: "2026-01-01 11:00" })
            spy.target = form; spy.signalName = "applyRequested"
            const apply = findItem(form, it => it.hasOwnProperty("variant") && it.variant === "primary")
            verify(apply)
            waitForRendering(form)
            mouseClick(apply)
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], "2026-01-01 10:00")
            compare(spy.signalArguments[0][1], "2026-01-01 11:00")
        }

        function test_fieldRowSignals() {
            const row = createTemporaryObject(fieldRow, host)
            verify(row)
            spy.target = row; spy.signalName = "includeRequested"
            row.includeRequested()
            compare(spy.count, 1)
        }
        // Menus keep declaration order (Repeater items included), use the
        // theme and close when an item is picked.
        function test_menuOrderAndClose() {
            const m = createTemporaryObject(menuComponent, host)
            m.open()
            tryVerify(() => m.opened)
            const items = findAll(m.contentItem, it => it.hasOwnProperty("checkedMark"))
            compare(items.map(i => i.text), ["First", "A", "B", "Last"])
            verify(items[2].checkedMark)
            compare(String(items[1].dotColor), "#f85149")
            waitForRendering(m.contentItem)
            mouseClick(items[3])
            compare(m.picked, "last")
            tryVerify(() => !m.opened)
        }

        function test_themedToggles() {
            const r = createTemporaryObject(radio, host)
            compare(String(r.indicator.color), String(Theme.inputBg))
            mouseClick(r)
            verify(r.checked)
            compare(String(r.indicator.border.color), String(Theme.accent))
            const c = createTemporaryObject(check, host)
            mouseClick(c)
            verify(c.checked)
            compare(String(c.indicator.color), String(Theme.accentStrong))
            const t = createTemporaryObject(toggle, host)
            mouseClick(t)
            verify(t.checked)
            compare(String(t.indicator.color), String(Theme.successStrong))
        }

        function test_confirmDialog() {
            const d = createTemporaryObject(confirm, host)
            spy.target = d; spy.signalName = "confirmed"
            d.open()
            tryVerify(() => d.opened)
            const buttons = findAll(d.contentItem, it => it.hasOwnProperty("variant"))
            waitForRendering(d.contentItem)
            mouseClick(buttons[buttons.length - 1])
            compare(spy.count, 1)
            tryVerify(() => !d.opened)
        }

        // Long field names elide; every row is as wide as the list and its
        // highlight has equal insets left and right.
        function test_facetRowsStayInsideTheList() {
            const list = createTemporaryObject(facets, host, { model: createTemporaryObject(facetModel, host) })
            waitForRendering(list)
            const rows = findAll(list, it => it.hasOwnProperty("hovered") && it.Accessible.role === Accessible.TreeItem)
            compare(rows.length, 2)
            for (const r of rows) {
                compare(r.width, list.width)
                // Same inset on both sides of the highlight (chevron … count).
                compare(r.contentItem.x, r.width - r.contentItem.x - r.contentItem.width)
                // The name sits on the row's vertical centre (the highlight is not shifted).
                const name = findAll(r, it => it.text === "level" || String(it.text).indexOf("context.") === 0)[0]
                verify(name)
                compare(Math.round(name.mapToItem(r, 0, 0).y + name.height / 2), Math.round(r.height / 2))
            }
        }

        // As in 2.8: bars show WARN (bottom) and ERROR (top) only, scaled to them.
        function test_histogramShowsWarnAndAbove() {
            const h = createTemporaryObject(histogram, host, { model: createTemporaryObject(histogramModel, host) })
            waitForRendering(h)
            const segments = findAll(h, it => it.hasOwnProperty("modelData") && it.modelData && it.modelData.level !== undefined)
            compare(segments.map(s => s.modelData.level).sort(), ["ERROR", "WARN"])
            const warn = segments.find(s => s.modelData.level === "WARN")
            const error = segments.find(s => s.modelData.level === "ERROR")
            compare(warn.height, 80 * 3 / 4)
            compare(error.height, 80 * 1 / 4)
            verify(warn.mapToItem(h, 0, 0).y > error.mapToItem(h, 0, 0).y)   // WARN below ERROR
        }

        // Each icon is its own drawing; "settings" is the gear from the mockups.
        function test_iconsAreDistinct() {
            const names = Object.keys(Icons.paths)
            const paths = names.map(n => Icons.paths[n])
            compare(new Set(paths).size, paths.length)
            verify(Icons.paths.settings !== Icons.paths.sun)
            verify(Icons.paths.settings.indexOf("M19.4 15") > 0)
        }
        // Double click anywhere on the chart, an empty bucket included, asks to reset.
        function test_histogramDoubleClickResets() {
            const h = createTemporaryObject(histogram, host, { model: createTemporaryObject(sparseModel, host), maxTotal: 2 })
            spy.target = h; spy.signalName = "resetRequested"
            waitForRendering(h)
            mouseDoubleClickSequence(h, h.width * 0.75, h.height / 2)   // an empty bucket
            compare(spy.count, 1)
            wait(Qt.styleHints.mouseDoubleClickInterval + 50)
            mouseDoubleClickSequence(h, h.width * 0.25, h.height - 2)    // a bar
            compare(spy.count, 2)
        }

        // A bucket without WARN/ERROR is not a target: no hover, tooltip or click.
        function test_histogramIgnoresEmptyBuckets() {
            const h = createTemporaryObject(histogram, host, { model: createTemporaryObject(sparseModel, host), maxTotal: 2 })
            spy.target = h; spy.signalName = "bucketClicked"
            waitForRendering(h)
            const bars = findAll(h, it => it.hasOwnProperty("hasEntries"))
            compare(bars.length, 2)
            verify(bars[0].hasEntries)
            verify(!bars[1].hasEntries)
            mouseClick(bars[1], bars[1].width / 2, bars[1].height - 2)
            compare(spy.count, 0)
            mouseClick(bars[0], bars[0].width / 2, bars[0].height - 2)
            compare(spy.count, 1)
        }

        // WARN is yellow in the light theme too.
        function test_warnIsYellow() {
            const wasDark = Theme.dark
            Theme.dark = false
            compare(String(Theme.levelColor("WARN")), "#d4a72c")
            Theme.dark = true
            compare(String(Theme.levelColor("WARN")), "#d29922")
            Theme.dark = wasDark
        }

        // Radio and check boxes start flush with the text around them.
        function test_togglesHaveNoLeadingInset() {
            compare(createTemporaryObject(radio, host).indicator.x, 0)
            compare(createTemporaryObject(check, host).indicator.x, 0)
        }

        // Level name and count share a baseline.
        function test_legendBaseline() {
            const l = createTemporaryObject(legend, host)
            waitForRendering(l)
            const chip = findAll(l, it => it.hasOwnProperty("count") && it.hasOwnProperty("active"))[0]
            const name = findAll(chip, it => it.text === "ERROR")[0]
            const count = findAll(chip, it => it.text === "3")[0]
            compare(name.mapToItem(chip, 0, 0).y + name.baselineOffset, count.mapToItem(chip, 0, 0).y + count.baselineOffset)
        }

        // Long names and values wrap instead of being cut off.
        function test_fieldRowWraps() {
            const row = createTemporaryObject(longField, host)
            waitForRendering(row)
            const texts = findAll(row, it => it.wrapMode !== undefined && (it.text === row.key || it.text === row.value))
            compare(texts.length, 2)
            for (const t of texts) {
                compare(t.wrapMode, Text.WrapAnywhere)
                verify(t.lineCount > 1, t.text)
            }
            verify(row.height > 30)
        }
    }
}
