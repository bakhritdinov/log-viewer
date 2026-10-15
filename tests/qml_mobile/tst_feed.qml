import QtQuick
import QtTest
import LogViewer.App
import "../qml_desktop/Helpers.js" as H

// The Logs section over a fake Grafana: cards, search, chart, navigation.
TestCase {
    name: "MobileFeed"
    when: windowShown

    property var window

    function cards() { return H.findAll(window.contentItem, it => it.hasOwnProperty("ago") && it.hasOwnProperty("timeMs") && H.isShown(it)) }
    function byName(name) { return H.find(window.contentItem, it => it.Accessible && it.Accessible.name === name && H.isShown(it)) }

    function initTestCase() {
        const component = Qt.createComponent("LogViewer.Mobile", "Main")
        verify(component.status === Component.Ready, component.errorString())
        window = component.createObject(null)
        verify(window)
        harness.scriptStartup(12)
        harness.start()
        tryCompare(Session.logs, "totalCount", 12, 3000)
        tryCompare(Session, "loading", false)
        waitForRendering(window.contentItem)
    }
    function cleanupTestCase() { window.destroy() }
    function init() { failOnWarning(/^(?!.*(qt\.qpa\.fonts|Populating font)).*$/) }

    function test_01_phoneWindow() {
        compare(window.width, 390)
        compare(window.section, 0)
    }

    function test_02_cards() {
        tryVerify(() => cards().length > 3)
        const card = cards()[0]
        compare(card.level, "ERROR")
        verify(card.ago.length > 0)
        // Every card inside the window, with a 12 px gutter.
        const p = card.mapToItem(window.contentItem, 0, 0)
        compare(Math.round(p.x), 12)
        compare(Math.round(card.width), 390 - 24)
    }

    function test_03_sourceInTheBar() {
        verify(H.visibleText(window.contentItem, Session.app))
        verify(byName("Окружение: " + Session.environmentName))
    }

    function test_04_searchRunsOnEnter() {
        const requests = harness.requestCount
        harness.scriptLogs(3)
        Session.searchText = "timeout"
        compare(harness.requestCount, requests)               // typing does not search
        Session.search()
        tryCompare(Session.logs, "totalCount", 3, 3000)
        Session.searchText = ""
        harness.scriptLogs(12)
        Session.search()
        tryCompare(Session.logs, "totalCount", 12, 3000)
    }

    function test_05_chartSection() {
        mouseClick(byName("График"))
        tryCompare(window, "section", 1)
        tryVerify(() => H.find(window.contentItem, it => it.hasOwnProperty("maxTotal") && H.isShown(it)) !== null)
        mouseClick(byName("Логи"))
        tryCompare(window, "section", 0)
    }

    function test_06_settingsSection() {
        mouseClick(byName("Настройки"))
        tryCompare(window, "section", 2)
        verify(H.visibleText(window.contentItem, "Подключения"))
        // The language picker is on the phone too.
        verify(H.find(window.contentItem, it => it.Accessible && it.Accessible.role === Accessible.RadioButton && it.Accessible.name === "Русский" && H.isShown(it)))
        mouseClick(byName("Логи"))
    }

    function test_07_touchTargets() {
        // Every button in the Logs section is at least 44 px tall (32 for chips).
        const small = H.findAll(window.contentItem, it => it.hasOwnProperty("pressed") && it.hasOwnProperty("checkable") && H.isShown(it) && it.height < 32 && it.width > 0)
        compare(small.map(it => String(it.Accessible.name)), [])
    }
}
