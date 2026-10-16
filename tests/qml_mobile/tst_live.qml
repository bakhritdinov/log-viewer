import QtQuick
import QtTest
import LogViewer.App
import "../qml_desktop/Helpers.js" as H

// Live tail and patterns over a fake Grafana.
TestCase {
    name: "MobileLive"
    when: windowShown

    property var window

    function root() { return H.windowRoot(window) }
    function popup(test) {
        for (let i = 0; i < H.contentData(window).length; ++i)
            if (H.contentData(window)[i] && test(H.contentData(window)[i])) return H.contentData(window)[i]
        return null
    }
    function byName(name) { return H.find(root(), it => it.Accessible && it.Accessible.name === name && H.isShown(it)) }
    function shownText(text) { return H.visibleText(root(), text) }
    function tap(item) { verify(item); waitForRendering(window.contentItem); mouseClick(item) }
    function liveView() { return H.find(window.contentItem, it => it.hasOwnProperty("pauseReason")) }

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
        Session.live.stop()
        Session.patternsEnabled = false
        for (let i = 0; i < H.contentData(window).length; ++i) {
            const p = H.contentData(window)[i]
            if (!p || !p.hasOwnProperty("closePolicy")) continue
            if (p.opened) p.close()
            tryCompare(p, "visible", false)
        }
    }

    function test_01_patternsTab() {
        tap(H.find(window.contentItem, it => it.text === "Шаблоны · 2" || (it.text !== undefined && String(it.text).startsWith("Шаблоны")) && H.isShown(it)))
        tryCompare(Session, "patternsEnabled", true)
        tryVerify(() => Session.patterns.count > 0, 5000)
        const card = H.find(window.contentItem, it => it.hasOwnProperty("templateParts") && H.isShown(it))
        verify(card)
        tap(card)
        tryVerify(() => card.open)
        harness.scriptLogs(4)
        tap(H.find(root(), it => it.hasOwnProperty("variant") && String(it.text).startsWith("Показать") && H.isShown(it)))
        tryCompare(Session, "patternsEnabled", false)          // back to the records of the pattern
        harness.scriptLogs(12)
        Session.clearSearch()
        Session.clearHistogramFilter()
        tryCompare(Session, "loading", false)
    }

    function test_02_sortSheet() {
        Session.patternsEnabled = true
        tap(byName("Сортировать шаблоны"))
        const sheet = popup(p => p.title === "Сортировка шаблонов")
        tryCompare(sheet, "opened", true)
        tap(byName("По последнему появлению"))
        tryCompare(sheet, "opened", false)
        compare(Session.patternSort, "last")
        Session.patternSort = "count"
    }

    function test_03_liveWaitsThenStreams() {
        tap(H.find(window.contentItem, it => it.text === "Live" && it.hasOwnProperty("variant") && H.isShown(it)))
        tryCompare(Session.live, "running", true)
        tryVerify(() => shownText("Ждём новые записи"))
        verify(shownText("LIVE"))
        harness.completeLast(5)
        tryVerify(() => Session.live.bufferCount > 0, 5000)
        tryVerify(() => H.find(liveView(), it => it.hasOwnProperty("ago") && H.isShown(it)))
    }

    function test_04_pauseAndResume() {
        Session.live.start()
        harness.completeLast(5)
        tryVerify(() => Session.live.bufferCount > 0, 5000)
        tap(byName("Пауза"))
        verify(Session.live.paused)
        verify(shownText("ПАУЗА"))
        tap(byName("Продолжить"))
        verify(!Session.live.paused)
    }

    function test_05_entryPausesAndClosingResumes() {
        Session.live.start()
        harness.completeLast(5)
        tryVerify(() => Session.live.bufferCount > 0, 5000)
        tap(H.find(liveView(), it => it.hasOwnProperty("ago") && H.isShown(it)))
        const details = popup(p => p.hasOwnProperty("canOpenFocus") && p.canOpenFocus)
        tryCompare(details, "opened", true)
        verify(Session.live.paused)
        compare(liveView().pauseReason, "entry")
        details.close()
        tryVerify(() => !Session.live.paused)
    }

    function test_06_leave() {
        Session.live.start()
        tryCompare(Session.live, "running", true)
        tap(byName("Выйти из live"))
        tryCompare(Session.live, "running", false)
        verify(!liveView().visible)
    }
}
