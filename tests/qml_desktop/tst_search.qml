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
        // Not from the search field (there "?" is typed): focus the log table.
        // contentItem.forceActiveFocus() would hand focus back to the field.
        const table = H.find(window.contentItem, it => it.hasOwnProperty("highlightTerms") && it.hasOwnProperty("currentRow") && H.isShown(it))
        verify(table)
        table.forceActiveFocus()
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
        tryVerify(() => overlayText("Сохранить") !== null)
        mouseClick(overlayText("Сохранить"))
        tryCompare(Session.savedQueries, "count", 1)
        keyClick(Qt.Key_Escape)
    }

    // Feedback: "Replace with the current query" in a saved query's menu works.
    function test_10b_replaceSavedQuery() {
        tryCompare(Session.savedQueries, "count", 1)
        Session.searchText = "level:error"
        mouseClick(byName(window.contentItem, "Сохранить запрос"))
        const more = () => H.find(root(), it => String(it.Accessible.name).startsWith("Ещё действия с") && it.visible)
        tryVerify(() => more() !== null)
        waitForRendering(root())
        mouseClick(more())
        tryVerify(() => overlayText("Заменить текущим запросом") !== null)
        waitForRendering(root())
        mouseClick(overlayText("Заменить текущим запросом"))
        tryVerify(() => String(Session.savedQueries.get(0).summary).indexOf("level:error") >= 0)
        tryVerify(() => H.find(root(), it => String(it.text).indexOf("теперь содержит текущий поиск") >= 0 && H.isShown(it)) !== null)   // toast
        mouseClick(byName(window.contentItem, "Сохранить запрос"))
        tryVerify(() => H.find(root(), it => it.font && it.font.family === Theme.mono && String(it.text).indexOf("level:error") >= 0 && H.isShown(it)) !== null)
        keyClick(Qt.Key_Escape)
        Session.searchText = ""
    }

    // The star saves (saved queries, name field focused); the history button
    // opens the recent searches.
    function test_10c_starAndHistoryDiffer() {
        mouseClick(byName(window.contentItem, "Недавние поиски"))
        const tab = name => H.find(root(), it => it.Accessible.name === name && it.Accessible.role === Accessible.PageTab && H.isShown(it))
        tryVerify(() => tab("Недавние поиски") !== null)
        verify(tab("Недавние поиски").Accessible.selected)
        verify(!H.find(root(), it => it.Accessible.name === "Название запроса" && H.isShown(it)))
        keyClick(Qt.Key_Escape)
        mouseClick(byName(window.contentItem, "Сохранить запрос"))
        tryVerify(() => tab("Сохранённые") !== null && tab("Сохранённые").Accessible.selected)
        tryVerify(() => H.find(root(), it => it.Accessible.name === "Название запроса" && it.activeFocus) !== null)
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
        compare(items().map(i => i.text), ["Без автообновления", "Каждые 5 с", "Каждые 10 с", "Каждые 30 с", "Каждую минуту", "Live tail (хвост)"])
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
    // Feedback: the search bar has no syntax hint (the placeholder has it).
    function test_23_noSearchHint() {
        verify(H.find(window.contentItem, it => String(it.text).indexOf("key:~regex · AND") >= 0 && H.isShown(it)) === null)
    }

    // Feedback: a level filter shows on the legend only (no chip with a cross);
    // a time-bucket chip is as tall as the level buttons.
    function test_27_levelFilterHasNoChip() {
        const panel = byName(window.contentItem, "Распределение по времени")
        const chipOf = () => H.find(panel, it => it.hasOwnProperty("pill") && H.isShown(it))
        Session.applyLevelFilter("ERROR")
        tryCompare(Session, "analyzing", false)
        verify(Session.histogramFilterActive)
        compare(chipOf(), null)
        Session.applyLevelFilter("ERROR")                 // again: off
        tryCompare(Session, "analyzing", false)
        verify(!Session.histogramFilterActive)
        Session.applyBucketFilter(0, "")
        tryCompare(Session, "analyzing", false)
        tryVerify(() => chipOf() !== null)
        const button = H.find(window.contentItem, it => it.hasOwnProperty("count") && it.hasOwnProperty("active") && H.isShown(it))
        compare(chipOf().height, button.height)
        Session.clearHistogramFilter()
    }

    // Feedback: the distribution label is centred on the level buttons.
    // Feedback (3.0.0 on a scaled Windows screen): the time ran into the level.
    // Every time and level text fits its column, the next one starts after it.
    function test_23b_columnsFitTheirText() {
        const row = rows()[0]
        verify(row)
        const texts = H.findAll(row, it => it.hasOwnProperty("textFormat") && it.hasOwnProperty("elide") && it.visible && it.text !== "")
        const time = texts.find(t => t.text === row.timeText)
        const level = texts.find(t => t.text === row.level)
        verify(time && level, texts.map(t => t.text).join(" | "))
        verify(time.implicitWidth <= time.width, "time " + time.implicitWidth + " in " + time.width)
        verify(level.implicitWidth <= level.width, "level " + level.implicitWidth + " in " + level.width)
        const timeEnd = time.mapToItem(row, time.implicitWidth, 0).x
        const levelStart = level.mapToItem(row, 0, 0).x
        verify(timeEnd + 8 <= levelStart, "time ends at " + timeEnd + ", level starts at " + levelStart)
        // The titles too: "УРОВЕНЬ" is wider than "ERROR".
        const titles = H.findAll(window.contentItem, it => it.font !== undefined && it.font.capitalization === Font.AllUppercase
                                                           && (it.text === "Время" || it.text === "Уровень") && H.isShown(it))
        compare(titles.length, 2)
        for (const t of titles) verify(t.implicitWidth + 8 <= t.width, t.text + " " + t.implicitWidth + " in " + t.width)
    }

    // Feedback (3.0.0): the pattern sort button's chevron hung outside it.
    // Every shown button holds its content (a replaced contentItem included).
    function test_23c_buttonsHoldTheirContent() {
        Session.patternsEnabled = true
        tryVerify(() => Session.patterns.count > 0)
        waitForRendering(window.contentItem)
        const tight = H.findAll(window.contentItem, it => it.hasOwnProperty("variant") && it.hasOwnProperty("iconName") && H.isShown(it)
                                                         && it.contentItem && it.contentItem.implicitWidth > it.width - it.leftPadding - it.rightPadding + 0.5)
            .map(it => (it.Accessible.name || it.text) + ": " + it.contentItem.implicitWidth + " in " + (it.width - it.leftPadding - it.rightPadding))
        Session.patternsEnabled = false
        compare(tight.join("; "), "")
    }

    // Feedback (3.0.0): a second click on the button that opened a menu or a
    // popup left it open.
    function test_23d_secondClickCloses() {
        const check = (button, shownText) => {
            verify(button)
            mouseClick(button)
            tryVerify(() => overlayText(shownText) !== null, 2000, shownText + " not shown")
            mouseClick(button)
            tryVerify(() => overlayText(shownText) === null, 2000, "still open: " + shownText)
        }
        check(H.find(window.contentItem, it => it.Accessible && String(it.Accessible.name).indexOf("Автообновление") === 0
                                              && it.hasOwnProperty("pressed") && H.isShown(it)), "Без автообновления")
        check(H.find(window.contentItem, it => it.hasOwnProperty("iconName") && it.iconName === "clock" && it.hasOwnProperty("variant")
                                              && H.isShown(it)), "Сегодня")
    }

    function test_24_distributionHeaderAligned() {
        const label = H.find(window.contentItem, it => it.text === "Распределение" && H.isShown(it))
        const chip = H.find(window.contentItem, it => it.hasOwnProperty("count") && it.hasOwnProperty("active") && H.isShown(it))
        const mid = it => it.mapToItem(root(), 0, 0).y + it.height / 2
        compare(Math.round(mid(label)), Math.round(mid(chip)))
    }

    // Feedback: share popup — field and button equally tall, toggles flush with the heading.
    function test_25_shareAligned() {
        mouseClick(rows()[0])
        keySequence("Ctrl+L")
        const field = () => byName(root(), "Ссылка")
        tryVerify(() => field() !== null)
        waitForRendering(root())
        const copy = H.find(field().parent, it => it.text === "Копировать" && it.hasOwnProperty("variant"))
        compare(copy.height, field().height)
        compare(copy.mapToItem(root(), 0, 0).y, field().mapToItem(root(), 0, 0).y)
        // Nothing sticks out of the popup (long labels wrap).
        // The popup's own item: the ancestor sitting directly in the overlay.
        let popup = field()
        while (popup.parent && String(popup.parent).indexOf("QQuickOverlay") !== 0) popup = popup.parent
        verify(popup.width >= 400 && popup.width < 700, popup.width)
        const box = popup.mapToItem(root(), 0, 0)
        for (const it of H.findAll(popup, it => H.isShown(it) && it.width > 0 && it.text !== undefined)) {
            const p = it.mapToItem(root(), 0, 0)
            verify(p.x + it.width <= box.x + popup.width + 0.5, `"${it.text}" ends at ${p.x + it.width} > ${box.x + popup.width}`)
        }
        const heading = H.find(root(), it => it.text === "Период в ссылке" && H.isShown(it))
        const radio = H.find(root(), it => it.indicator !== undefined && String(it.text).indexOf("Зафиксировать") === 0 && H.isShown(it))
        compare(globalX(radio.indicator), globalX(heading))
        keyClick(Qt.Key_Escape)
    }

    // Feedback: raw JSON of any entry (not only JSON messages), as in 2.8;
    // long values wrap; the panel can be widened.
    function test_26_detailsRawAndResize() {
        mouseClick(rows()[0])
        const panel = () => byName(window.contentItem, "Подробности записи")
        tryVerify(() => panel() !== null)
        const raw = H.find(panel(), it => it.Accessible.name === "Raw JSON" && it.hasOwnProperty("current"))
        verify(raw, "the Raw JSON tab is there for a plain-text message")
        mouseClick(raw)
        tryVerify(() => H.find(panel(), it => String(it.text).indexOf("\"timestamp\"") >= 0 && H.isShown(it)) !== null)
        verify(H.find(panel(), it => it.text === "Копировать JSON" && H.isShown(it)))
        // Coloured like the rest of the app's JSON (keys in their colour).
        verify(H.find(panel(), it => it.textFormat === TextEdit.RichText && String(it.text).indexOf(String(Theme.jsonKey)) >= 0 && H.isShown(it)))
        const json = H.find(panel(), it => it.hasOwnProperty("richText") && it.text.indexOf("\"fields\"") >= 0 && H.isShown(it)).text
        verify(JSON.parse(json).message.indexOf("payment") === 0)
        mouseClick(H.find(panel(), it => it.Accessible.name === "Поля" && it.hasOwnProperty("current")))

        const before = panel().width
        panel().resizeRequested(before + 120)
        tryCompare(panel(), "width", before + 120)
        panel().resizeRequested(10)                       // clamped
        tryCompare(panel(), "width", 360)
        panel().resizeRequested(420)
        keyClick(Qt.Key_Escape)
    }

    // A field of the details becomes a table column and back.
    function test_28_fieldAsColumn() {
        mouseClick(rows()[0])
        const panel = () => byName(window.contentItem, "Подробности записи")
        tryVerify(() => panel() !== null)
        // The actions show over the value while the field is hovered.
        const fieldRow = H.find(panel(), it => it.hasOwnProperty("columnable") && H.isShown(it))
        mouseMove(fieldRow, 20, fieldRow.height / 2)
        const toggle = () => H.find(panel(), it => String(it.Accessible.name).startsWith("Показывать колонкой") && it.visible)
        tryVerify(() => toggle() !== null)
        const field = String(toggle().Accessible.name).replace("Показывать колонкой ", "")
        mouseClick(toggle())
        compare(Session.prefs.extraColumns, [field])
        tryVerify(() => H.find(window.contentItem, it => it.text === field && it.font && it.font.capitalization === Font.MixedCase && H.isShown(it)) !== null)   // the header
        mouseMove(fieldRow, 20, fieldRow.height / 2)
        const remove = H.find(panel(), it => it.Accessible.name === "Убрать колонку " + field && it.visible)
        verify(remove, "the toggle says the column is there")
        mouseClick(remove)
        compare(Session.prefs.extraColumns, [])
        keyClick(Qt.Key_Escape)
    }
    // Feedback: Refresh sits at the end of the search field (not in the top bar)
    // and runs the search.
    function test_28_refreshAtTheEndOfTheSearch() {
        const search = byName(window.contentItem, "Поиск по логам")
        const refresh = H.find(window.contentItem, it => it.text === "Обновить" && it.hasOwnProperty("variant") && H.isShown(it))
        verify(search && refresh)
        compare(H.findAll(window.contentItem, it => it.text === "Обновить" && it.hasOwnProperty("variant") && H.isShown(it)).length, 1)
        const s = search.mapToItem(root(), 0, 0), r = refresh.mapToItem(root(), 0, 0)
        verify(r.x > s.x + search.width, "after the search field")
        compare(Math.round(r.y + refresh.height / 2), Math.round(s.y + search.height / 2))   // same line
        const before = harness.requestCount
        harness.scriptLogs(5)
        mouseClick(refresh)
        tryVerify(() => harness.requestCount > before)
        tryCompare(Session, "loading", false)
    }

    // Feedback: no service column by default (the source picks one app).
    function test_29_noServiceColumnByDefault() {
        verify(H.find(window.contentItem, it => it.text === "Сервис" && H.isShown(it)) === null)
        Session.prefs.showService = true
        tryVerify(() => H.find(window.contentItem, it => it.text === "Сервис" && H.isShown(it)) !== null)
        Session.prefs.showService = false
    }

    // Feedback: in "Version" the status icon, its text and the button share a centre line.
    function test_30_updateStatusAligned() {
        keySequence("Ctrl+,")
        const nav = () => H.find(root(), it => it.Accessible.name === "Версия" && it.hasOwnProperty("current") && H.isShown(it))
        tryVerify(() => nav() !== null)
        waitForRendering(root())
        mouseClick(nav())
        const button = () => H.find(root(), it => it.hasOwnProperty("variant") && (it.text === "Проверить обновления" || it.text === "Проверить снова" || it.text === "Повторить") && H.isShown(it))
        tryVerify(() => button() !== null)
        const row = button().parent
        const icon = H.find(row, it => it.hasOwnProperty("strokeWidth") && H.isShown(it))
        // The status icon stands upright and never turns: the "checking" spinner is a
        // separate icon (one shared icon kept the spinner's last angle — a tilted check).
        compare(icon.rotation, 0)
        const icons = H.findAll(icon.parent, it => it.hasOwnProperty("strokeWidth"))
        compare(icons.length, 2)
        const spinner = icons.find(it => it !== icon)
        verify(!spinner.visible && spinner.name === "refresh")
        const title = H.find(row, it => it.hasOwnProperty("firstLineHeight"))
        // Within a pixel: a text line's height is fractional and layouts round it.
        const mid = (it, h) => it.mapToItem(root(), 0, 0).y + h / 2
        verify(Math.abs(mid(icon, icon.height) - mid(button(), button().height)) <= 1)
        verify(Math.abs(mid(title, title.firstLineHeight) - mid(button(), button().height)) <= 1,
               `${mid(title, title.firstLineHeight)} vs ${mid(button(), button().height)}`)
        keyClick(Qt.Key_Escape)
    }
    // Feedback: the refresh keys work — F5 and Ctrl+R (⌘R on macOS); a key bound
    // twice is ambiguous and Qt fires neither.
    function test_31_refreshKey() {
        mouseClick(rows()[0])                         // focus in the list, not in a text field
        for (const key of ["Ctrl+R", "F5", "Ctrl+R"]) {
            const before = harness.requestCount
            harness.scriptLogs(5)
            keySequence(key)
            tryVerify(() => harness.requestCount > before, 2000, key)
            tryCompare(Session, "loading", false)
        }
        keyClick(Qt.Key_Escape)
    }
    // Feedback: while loading, "Stop" (spinner, text, Esc) fits its button —
    // nothing spills behind the auto-refresh button.
    function test_32_stopButtonFits() {
        Session.search()                                  // no scripted answer: stays loading
        tryCompare(Session, "loading", true)
        const stop = H.find(window.contentItem, it => it.Accessible.name === "Остановить загрузку" && H.isShown(it))
        verify(stop)
        waitForRendering(window.contentItem)
        for (const it of H.findAll(stop.contentItem, it => H.isShown(it) && it.width > 0)) {
            const p = it.mapToItem(stop, 0, 0)
            verify(p.x >= 0 && p.x + it.width <= stop.width + 0.5, `${it} ends at ${p.x + it.width} > ${stop.width}`)
        }
        const auto = H.find(window.contentItem, it => String(it.Accessible.name).indexOf("Автообновление") === 0 && H.isShown(it))
        verify(stop.mapToItem(root(), 0, 0).x + stop.width <= auto.mapToItem(root(), 0, 0).x)
        harness.completeLast(5)
        tryCompare(Session, "loading", false)
    }
}
