import QtQuick
import QtTest
import LogViewer.App
import "../qml_desktop/Helpers.js" as H

// The phone design with 5 000 entries shaped like a busy service: each step is
// timed and printed ("PERF <step> <ms>") and fails only past a budget several
// times what a developer machine needs (see the desktop's tst_perf.qml).
TestCase {
    name: "MobilePerf"
    when: windowShown

    property var window

    function cards() { return H.findAll(window.contentItem, it => it.hasOwnProperty("ago") && it.hasOwnProperty("timeMs") && H.isShown(it)) }
    function feed() { return H.find(window.contentItem, it => it.hasOwnProperty("pinnedToStart")) }
    function popup(test) {
        for (let i = 0; i < H.contentData(window).length; ++i)
            if (H.contentData(window)[i] && test(H.contentData(window)[i])) return H.contentData(window)[i]
        return null
    }
    function details() { return popup(p => p.hasOwnProperty("canOpenFocus") && p.canOpenFocus) }
    function byName(name) { return H.find(H.windowRoot(window), it => it.Accessible && it.Accessible.name === name && H.isShown(it)) }
    function idle() { return !Session.loading && !Session.analyzing }

    function measure(step, budgetMs, fn, done) {
        const t0 = Date.now()
        fn()
        const deadline = t0 + Math.max(budgetMs, 5000)
        while (!done() && Date.now() < deadline) wait(5)
        verify(done(), step + ": total=" + Session.logs.totalCount + " shown=" + (feed() ? feed().count : -1) + " loading=" + Session.loading
               + " analyzing=" + Session.analyzing + " cards=" + cards().length + " requests=" + harness.requestCount)
        waitForRendering(window.contentItem)
        const ms = Date.now() - t0
        console.log("PERF mobile " + step + " " + ms + " ms")
        verify(ms <= budgetMs, step + ": " + ms + " ms, budget " + budgetMs + " ms")
        return ms
    }

    function initTestCase() {
        const component = Qt.createComponent("LogViewer.Mobile", "Main")
        verify(component.status === Component.Ready, component.errorString())
        window = component.createObject(null)
        verify(window)
    }
    function cleanupTestCase() { window.destroy() }
    // DelegateModel::cancel: Qt's harmless note when a search resets the feed.
    function init() { failOnWarning(/^(?!.*(qt\.qpa\.fonts|Populating font|DelegateModel::cancel)).*$/) }

    function test_01_first5000() {
        harness.scriptStartup(0)
        harness.start()
        tryVerify(() => harness.requestCount === 3 && !Session.loading && !Session.discovering, 5000)
        harness.scriptRealisticLogs(5000)
        measure("load-5000", 3000, () => Session.search(), () => Session.logs.totalCount === 5000 && idle() && cards().length > 3)
    }

    // Flicking down the growing feed: more cards as the end comes near.
    function test_02_scrollThe1000First() {
        const list = feed()
        verify(list)
        const t0 = Date.now()
        let frames = 0
        list.pinnedToStart = false          // as after the user's own flick
        while (list.count < 1000 && Date.now() - t0 < 60000) {
            list.contentY += list.height / 3
            waitForRendering(window.contentItem)
            ++frames
        }
        const avg = (Date.now() - t0) / Math.max(frames, 1)
        console.log("PERF mobile scroll-frame-avg " + avg.toFixed(1) + " ms (" + frames + " frames, " + list.count + " cards)")
        verify(list.count >= 1000, "shown " + list.count + " y=" + list.contentY + " h=" + list.contentHeight + " originY=" + list.originY + " atYEnd=" + list.atYEnd + " canShowMore=" + Session.logs.canShowMore + " height=" + list.height)
        verify(avg < 100, "scroll frame " + avg + " ms")
    }

    function test_03_backToTop() {
        measure("to-top", 1000, () => feed().toStart(), () => feed().pinnedToStart && cards().some(c => c.index === 0))
    }

    function test_04_detailsAndNext() {
        const first = cards().find(c => c.index === 0)
        mouseClick(first)
        tryCompare(details(), "opened", true)
        const next = byName("Следующая запись")
        verify(next)
        const t0 = Date.now()
        for (let i = 0; i < 40; ++i) { mouseClick(next); waitForRendering(window.contentItem) }
        const avg = (Date.now() - t0) / 40
        console.log("PERF mobile details-next-avg " + avg.toFixed(1) + " ms")
        compare(details().row, 40)
        verify(avg < 100, "next " + avg + " ms")
        details().close()
        tryCompare(details(), "visible", false)
    }

    function test_05_chart() {
        measure("chart-section", 1500, () => { window.section = 1 }, () => Session.histogram.count > 0 && idle())
        window.section = 0
        waitForRendering(window.contentItem)
    }

    function test_06_levelFilter() {
        const total = Session.logs.totalCount
        measure("level-error", 1000, () => Session.applyLevelFilter("ERROR"), () => Session.logs.totalCount < total && idle())
        measure("level-off", 1000, () => Session.applyLevelFilter("ERROR"), () => Session.logs.totalCount === total && idle())
    }

    function test_07_patterns() {
        measure("patterns-on", 3000, () => { Session.patternsEnabled = true }, () => Session.patterns.count > 0 && idle())
        measure("patterns-off", 1000, () => { Session.patternsEnabled = false }, () => cards().length > 3)
    }

    function test_08_search() {
        harness.scriptRealisticLogs(5000)
        measure("search-5000", 3000, () => { Session.searchText = "timeout"; Session.search() },
                () => Session.appliedSearchText === "timeout" && Session.logs.totalCount === 5000 && idle() && cards().length > 3)
    }
}
