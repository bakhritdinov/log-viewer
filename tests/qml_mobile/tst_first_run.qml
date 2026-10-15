import QtQuick
import QtTest
import LogViewer.App
import "../qml_desktop/Helpers.js" as H

// No environment configured: the guide is shown and leads to Settings.
TestCase {
    name: "MobileFirstRun"
    when: windowShown

    property var window

    function initTestCase() {
        const component = Qt.createComponent("LogViewer.Mobile", "Main")
        verify(component.status === Component.Ready, component.errorString())
        window = component.createObject(null)
        verify(window)
        harness.start()
        tryCompare(Session, "needsSetup", true)
    }
    function cleanupTestCase() { window.destroy() }
    function init() { failOnWarning(/^(?!.*(qt\.qpa\.fonts|Populating font)).*$/) }

    function test_1_guideShown() {
        tryVerify(() => H.visibleText(window.contentItem, "Подключите Grafana") !== null)
        compare(harness.requestCount, 0)
        // "!" on Settings while nothing is connected.
        verify(H.find(window.contentItem, it => it.text === "!" && H.isShown(it)))
    }

    function test_2_openSettings() {
        mouseClick(H.visibleText(window.contentItem, "Открыть настройки"))
        tryCompare(window, "section", 2)
        tryVerify(() => H.visibleText(window.contentItem, "Подключения") !== null)
    }

    function test_3_chartShowsTheSameGuide() {
        window.section = 0
        waitForRendering(window.contentItem)
        const onLogs = H.visibleText(window.contentItem, "Подключите Grafana").mapToItem(window.contentItem, 0, 0)
        window.section = 1
        waitForRendering(window.contentItem)
        const guide = H.visibleText(window.contentItem, "Подключите Grafana")
        verify(guide)
        // The same place on both tabs: nothing jumps when switching.
        const onChart = guide.mapToItem(window.contentItem, 0, 0)
        compare(Math.round(onChart.y), Math.round(onLogs.y))
        // No step switch over an empty chart.
        verify(!H.find(window.contentItem, it => it.Accessible && it.Accessible.name === "Шаг гистограммы" && H.isShown(it)))
        mouseClick(H.visibleText(window.contentItem, "Открыть настройки"))
        tryCompare(window, "section", 2)
    }
}
