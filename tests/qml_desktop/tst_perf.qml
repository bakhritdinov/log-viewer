import QtQuick
import QtTest
import LogViewer.App
import "Helpers.js" as H

// 5 000 entries and more, shaped like a busy service (see Harness::realisticRows):
// each step is timed and printed ("PERF <step> <ms>"), and fails only past a
// budget several times what a developer machine needs, so CI stays green on a
// slow runner while a regression by an order of magnitude does not.
TestCase {
    name: "DesktopPerf"
    when: windowShown

    property var window

    function rows() { return H.findAll(window.contentItem, it => it.hasOwnProperty("timeText") && it.hasOwnProperty("anchored") && H.isShown(it)) }
    function table() { return H.find(window.contentItem, it => it.Accessible && it.Accessible.name === "Логи" && it.hasOwnProperty("contentY")) }
    function idle() { return !Session.loading && !Session.analyzing }

    // Runs `fn`, waits for `done` and a rendered frame; prints and checks the time.
    function measure(step, budgetMs, fn, done) {
        const t0 = Date.now()
        fn()
        const deadline = t0 + Math.max(budgetMs, 5000)
        while (!done() && Date.now() < deadline) wait(5)
        verify(done(), step + ": total=" + Session.logs.totalCount + " loading=" + Session.loading + " analyzing=" + Session.analyzing
               + " rows=" + rows().length + " requests=" + harness.requestCount + " error=" + Session.error.title)
        waitForRendering(window.contentItem)
        const ms = Date.now() - t0
        console.log("PERF desktop " + step + " " + ms + " ms")
        verify(ms <= budgetMs, step + ": " + ms + " ms, budget " + budgetMs + " ms")
        return ms
    }

    function initTestCase() {
        const component = Qt.createComponent("LogViewer.Desktop", "Main")
        verify(component.status === Component.Ready, component.errorString())
        window = component.createObject(null, { width: 1440, height: 900 })
        verify(window)
    }
    function cleanupTestCase() { window.destroy() }
    // DelegateModel::cancel: Qt's note when a reset lands while rows are still being created.
    function init() { failOnWarning(/^(?!.*(qt\.qpa\.fonts|Populating font|DelegateModel::cancel)).*$/) }

    function test_01_first5000() {
        harness.scriptStartup(0)          // discovery; the empty answer is replaced below
        harness.start()
        tryVerify(() => harness.requestCount === 3 && !Session.loading && !Session.discovering, 5000)
        harness.scriptRealisticLogs(5000)
        measure("load-5000", 3000, () => Session.search(), () => Session.logs.totalCount === 5000 && idle() && rows().length > 10)
    }

    function test_02_pages() {
        const count = Session.logs.pageCount
        verify(count > 1, "pages: " + count)
        measure("page-last", 500, () => Session.logs.goToPage(count - 1), () => Session.logs.page === count - 1)
        measure("page-first", 500, () => Session.logs.goToPage(0), () => Session.logs.page === 0)
        const t0 = Date.now()
        for (let p = 1; p < Math.min(count, 21); ++p) { Session.logs.goToPage(p); waitForRendering(window.contentItem) }
        console.log("PERF desktop page-step-avg " + Math.round((Date.now() - t0) / Math.min(count - 1, 20)) + " ms")
        Session.logs.goToPage(0)
    }

    function test_03_scrollPage() {
        const list = table()
        verify(list)
        const t0 = Date.now()
        let frames = 0
        for (let y = 0; y < list.contentHeight - list.height; y += list.height / 4) {
            list.contentY = y
            waitForRendering(window.contentItem)
            ++frames
        }
        const avg = Math.round((Date.now() - t0) / Math.max(frames, 1))
        console.log("PERF desktop scroll-frame-avg " + avg + " ms (" + frames + " frames)")
        verify(avg < 100, "scroll frame " + avg + " ms")
        list.contentY = 0
    }

    function test_04_keyboardThroughRows() {
        mouseClick(rows().find(r => r.index === 0))
        compare(Session.selectedRow, 0)
        const t0 = Date.now()
        for (let i = 0; i < 150; ++i) keyClick(Qt.Key_Down)   // across a page boundary, details open
        waitForRendering(window.contentItem)
        const avg = (Date.now() - t0) / 150
        console.log("PERF desktop key-down-avg " + avg.toFixed(1) + " ms")
        verify(Session.selectedEntry.valid)
        verify(avg < 40, "Down " + avg + " ms")
        keyClick(Qt.Key_Escape)
    }

    function test_05_levelFilter() {
        const total = Session.logs.totalCount
        measure("level-error", 1000, () => Session.applyLevelFilter("ERROR"), () => Session.logs.totalCount < total && idle())
        measure("level-off", 1000, () => Session.applyLevelFilter("ERROR"), () => Session.logs.totalCount === total && idle())
    }

    function test_06_histogramBucket() {
        const total = Session.logs.totalCount
        measure("bucket", 1000, () => Session.applyBucketFilter(Math.floor(Session.histogram.count / 2)), () => Session.logs.totalCount < total && idle())
        measure("bucket-off", 1000, () => Session.clearHistogramFilter(), () => Session.logs.totalCount === total && idle())
    }

    function test_07_patterns() {
        measure("patterns-on", 3000, () => { Session.patternsEnabled = true }, () => Session.patterns.count > 0 && idle())
        measure("patterns-off", 1000, () => { Session.patternsEnabled = false }, () => rows().length > 10)
    }

    function test_08_fieldFilter() {
        const total = Session.logs.totalCount
        harness.scriptRealisticLogs(5000)
        measure("field-filter-search", 3000, () => Session.toggleFilter("pod", "billing-api-7d9f8-x2k4"),
                () => Session.logs.totalCount === 5000 && idle() && rows().length > 10)
        harness.scriptRealisticLogs(5000)
        measure("clear-search", 3000, () => Session.clearSearch(), () => Session.chips.count === 0 && idle() && Session.logs.totalCount === total)
    }

    function test_09_loadMoreTo20000() {
        for (let total = 10000; total <= 20000; total += 5000) {
            if (!Session.hasMore) skip("no more to load")
            harness.scriptRealisticOlder(5000, total - 5000)
            measure("load-more-" + total, 3000, () => Session.loadMore(), () => Session.logs.totalCount === total && idle())
        }
    }

    function test_10_patternsAt20000() {
        measure("patterns-on-20000", 6000, () => { Session.patternsEnabled = true }, () => Session.patterns.count > 0 && idle())
        Session.patternsEnabled = false
        tryVerify(() => rows().length > 10)
    }

    function test_11_refreshKeepsShown() {
        harness.scriptRealisticLogs(5000)
        measure("refresh-5000", 3000, () => Session.search(), () => Session.logs.totalCount === 5000 && idle())
    }
}
