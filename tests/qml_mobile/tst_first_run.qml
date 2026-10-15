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
}
