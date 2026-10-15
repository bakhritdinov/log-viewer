import QtQuick
import QtTest
import LogViewer.App
import "Helpers.js" as H

// No environment configured: the guide is shown and leads to the settings.
TestCase {
    name: "FirstRun"
    when: windowShown

    property var window

    function initTestCase() {
        const component = Qt.createComponent("LogViewer.Desktop", "Main")
        verify(component.status === Component.Ready, component.errorString())
        window = component.createObject(null)
        verify(window)
        harness.start()
        tryCompare(Session, "needsSetup", true)
    }
    function cleanupTestCase() { window.destroy() }

    function test_1_guideShown() {
        tryVerify(() => H.visibleText(window.contentItem, "Подключите Grafana") !== null)
        compare(harness.requestCount, 0)
    }

    function test_2_openSettings() {
        const button = H.visibleText(window.contentItem, "Открыть настройки")
        verify(button)
        mouseClick(button)
        const overlay = H.windowRoot(window)
        tryVerify(() => H.visibleText(overlay, "Подключения к Grafana") !== null)
        // The form of the current environment (DEV) is open.
        verify(H.visibleText(overlay, "URL Grafana"))
        keyClick(Qt.Key_Escape)
        tryVerify(() => H.visibleText(overlay, "Подключения к Grafana") === null)
    }
}
