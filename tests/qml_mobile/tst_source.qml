import QtQuick
import QtTest
import LogViewer.App
import "../qml_desktop/Helpers.js" as H

// The source, period and environment sheets over a fake Grafana.
TestCase {
    name: "MobileSource"
    when: windowShown

    property var window

    function root() { return H.windowRoot(window) }
    function popup(test) {
        for (let i = 0; i < window.contentData.length; ++i)
            if (window.contentData[i] && test(window.contentData[i])) return window.contentData[i]
        return null
    }
    function sourceSheet() { return popup(p => p.hasOwnProperty("openNamespace")) }
    function timeSheet() { return popup(p => p.objectName === "timeSheet") }
    function environmentSheet() { return popup(p => p.hasOwnProperty("keptApp")) }
    function byName(name) { return H.find(root(), it => it.Accessible && it.Accessible.name === name && H.isShown(it)) }
    function shownText(text) { return H.visibleText(root(), text) }
    function tap(item) { verify(item); waitForRendering(window.contentItem); mouseClick(item) }

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
        for (let i = 0; i < window.contentData.length; ++i) {
            const p = window.contentData[i]
            if (!p || !p.hasOwnProperty("closePolicy")) continue
            if (p.opened) p.close()
            tryCompare(p, "visible", false)
        }
    }

    function test_01_barOpensTheSourceSheet() {
        tap(byName("Источник: prod-core / billing-api"))
        tryCompare(sourceSheet(), "opened", true)
        verify(shownText("Недавние"))
        verify(shownText("Все · DEV"))
        // The current namespace is open; another one opens instead of it.
        verify(byName("prod-core / billing-gw"))
        tap(byName("prod-data"))
        tryVerify(() => byName("prod-data / etl"))
        verify(!byName("prod-core / billing-gw"))
    }

    function test_02_pickAnApp() {
        sourceSheet().open()
        tryCompare(sourceSheet(), "opened", true)
        harness.scriptLogs(5)
        tap(byName("prod-core / billing-gw"))
        tryCompare(sourceSheet(), "opened", false)
        compare(Session.app, "billing-gw")
        tryCompare(Session.logs, "totalCount", 5, 3000)
    }

    function test_03_typingGivesAFlatList() {
        sourceSheet().open()
        tryCompare(sourceSheet(), "opened", true)
        sourceSheet().query = "work"
        tryVerify(() => shownText("Найдено в DEV · 1"))
        verify(!shownText("Недавние"))                         // hidden while typing
        harness.scriptLogs(6)
        tap(byName("prod-core / billing-worker"))
        tryVerify(() => Session.app === "billing-worker")
        tryCompare(Session.logs, "totalCount", 6, 3000)
    }

    function test_04_nothingFound() {
        sourceSheet().open()
        tryCompare(sourceSheet(), "opened", true)
        sourceSheet().query = "ledgr"
        tryVerify(() => shownText("В DEV нет «ledgr»"))
    }

    function test_05_periodPresetAppliesAtOnce() {
        tap(H.find(window.contentItem, it => it.Accessible && String(it.Accessible.name).startsWith("Период:") && H.isShown(it)))
        tryCompare(timeSheet(), "opened", true)
        harness.scriptLogs(7)
        tap(shownText("15 мин"))
        tryCompare(timeSheet(), "opened", false)
        compare(Session.timeRangeKey, "15m")
        tryCompare(Session.logs, "totalCount", 7, 3000)
    }

    function test_06_wrongCustomPeriodKeepsTheSheet() {
        timeSheet().open()
        tryCompare(timeSheet(), "opened", true)
        const from = byName("Начало периода")
        const to = byName("Конец периода")
        verify(from && to)
        from.text = "2026-10-15 14:00"
        to.text = "2026-10-15 12:00"
        tap(H.find(root(), it => it.text === "Применить" && it.hasOwnProperty("variant") && H.isShown(it)))
        verify(timeSheet().opened)
        verify(Session.rangeError !== "")
    }

    function test_07_environmentSheet() {
        tap(byName("Окружение: DEV"))
        tryCompare(environmentSheet(), "opened", true)
        verify(byName("DEV"))
        verify(byName("PROD"))
        verify(shownText("Не настроено"))
        tap(byName("Управление окружениями"))
        tryCompare(window, "section", 2)
    }

    // A sheet opened a second time comes up again (it stayed below the screen,
    // only its scrim showing, after the first close).
    function test_08_sheetOpensAgain() {
        for (const sheet of [timeSheet(), environmentSheet()]) {
            for (let round = 0; round < 2; ++round) {
                sheet.open()
                tryCompare(sheet, "opened", true)
                tryVerify(() => Math.abs(sheet.y - (sheet.parent.height - sheet.height)) < 1)
                sheet.close()
                tryCompare(sheet, "visible", false)
            }
        }
    }
}
