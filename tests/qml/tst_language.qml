import QtQuick
import QtTest
import LogViewer.App
import LogViewer.Ui

// Runs in the language picked by the harness: texts are translated, fit
// their controls on a phone-width screen, and follow a runtime switch.
Item {
    id: host
    width: 390
    height: 844

    readonly property var expected: ({
        ru: { yesterday: "Вчера", apply: "Применить", lastHour: "Последний 1 час" },
        uz: { yesterday: "Kecha", apply: "Qoʻllash", lastHour: "Oxirgi 1 soat" },
        en: { yesterday: "Yesterday", apply: "Apply", lastHour: "Last 1 hour" },
    })

    function findAll(item, predicate, out) {
        out = out ?? []
        if (predicate(item)) out.push(item)
        const kids = item.children ?? []
        for (let i = 0; i < kids.length; ++i) findAll(kids[i], predicate, out)
        return out
    }
    function presetButtons(grid) { return findAll(grid, it => it.hasOwnProperty("current")) }

    Component { id: phonePresets; TimePresetGrid { width: 358; touch: true } }
    Component { id: desktopPresets; TimePresetGrid { width: 220 } }
    Component { id: phoneForm; AbsoluteRangeForm { width: 358; touch: true } }
    Component { id: legend; LevelLegend { width: 358; touch: true; totals: ({ ERROR: 12345, WARN: 678, INFO: 90123, DEBUG: 4 }) } }

    TestCase {
        name: "Language"
        when: windowShown

        property string startCode

        function initTestCase() { startCode = Language.code }
        function cleanup() { Language.code = startCode }

        function test_activeLanguage() {
            verify(["ru", "uz", "en"].includes(Language.code))
            compare(Language.languages.length, 3)
        }

        function test_textsTranslated() {
            const e = host.expected[Language.code]
            const grid = createTemporaryObject(desktopPresets, host)
            const buttons = presetButtons(grid)
            compare(buttons[3].text, e.lastHour)
            compare(buttons[11].text, e.yesterday)
            const form = createTemporaryObject(phoneForm, host)
            verify(findAll(form, it => it.text === e.apply).length > 0)
        }

        function test_phoneLabelsFit() {
            for (const c of [phonePresets, desktopPresets]) {
                const grid = createTemporaryObject(c, host)
                waitForRendering(grid)
                for (const b of presetButtons(grid))
                    verify(b.contentItem.implicitWidth + b.contentItem.leftPadding <= b.width,
                           `"${b.text}" (${b.contentItem.implicitWidth}) > ${b.width}`)
            }
            const l = createTemporaryObject(legend, host)
            waitForRendering(l)
            verify(l.implicitWidth <= l.width, `legend ${l.implicitWidth} > ${l.width}`)
        }

        function test_runtimeSwitch() {
            const grid = createTemporaryObject(desktopPresets, host)
            for (const code of ["en", "uz", "ru"]) {
                Language.code = code
                // The presets array is rebuilt, so the Repeater recreates its buttons.
                compare(presetButtons(grid)[11].text, host.expected[code].yesterday, code)
            }
        }
    }
}
