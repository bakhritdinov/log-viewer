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
    function feed() { return H.find(window.contentItem, it => it.hasOwnProperty("refreshing")) }
    // The bottom navigation's tab (the feed has the same accessible name).
    function navTab(name) { return H.findAll(window.contentItem, it => it.Accessible && it.Accessible.name === name && it.hasOwnProperty("checkable") && H.isShown(it)).pop() }
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
    // DelegateModel::cancel: Qt's own note when a new search resets the feed
    // while it is still creating cards beyond the screen; harmless.
    function init() { failOnWarning(/^(?!.*(qt\.qpa\.fonts|Populating font|DelegateModel::cancel)).*$/) }

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

    function test_08_endOfTheFeed() {
        const list = feed()
        for (let i = 0; i < 5; ++i) { list.positionViewAtEnd(); wait(50) }
        tryVerify(() => H.visibleText(window.contentItem, "Это все записи за период"))
        mouseClick(navTab("Логи"))       // a second tap: back to the top
        tryVerify(() => list.contentY - list.originY + list.topMargin <= 1)
    }

    function test_09_refreshKeepsTheCards() {
        // Nothing scripted: the refresh hangs; the cards stay, the button stops it.
        Session.search()
        verify(Session.loading)
        compare(Session.logs.totalCount, 12)
        verify(cards().length > 3)
        verify(byName("Остановить"))
        verify(H.find(window.contentItem, it => it.text !== undefined && /^Загружено .*12/.test(String(it.text)) && H.isShown(it)))
        harness.completeLast(14)
        tryCompare(Session.logs, "totalCount", 14, 3000)
        verify(byName("Обновить"))
    }

    function test_10_nothingFound() {
        harness.scriptLogs(0)
        Session.searchText = "zzz"
        Session.search()
        tryCompare(Session, "loading", false)
        verify(H.visibleText(window.contentItem, "Нет записей по запросу"))
        compare(cards().length, 0)
        verify(!byName("Вид результатов"))                    // no Records / Patterns over nothing
        harness.scriptLogs(12)
        mouseClick(byName("Убрать zzz"))
        tryCompare(Session.logs, "totalCount", 12, 3000)
    }

    function test_11_errorOverShownCards() {
        harness.scriptStatus(502, "bad gateway")
        Session.search()
        tryCompare(Session, "loading", false)
        verify(Session.hasError)
        compare(Session.logs.totalCount, 12)                  // the cards stay
        tryVerify(() => H.find(window.contentItem, it => it.text !== undefined && String(it.text).startsWith("Показаны данные последнего успешного запроса") && H.isShown(it)))
    }

    function test_12_errorWithoutData() {
        harness.scriptStatus(401)
        Session.searchText = "other"
        Session.search()
        tryCompare(Session, "loading", false)
        verify(H.visibleText(window.contentItem, "Записей нет — запрос не выполнен"))
        verify(H.visibleText(window.contentItem, "Неверный логин или пароль"))
        harness.scriptLogs(12)
        Session.searchText = ""
        Session.search()
        tryCompare(Session.logs, "totalCount", 12, 3000)
    }
}
