import QtQuick
import QtTest
import LogViewer.App
import "Helpers.js" as H

// Accessibility of the desktop design: every control a screen reader reaches
// has a name, on the main window and in each popup.
TestCase {
    name: "DesktopA11y"
    when: windowShown

    property var window

    function root() { return H.windowRoot(window) }

    function initTestCase() {
        const component = Qt.createComponent("LogViewer.Desktop", "Main")
        verify(component.status === Component.Ready, component.errorString())
        window = component.createObject(null, { width: 1440, height: 900 })
        verify(window)
        harness.scriptStartup(30)
        harness.start()
        tryCompare(Session.logs, "totalCount", 30, 3000)
        tryCompare(Session, "loading", false)
        waitForRendering(window.contentItem)
    }
    function cleanupTestCase() { window.destroy() }
    function cleanup() { keyClick(Qt.Key_Escape); keyClick(Qt.Key_Escape); wait(50) }

    function expectNamed(where) {
        waitForRendering(window.contentItem)
        compare(H.unnamedControls(root(), it => it.Accessible ? it.Accessible.name : "").join("\n"), "", where)
    }

    function test_main() { expectNamed("main window") }
    function test_details() {
        Session.selectRow(0)
        expectNamed("details")
        Session.clearSelection()
    }
    function test_sourcePicker() { keySequence("Ctrl+K"); wait(200); expectNamed("source picker") }
    function test_timeRange() { keySequence("Ctrl+T"); wait(200); expectNamed("time range") }
    function test_share() { keySequence("Ctrl+L"); wait(200); expectNamed("share") }
    function test_settings() { keySequence("Ctrl+,"); wait(200); expectNamed("settings") }
    // Tab walks the whole window and comes back: each stop shown, named and
    // named; the search, the table and the main actions on the way.
    function test_tabOrder() {
        window.requestActivate()
        const stops = []
        let first = null
        for (let i = 0; i < 80; ++i) {
            keyClick(Qt.Key_Tab)
            const it = window.activeFocusItem
            verify(it, "focus lost after " + i + " Tab")
            if (it === first) break
            if (!first) first = it
            stops.push(it)
        }
        verify(window.activeFocusItem === first, "Tab does not come back within 80 stops: " + stops.length)
        const nameOf = it => {
            for (let p = it; p; p = p.parent) {
                const n = (p.Accessible && p.Accessible.name) || p.text || p.placeholderText
                if (n) return String(n)
            }
            return ""
        }
        const unnamed = stops.filter(it => nameOf(it) === "").map(it => String(it))
        compare(unnamed.join(", "), "", "Tab stops without a name")
        const hidden = stops.filter(it => !H.isShown(it)).map(it => nameOf(it))
        compare(hidden.join(", "), "", "Tab stops that are not shown")
        const names = stops.map(nameOf)
        for (const expected of ["Поиск по логам", "Обновить"])
            verify(names.some(n => n.indexOf(expected) >= 0), expected + " not in " + names.join(" | "))
        // The table: its rows (a row, or the list itself, holds the focus).
        verify(stops.some(it => it.hasOwnProperty("timeText") || (it.Accessible && it.Accessible.role === Accessible.Table)),
               "no table in " + names.join(" | "))
    }

    // An empty search field passes Tab on (suggestions are open, but nothing
    // is typed); with text, Tab completes the first suggestion.
    function test_tabLeavesEmptySearch() {
        Session.clearSearch()
        keySequence("Ctrl+F")
        const field = window.activeFocusItem
        verify(field && field.hasOwnProperty("cursorPosition"))
        keyClick(Qt.Key_Tab)
        verify(window.activeFocusItem !== field, "Tab stayed in the empty search field")
        keySequence("Ctrl+F")
        keyClick("l"); keyClick("e")
        keyClick(Qt.Key_Tab)
        verify(window.activeFocusItem === field)
        verify(Session.searchText.indexOf("level") === 0, Session.searchText)
        Session.clearSearch()
    }

    function test_patterns() { Session.patternsEnabled = true; wait(200); expectNamed("patterns"); Session.patternsEnabled = false }
}
