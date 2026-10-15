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
            const chips = findAll(l, it => it.hasOwnProperty("count") && it.hasOwnProperty("active"))
            compare(chips.length, 4)
            compare(chips[0].count, 3)
            compare(chips[3].count, 0)
            waitForRendering(l)
            mouseClick(chips[1])
            compare(spy.signalArguments[0][0], "WARN")
            l.activeLevel = "WARN"
            verify(chips[1].active)
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
    }
}
