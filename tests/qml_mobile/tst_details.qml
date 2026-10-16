import QtQuick
import QtTest
import LogViewer.App
import "../qml_desktop/Helpers.js" as H

// Entry details, the focus around an entry and the chart over a fake Grafana.
TestCase {
    name: "MobileDetails"
    when: windowShown

    property var window

    function root() { return H.windowRoot(window) }
    function popup(test) {
        for (let i = 0; i < window.contentData.length; ++i)
            if (window.contentData[i] && test(window.contentData[i])) return window.contentData[i]
        return null
    }
    function details() { return popup(p => p.hasOwnProperty("canOpenFocus") && p.canOpenFocus) }
    function focusScreen() { return popup(p => p.hasOwnProperty("serviceCount")) }
    function byName(name) { return H.find(root(), it => it.Accessible && it.Accessible.name === name && H.isShown(it)) }
    function shownText(text) { return H.visibleText(root(), text) }
    function tap(item) { verify(item); waitForRendering(window.contentItem); mouseClick(item) }
    function cards() { return H.findAll(window.contentItem, it => it.hasOwnProperty("ago") && H.isShown(it)) }
    function openFirst() {
        tap(cards()[0])
        tryCompare(details(), "opened", true)
        compare(details().row, 0)
    }

    function initTestCase() {
        const component = Qt.createComponent("LogViewer.Mobile", "Main")
        verify(component.status === Component.Ready, component.errorString())
        window = component.createObject(null)
        harness.scriptStartup(12)
        harness.start()
        tryCompare(Session.logs, "totalCount", 12, 3000)
        tryCompare(Session, "loading", false)
        waitForRendering(window.contentItem)
    }
    function cleanupTestCase() { window.destroy() }
    // DelegateModel::cancel: Qt's harmless note when a search resets the feed.
    function init() { failOnWarning(/^(?!.*(qt\.qpa\.fonts|Populating font|DelegateModel::cancel)).*$/) }
    function cleanup() {
        if (Session.focus.active) Session.focus.close()
        for (let i = 0; i < window.contentData.length; ++i) {
            const p = window.contentData[i]
            if (!p || !p.hasOwnProperty("closePolicy")) continue
            if (p.opened) p.close()
            tryCompare(p, "visible", false)
        }
        window.section = 0
    }

    function test_01_cardOpensTheEntry() {
        openFirst()
        verify(shownText("ERROR"))
        verify(shownText(Session.logs.rowData(0).dateTimeText))
        tap(byName("Следующая запись"))
        compare(details().row, 1)
        tap(byName("Предыдущая запись"))
        compare(details().row, 0)
        compare(Session.selectedRow, 0)                        // a shared link can highlight it
    }

    function test_02_rawAndBackShowsTheMessage() {
        openFirst()
        const message = Session.logs.rowData(0).message
        details().tab = 1
        waitForRendering(window.contentItem)
        details().tab = 0
        waitForRendering(window.contentItem)
        // The plain message again, not the HTML of the raw view.
        verify(H.find(root(), it => it.hasOwnProperty("persistentSelection") && it.text === message && H.isShown(it)))
    }

    function test_03_copyAndNoTrace() {
        openFirst()
        tap(byName("Копировать"))
        tryVerify(() => byName("Скопировано"))
        tryVerify(() => shownText("Сообщение скопировано"))
        verify(!byName("Трейс").enabled)
        verify(shownText("Трейс недоступен: у записи нет trace_id"))
    }

    function test_04_includeAFieldGoesBackToTheFeed() {
        openFirst()
        harness.scriptLogs(4)
        tap(byName("Показать только level = error"))
        tryCompare(details(), "visible", false)
        tryCompare(Session.logs, "totalCount", 4, 3000)
        compare(Session.appliedSearchText, "level:\"error\"")
        harness.scriptLogs(12)
        Session.clearSearch()
        tryCompare(Session.logs, "totalCount", 12, 3000)
    }

    function test_05_context() {
        openFirst()
        harness.scriptLogs(12)
        tap(byName("Контекст"))
        tryCompare(focusScreen(), "opened", true)
        tryCompare(Session.focus, "loading", false)
        verify(Session.focus.active)
        tryVerify(() => H.find(root(), it => it.hasOwnProperty("anchor") && it.anchor && H.isShown(it)))
        tap(byName("Запись"))                                   // back to the entry
        tryCompare(focusScreen(), "visible", false)
        verify(details().opened)
        verify(!Session.focus.active)
    }

    function test_06_chartPicksAnInterval() {
        window.section = 1
        waitForRendering(window.contentItem)
        const chart = H.find(window.contentItem, it => it.hasOwnProperty("maxTotal") && H.isShown(it))
        verify(chart)
        mousePress(chart, 10, 100)
        mouseMove(chart, 20, 100)
        tryVerify(() => shownText("ERROR"))
        mouseRelease(chart, 20, 100)
        tryVerify(() => Session.histogramFilterActive)
        tryVerify(() => shownText("выбранный интервал"))
        // Feedback: the chart draws WARN and ERROR, so a pick shows those —
        // not the INFO of the interval; all its levels are one tap away.
        const levels = () => { const out = []; for (let i = 0; i < Session.logs.totalCount; ++i) out.push(Session.logs.rowData(i).level); return out }
        tryVerify(() => Session.logs.totalCount > 0 && levels().every(l => l === "ERROR" || l === "WARN"), 3000, levels().join(","))
        const button = text => H.find(root(), it => String(it.text).indexOf(text) === 0 && it.hasOwnProperty("variant") && H.isShown(it))
        verify(button("Показать " + Session.logs.totalCount + " "))
        const problems = Session.logs.totalCount
        tap(button("Все уровни"))
        tryVerify(() => Session.logs.totalCount > problems && levels().indexOf("INFO") >= 0)
        tryCompare(window, "section", 0)
        Session.clearHistogramFilter()
    }

    function test_07_levelFiltersOnTheChart() {
        window.section = 1
        waitForRendering(window.contentItem)
        tap(H.find(window.contentItem, it => it.Accessible && String(it.Accessible.name).startsWith("WARN:") && H.isShown(it)))
        compare(Session.activeLevel, "WARN")
        compare(window.section, 1)                             // stays on the chart
        Session.clearHistogramFilter()
    }
}
