import QtQuick
import QtTest
import LogViewer.App
import "../qml_desktop/Helpers.js" as H

// Accessibility of the phone design: every control is named for TalkBack /
// VoiceOver, and touch targets are at least 44 px (filter chips: 32 px tall).
TestCase {
    name: "MobileA11y"
    when: windowShown

    property var window

    function root() { return H.windowRoot(window) }
    function sheets() {
        const out = []
        for (let i = 0; i < window.contentData.length; ++i) {
            const p = window.contentData[i]
            if (p && p.hasOwnProperty("closePolicy") && typeof p.open === "function") out.push(p)
        }
        return out
    }

    function initTestCase() {
        const component = Qt.createComponent("LogViewer.Mobile", "Main")
        verify(component.status === Component.Ready, component.errorString())
        window = component.createObject(null)
        verify(window)
        harness.scriptStartup(30)
        harness.start()
        tryCompare(Session.logs, "totalCount", 30, 3000)
        tryCompare(Session, "loading", false)
        waitForRendering(window.contentItem)
    }
    function cleanupTestCase() { window.destroy() }
    function cleanup() {
        for (const p of sheets()) if (p.opened) { p.close(); tryCompare(p, "visible", false) }
        window.section = 0
    }

    function unnamed(scope) { return H.unnamedControls(scope, it => it.Accessible ? it.Accessible.name : "") }
    // A chip in a sideways-scrolling row (period, conditions, environments).
    function inChipRow(it) {
        for (let p = it.parent; p; p = p.parent)
            if (p.hasOwnProperty("flickableDirection") && p.flickableDirection === Flickable.HorizontalFlick) return true
        return false
    }
    // Buttons smaller than a finger: under 44 × 44 px; chips under 32 px tall.
    function smallTargets(scope) {
        return H.findAll(scope, it => it.hasOwnProperty("pressed") && it.hasOwnProperty("checkable") && it.hasOwnProperty("autoRepeat")
                                      && H.isShown(it) && it.width > 0 && it.enabled)
            .filter(it => it.width < 44 || it.height < (inChipRow(it) ? 32 : 44))
            .map(it => (it.Accessible.name || it.text) + " " + Math.round(it.width) + "×" + Math.round(it.height))
    }
    function audit(where, scope) {
        scope = scope || root()
        waitForRendering(window.contentItem)
        compare(unnamed(scope).join("
"), "", where + ": unnamed")
        compare(smallTargets(scope).join("
"), "", where + ": small targets")
    }

    function test_logs() { audit("logs") }
    function test_chart() { window.section = 1; audit("chart") }
    function test_settings() { window.section = 2; audit("settings") }
    function test_details() {
        const card = H.find(window.contentItem, it => it.hasOwnProperty("ago") && it.hasOwnProperty("timeMs") && H.isShown(it))
        mouseClick(card)
        wait(400)
        const details = sheets().find(p => p.hasOwnProperty("canOpenFocus") && p.opened)
        verify(details)
        audit("details", details.contentItem)
    }
    function test_sheets() {
        const done = []
        for (const p of sheets()) {
            if (p.hasOwnProperty("canOpenFocus") || p.hasOwnProperty("serviceCount")) continue   // details / focus: own tests
            p.open()
            wait(400)
            if (!p.opened) continue
            done.push(p.title || String(p))
            audit(p.title || String(p), p.contentItem)
            p.close()
            tryCompare(p, "visible", false)
        }
        console.log("sheets audited: " + done.join(", "))
        verify(done.length >= 4, done.join(", "))
    }
}
