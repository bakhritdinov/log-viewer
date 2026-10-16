import QtQuick
import QtTest
import LogViewer.App
import "../qml_desktop/Helpers.js" as H

// The Settings section: its screens, the phone's defaults, an environment form.
TestCase {
    name: "MobileSettings"
    when: windowShown

    property var window

    function root() { return H.windowRoot(window) }
    function byName(name) { return H.find(root(), it => it.Accessible && it.Accessible.name === name && H.isShown(it)) }
    function shownText(text) { return H.visibleText(root(), text) }
    function stack() { return H.find(page(), it => it.hasOwnProperty("depth")) }
    // Clicks after a screen has slid in (a click during the transition misses).
    function tap(item) { verify(item); tryVerify(() => !stack().busy); waitForRendering(window.contentItem); mouseClick(item) }
    function page() { return H.find(window.contentItem, it => it.hasOwnProperty("densityLabel")) }
    function stackDepth() { return stack().depth }

    function initTestCase() {
        const component = Qt.createComponent("LogViewer.Mobile", "Main")
        verify(component.status === Component.Ready, component.errorString())
        window = component.createObject(null)
        harness.scriptStartup(12)
        harness.start()
        tryCompare(Session.logs, "totalCount", 12, 3000)
        tryCompare(Session, "loading", false)
        window.section = 2
        waitForRendering(window.contentItem)
    }
    function cleanupTestCase() { window.destroy() }
    // DelegateModel::cancel: Qt's harmless note when a search resets the feed.
    function init() { failOnWarning(/^(?!.*(qt\.qpa\.fonts|Populating font|DelegateModel::cancel)).*$/) }
    function cleanup() {
        page().popToRoot()
        tryVerify(() => stackDepth() === 1)
        window.section = 2
    }

    function test_01_phoneDefaults() {
        compare(Session.prefs.logFontSize, 14)
        compare(Session.prefs.messageLines, 2)
        compare(Session.prefs.loadStep, 1000)
        compare(Session.prefs.liveIntervalMs, 5000)
        // The Behaviour row's value (the group separator may be a no-break space).
        verify(H.find(root(), it => it.text !== undefined && String(it.text).replace(/\s/g, "") === "1000" && H.isShown(it)))
    }

    function test_02_appearanceScreen() {
        tap(byName("Внешний вид"))
        tryVerify(() => stackDepth() === 2)
        tryVerify(() => shownText("Плотность"))
        tap(shownText("Компактно"))
        compare(Session.prefs.density, "compact")
        tap(byName("Подсвечивать ERROR и WARN"))                // the whole row toggles
        verify(Session.prefs.tintRows)
        tap(byName("Настройки"))                                // ‹ Settings
        tryVerify(() => stackDepth() === 1)
        verify(shownText("Тёмная · компактно"))
    }

    function test_03_feedFields() {
        tap(byName("Лента"))
        tryVerify(() => stackDepth() === 2)
        const field = byName("Поле для карточки")
        field.text = "trace_id"
        tap(byName("Добавить поле"))
        compare(Session.prefs.extraColumns, ["trace_id"])
        verify(byName("Фильтр: trace_id"))                      // listed as a chip
        Session.prefs.removeColumn("trace_id")
    }

    function test_04_resetAsks() {
        Session.prefs.loadStep = 20000
        tap(byName("Поведение"))
        tryVerify(() => stackDepth() === 2)
        tap(shownText("Вернуть настройки по умолчанию"))
        tryVerify(() => shownText("Сбросить настройки?"))
        tap(H.find(root(), it => it.text === "Сбросить" && it.hasOwnProperty("variant") && H.isShown(it)))
        tryCompare(Session.prefs, "loadStep", 1000)             // the phone's default again
        tryVerify(() => shownText("Настройки сброшены"))
    }

    function test_05_environmentLeaveAsks() {
        tap(H.find(window.contentItem, it => it.Accessible && it.Accessible.name === "DEV" && it.hasOwnProperty("subtitle") && H.isShown(it)))
        tryVerify(() => stackDepth() === 2)
        const url = byName("URL Grafana")
        tryCompare(url, "text", "https://dev-grafana")
        url.text = "https://other"
        url.textEdited()
        tap(byName("Настройки"))
        tryVerify(() => shownText("Сохранить изменения в DEV?"))
        tap(shownText("Не сохранять"))
        tryVerify(() => stackDepth() === 1)
        compare(Session.environments.get(0).host, "dev-grafana")   // nothing saved
    }

    function test_06_secondTapOnTheTabGoesBackToTheList() {
        tap(byName("Внешний вид"))
        tryVerify(() => stackDepth() === 2)
        tap(H.findAll(window.contentItem, it => it.Accessible && it.Accessible.name === "Настройки" && it.hasOwnProperty("checkable") && H.isShown(it)).pop())
        tryVerify(() => stackDepth() === 1)
    }

    // A device with files (the browser): export and import in "Version and data".
    function test_07_exportAndImport() {
        Session.saveCurrentQuery("Q1")
        harness.plugDevice()
        tap(byName("Версия и данные"))
        tryVerify(() => stackDepth() === 2)
        tap(H.find(root(), it => it.text === "Экспорт" && it.hasOwnProperty("variant") && H.isShown(it)))
        verify(harness.lastSaved.startsWith("logviewer-queries.json|"))
        const json = harness.lastSaved.slice(harness.lastSaved.indexOf("|") + 1)
        Session.removeSavedQuery(Session.savedQueries.get(0).id)
        tap(H.find(root(), it => it.text === "Импорт из файла" && it.hasOwnProperty("variant") && H.isShown(it)))
        compare(harness.fileRequests, 1)
        harness.deliverFile(json)
        tryCompare(Session.savedQueries, "count", 1)
        tryVerify(() => shownText("Добавлен 1 запрос"))
    }
}
