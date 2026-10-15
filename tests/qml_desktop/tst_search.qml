import QtQuick
import QtTest
import LogViewer.App
import "Helpers.js" as H

// The main scenario: load, select an entry, search with Enter, patterns,
// language switch, shortcuts.
TestCase {
    name: "Search"
    when: windowShown

    property var window

    function rows() { return H.findAll(window.contentItem, it => it.hasOwnProperty("timeText") && it.hasOwnProperty("anchored") && H.isShown(it)) }

    function initTestCase() {
        const component = Qt.createComponent("LogViewer.Desktop", "Main")
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
    // Any QML warning fails the test (font fallback notices aside).
    function init() { failOnWarning(/^(?!.*(qt\.qpa\.fonts|Populating font)).*$/) }
    function overlayText(text) { return H.visibleText(H.windowRoot(window), text) }

    function test_01_rowsShown() {
        compare(Session.app, "billing-api")
        tryVerify(() => rows().length === 12)
        verify(H.visibleText(window.contentItem, "Обновить"))
    }

    function test_02_selectAndClose() {
        const first = rows()[0]
        mouseClick(first)
        compare(Session.selectedRow, 0)
        tryVerify(() => H.find(window.contentItem, it => it.Accessible.name === "Подробности записи" && H.isShown(it)) !== null)
        keyClick(Qt.Key_Down)
        compare(Session.selectedRow, 1)
        keyClick(Qt.Key_Escape)
        compare(Session.selectedRow, -1)
    }

    function test_03_searchRunsOnEnterOnly() {
        const before = harness.requestCount
        keySequence("Ctrl+F")
        for (const ch of "timeout") keyClick(ch)
        compare(Session.searchText, "timeout")
        wait(50)
        compare(harness.requestCount, before)
        harness.scriptLogs(5)
        keyClick(Qt.Key_Return)
        tryVerify(() => harness.requestCount > before)
        verify(harness.lastExpr().indexOf("timeout") >= 0, harness.lastExpr())
        tryCompare(Session.logs, "totalCount", 5, 3000)
    }

    function test_04_patterns() {
        Session.patternsEnabled = true
        tryVerify(() => Session.patterns.count > 0)
        tryVerify(() => H.findAll(window.contentItem, it => it.hasOwnProperty("templateParts") && H.isShown(it)).length > 0)
        Session.patternsEnabled = false
    }

    function test_05_languageSwitch() {
        Language.code = "en"
        tryVerify(() => H.visibleText(window.contentItem, "Refresh") !== null)
        Language.code = "uz"
        tryVerify(() => H.visibleText(window.contentItem, "Yangilash") !== null)
        Language.code = "ru"
        tryVerify(() => H.visibleText(window.contentItem, "Обновить") !== null)
    }

    function test_06_shortcutsHelp() {
        window.contentItem.forceActiveFocus()
        keyClick("?")
        const overlay = H.windowRoot(window)
        tryVerify(() => H.visibleText(overlay, "Горячие клавиши") !== null)
        keyClick(Qt.Key_Escape)
    }

    function test_07_sourcePicker() {
        keySequence("Ctrl+K")
        tryVerify(() => overlayText("Недавние") !== null || H.find(H.windowRoot(window), it => it.Accessible.name === "Выбор источника логов" && H.isShown(it)) !== null)
        for (const ch of "bill") keyClick(ch)
        keyClick(Qt.Key_Escape)
    }

    function test_08_timePresets() {
        keySequence("Ctrl+T")
        tryVerify(() => overlayText("Произвольный период") !== null)
        waitForRendering(H.windowRoot(window))
        harness.scriptLogs(4)
        mouseClick(overlayText("Последние 15 минут"))
        tryCompare(Session, "timeRangeKey", "15m")
        tryVerify(() => overlayText("Произвольный период") === null)
        tryCompare(Session.logs, "totalCount", 4, 3000)
    }

    function test_09_shareLink() {
        keySequence("Ctrl+L")
        const field = () => H.find(H.windowRoot(window), it => it.Accessible.name === "Ссылка" && H.isShown(it))
        tryVerify(() => field() !== null)
        verify(field().text.indexOf("logviewer://") === 0, field().text)
        keyClick(Qt.Key_Escape)
    }

    function test_10_savedQuery() {
        keySequence("Ctrl+S")
        tryVerify(() => overlayText("Сохранить текущий") !== null)
        mouseClick(overlayText("Сохранить текущий"))
        tryCompare(Session.savedQueries, "count", 1)
        keyClick(Qt.Key_Escape)
    }

    function test_11_contextFocus() {
        mouseClick(rows()[0])
        harness.scriptLogs(6)
        mouseClick(H.visibleText(window.contentItem, "Контекст ±1 мин"))
        tryCompare(Session.focus, "active", true)
        tryVerify(() => H.visibleText(window.contentItem, "К результатам поиска") !== null)
        tryCompare(Session.focus, "loading", false)
        keyClick(Qt.Key_Escape)
        tryCompare(Session.focus, "active", false)
    }

    function test_12_liveTail() {
        harness.scriptLogs(3)
        Session.live.start()
        tryVerify(() => H.find(window.contentItem, it => it.text !== undefined && String(it.text).indexOf("LIVE") === 0 && H.isShown(it)) !== null)
        verify(H.visibleText(window.contentItem, "Период не нужен — показываются новые записи"))
        Session.live.stop()
        tryVerify(() => H.visibleText(window.contentItem, "Обновить") !== null)
    }

    function test_13_settingsPages() {
        keySequence("Ctrl+,")
        tryVerify(() => overlayText("Подключения к Grafana") !== null)
        for (const section of ["Язык", "Внешний вид", "Горячие клавиши", "Версия", "Подключения"]) {
            const nav = H.find(H.windowRoot(window), it => it.Accessible.name === section && it.hasOwnProperty("current") && H.isShown(it))
            verify(nav, section)
            mouseClick(nav)
            tryVerify(() => nav.current)
        }
        keyClick(Qt.Key_Escape)
    }

    function test_14_languagePicker() {
        keySequence("Ctrl+,")
        const nav = () => H.find(H.windowRoot(window), it => it.Accessible.name === "Язык" && it.hasOwnProperty("current") && H.isShown(it))
        tryVerify(() => nav() !== null)
        mouseClick(nav())
        tryVerify(() => overlayText("English") !== null)
        mouseClick(overlayText("English"))
        tryCompare(Language, "code", "en")
        tryVerify(() => overlayText("Interface language") !== null)
        mouseClick(overlayText("Русский"))
        tryCompare(Language, "code", "ru")
        keyClick(Qt.Key_Escape)
    }
}
