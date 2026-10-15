import QtQuick
import QtTest
import LogViewer.App
import LogViewer.Ui
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
    // A failed test must not leave a popup open for the next one.
    function cleanup() { keyClick(Qt.Key_Escape); keyClick(Qt.Key_Escape); wait(50) }
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
        waitForRendering(H.windowRoot(window))
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
    function root() { return H.windowRoot(window) }
    function byName(item, name) { return H.find(item, it => it.Accessible && it.Accessible.name === name && H.isShown(it)) }
    function globalX(item) { return item.mapToItem(root(), 0, 0).x }

    // Feedback #4: the field highlights line up with the filter field.
    function test_15_fieldRowsAlignWithTheFilter() {
        const filter = byName(window.contentItem, "Поиск по полям")
        verify(filter)
        const row = H.find(window.contentItem, it => it.Accessible && it.Accessible.role === Accessible.TreeItem && H.isShown(it))
        verify(row)
        compare(globalX(row), globalX(filter))
        compare(globalX(row) + row.width, globalX(filter) + filter.width)
    }

    // Feedback #1: shortcut names and keys sit on common edges.
    function test_16_shortcutsAligned() {
        keyClick("?")
        tryVerify(() => overlayText("Горячие клавиши") !== null)
        waitForRendering(root())
        const lines = H.findAll(root(), it => it.hasOwnProperty("modelData") && it.modelData && it.modelData.keys !== undefined
                                             && it.modelData.text !== undefined && H.isShown(it) && it.width > 300)
        verify(lines.length >= 10, lines.length)
        const lefts = new Set(), rights = new Set()
        for (const line of lines) {
            const label = H.find(line, it => it.text === line.modelData.text)
            const keys = H.findAll(line, it => it.hasOwnProperty("text") && line.modelData.keys.indexOf(it.text) >= 0 && it.border !== undefined)
            lefts.add(globalX(label))
            compare(globalX(label) - globalX(line), 24)                              // page margin
            compare(globalX(line) + line.width - (globalX(keys[keys.length - 1]) + keys[keys.length - 1].width), 24)
            const last = keys[keys.length - 1]
            rights.add(globalX(last) + last.width)
        }
        compare(lefts.size, 1)
        compare(rights.size, 1)
        keyClick(Qt.Key_Escape)
    }

    // Feedback #2: the share popup uses the app's controls and shows the link from its start.
    function test_17_shareThemed() {
        mouseClick(rows()[0])
        keySequence("Ctrl+L")
        const field = () => byName(root(), "Ссылка")
        tryVerify(() => field() !== null)
        compare(field().cursorPosition, 0)
        const toggles = H.findAll(root(), it => it.indicator !== undefined && it.checkable !== undefined && it.text !== undefined
                                               && H.isShown(it) && (String(it.text).indexOf("Зафиксировать") === 0
                                                                    || String(it.text).indexOf("Относительно") === 0
                                                                    || String(it.text).indexOf("Выделить") === 0))
        compare(toggles.length, 3)
        for (const t of toggles) verify(t.indicator.radius >= 4, t.text)                 // our indicators
        for (const t of toggles) verify(String(t.indicator.color) !== "#ffffff", t.text) // not the stock white
        keyClick(Qt.Key_Escape)
        keyClick(Qt.Key_Escape)
    }

    // Feedback (refresh menu): themed, options first, live tail last.
    function test_18_refreshMenu() {
        const button = byName(window.contentItem, "Автообновление: выкл")
        verify(button)
        mouseClick(button)
        const items = () => H.findAll(root(), it => it.hasOwnProperty("checkedMark") && H.isShown(it))
        tryVerify(() => items().length === 6)
        compare(items().map(i => i.text), ["Без автообновления", "Каждые 5 с", "Каждые 10 с", "Каждые 30 с", "Каждые 1 мин", "Live tail (хвост)"])
        verify(items()[0].checkedMark)
        waitForRendering(root())
        mouseClick(items()[2])
        compare(Session.autoRefreshSeconds, 10)
        tryVerify(() => items().length === 0)                    // closed
        Session.autoRefreshSeconds = 0
    }

    // Feedback (environment menu): themed, colour dots, current checked.
    function test_19_environmentMenu() {
        mouseClick(byName(window.contentItem, "Окружение: DEV"))
        const items = () => H.findAll(root(), it => it.hasOwnProperty("checkedMark") && H.isShown(it))
        tryVerify(() => items().length === 3)
        compare(items().map(i => i.text), ["DEV", "PROD", "Управление окружениями…"])
        verify(items()[0].checkedMark)
        verify(items()[0].dotColor.a > 0 && items()[1].dotColor.a > 0)
        keyClick(Qt.Key_Escape)
        tryVerify(() => items().length === 0)
    }

    // Feedback (2.8 histogram): only ERROR and WARN in the legend.
    function test_20_histogramLegendWarnAndAbove() {
        const chips = H.findAll(window.contentItem, it => it.hasOwnProperty("count") && it.hasOwnProperty("active") && H.isShown(it))
        compare(chips.map(c => c.modelData), ["ERROR", "WARN"])
    }

    // Feedback #3 and patterns of WARN and above.
    function test_21_patternsWarnAndAbove() {
        Session.patternsEnabled = true
        tryCompare(Session, "analyzing", false)
        verify(Session.patterns.count > 0)
        for (let i = 0; i < Session.patterns.count; ++i) {
            const p = Session.patterns.get(i)
            verify(p.level === "WARN" || p.level === "ERROR", p.level)
            verify(p.count >= 2)
        }
        Session.patternsEnabled = false
    }

    // Feedback (settings icon): the gear, not the sun.
    function test_22_settingsIcon() {
        const button = byName(window.contentItem, "Настройки")
        compare(button.iconName, "settings")
        verify(Icons.paths.settings !== Icons.paths.sun)
    }
}
