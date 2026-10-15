import QtQuick
import QtTest
import LogViewer.App
import "../qml_desktop/Helpers.js" as H

// The search screen, saved queries and sharing over a fake Grafana.
TestCase {
    name: "MobileSearch"
    when: windowShown

    property var window

    function root() { return H.windowRoot(window) }
    // Popups live in the window's data until they open.
    function popup(prop) {
        for (let i = 0; i < window.contentData.length; ++i)
            if (window.contentData[i] && window.contentData[i].hasOwnProperty(prop)) return window.contentData[i]
        return null
    }
    function screen() { return popup("textBefore") }
    function byName(name) { return H.find(root(), it => it.Accessible && it.Accessible.name === name && H.isShown(it)) }
    function shownText(text) { return H.visibleText(root(), text) }
    function searchRow() { return H.find(window.contentItem, it => it.Accessible && String(it.Accessible.name).startsWith("Поиск:") && H.isShown(it)) }

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
            tryCompare(p, "visible", false)            // the closing animation ends too
        }
    }

    // Clicks after the layout settled (a new section moves the ones below).
    function tap(item) { waitForRendering(window.contentItem); mouseClick(item) }

    function openScreen() {
        tap(searchRow())
        tryCompare(screen(), "opened", true)
    }

    function test_01_tapOpensTheScreen() {
        openScreen()
        verify(shownText("Сохранить текущий"))
        verify(shownText("Поделиться"))
    }

    function test_02_fieldThenValueSearches() {
        openScreen()
        Session.searchText = "lev"
        tryVerify(() => byName("level:"))                      // a field suggestion row
        tap(byName("level:"))
        compare(Session.searchText, "level:")
        verify(screen().opened)                                // a field only completes the text
        tryVerify(() => byName("error"))
        harness.scriptLogs(4)
        tap(byName("error"))
        tryCompare(screen(), "opened", false)                  // a value searches and goes back
        tryCompare(Session.logs, "totalCount", 4, 3000)
        compare(Session.appliedSearchText, "level:\"error\"")
    }

    function test_03_symbolsAndFind() {
        openScreen()
        Session.searchText = "timeout"
        tap(byName("Минус (исключить)"))
        compare(Session.searchText, "timeout-")
        Session.searchText = "timeout"
        harness.scriptLogs(3)
        tap(byName("Найти"))
        tryCompare(screen(), "opened", false)
        tryCompare(Session.logs, "totalCount", 3, 3000)
    }

    function test_04_badQueryKeepsTheScreen() {
        openScreen()
        Session.searchText = "service:\"billing"
        tap(byName("Найти"))
        verify(screen().opened)
        verify(Session.searchError !== "")
        harness.scriptLogs(2)
        tap(byName("Закрыть кавычку"))
        tryCompare(screen(), "opened", false)
        compare(Session.appliedSearchText, "service:\"billing\"")
        tryCompare(Session.logs, "totalCount", 2, 3000)
    }

    function test_05_cancelRestoresTheText() {
        const before = Session.searchText
        openScreen()
        Session.searchText = "something else"
        tap(byName("Отмена"))
        tryCompare(screen(), "opened", false)
        compare(Session.searchText, before)
    }

    function test_06_saveAndReplace() {
        const sheet = popup("renameId")
        sheet.openSaving()
        tryCompare(sheet, "opened", true)
        tap(byName("Сохранить"))
        tryCompare(Session.savedQueries, "count", 1)
        tryCompare(sheet, "opened", false)
        // The same name again: the button replaces that query.
        const name = Session.savedQueries.get(0).name
        sheet.openSaving()
        tryCompare(sheet, "opened", true)
        const field = H.find(root(), it => it.Accessible && it.Accessible.name === "Имя запроса" && H.isShown(it))
        field.text = name
        tryVerify(() => shownText("Заменит запрос № 1"))
        verify(byName("Заменить"))
        tap(byName("Заменить"))
        tryCompare(sheet, "opened", false)
        compare(Session.savedQueries.count, 1)
    }

    function test_07_savedQueryActions() {
        openScreen()
        Session.searchText = ""
        const id = Session.savedQueries.get(0).id
        tap(byName("Действия с «%1»".arg(Session.savedQueries.get(0).name)))
        const sheet = popup("queryId")
        tryCompare(sheet, "opened", true)
        compare(sheet.queryId, id)
        tap(byName("Удалить"))
        tryCompare(Session.savedQueries, "count", 0)
        tryVerify(() => byName("Вернуть"))                     // the snackbar, over the search screen
        tap(byName("Вернуть"))
        tryCompare(Session.savedQueries, "count", 1)
    }

    function test_08_share() {
        const sheet = popup("fixedRange")
        sheet.open()
        tryCompare(sheet, "opened", true)
        verify(sheet.link.length > 0)
        tap(byName("Копировать"))
        tryCompare(sheet, "opened", false)
        tryVerify(() => shownText("Ссылка скопирована"))
    }

    function test_09_chipsThatDoNotFit() {
        harness.scriptLogs(12)
        Session.searchText = "timeout AND level:error AND -pod:canary AND region:eu AND provider:visa"
        Session.search()
        tryCompare(Session, "loading", false)
        tryVerify(() => H.find(window.contentItem, it => it.text !== undefined && /^\+\d$/.test(String(it.text)) && H.isShown(it)))
    }
}
