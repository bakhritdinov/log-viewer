.pragma library
// Item lookup for scenario tests (visual children, control content and popups).

function children(item) {
    const out = []
    if (item.children) for (let i = 0; i < item.children.length; ++i) out.push(item.children[i])
    if (item.contentItem && item.contentItem !== item && out.indexOf(item.contentItem) < 0) out.push(item.contentItem)
    return out
}

function findAll(item, predicate, out) {
    out = out || []
    if (!item) return out
    if (predicate(item)) out.push(item)
    for (const c of children(item)) findAll(c, predicate, out)
    return out
}

// The window's data with the screens and sheets the phone design builds on
// first use (Main's Lazy loaders) built, so a test finds every popup.
function contentData(window) {
    const out = []
    for (let i = 0; i < window.contentData.length; ++i) {
        const d = window.contentData[i]
        out.push(d && typeof d.get === "function" && d.hasOwnProperty("sourceComponent") ? d.get() : d)
    }
    return out
}

function find(item, predicate) {
    return findAll(item, predicate)[0] || null
}

function visibleText(item, text) {
    return find(item, it => it.visible && it.text === text && isShown(it))
}

function isShown(item) {
    for (let it = item; it; it = it.parent) if (!it.visible) return false
    return true
}

// The window's root item: content and popups (overlay) both live under it.
function windowRoot(window) {
    let item = window.contentItem
    while (item.parent) item = item.parent
    return item
}

// Controls a screen reader could not announce: buttons, fields and click
// areas, shown, with neither an accessible name nor text. Returns
// descriptions ("Type at x,y") for a readable failure. `accessibleName(item)`
// comes from the test: attached properties are not visible to a library script.
function unnamedControls(root, accessibleName) {
    const out = []
    findAll(root, it => {
        if (!isShown(it) || it.width <= 0 || it.height <= 0) return false
        const button = it.hasOwnProperty("pressed") && it.hasOwnProperty("checkable") && it.hasOwnProperty("autoRepeat")
        const field = it.hasOwnProperty("cursorPosition") && it.hasOwnProperty("readOnly") && !it.readOnly
        const clickArea = it.hasOwnProperty("pressed") && it.hasOwnProperty("containsMouse") && it.hasOwnProperty("acceptedButtons")
                          && it.enabled && !it.hasOwnProperty("checkable")
        if (!button && !field && !clickArea) return false
        if (clickArea) {
            // A click area inside a named control is fine (the control is announced).
            for (let p = it.parent; p; p = p.parent) if (accessibleName(p)) return false
            if (it.cursorShape === Qt.SizeHorCursor || it.cursorShape === Qt.SizeVerCursor) return false   // resize handles
            return !accessibleName(it)
        }
        const name = accessibleName(it) || it.text || it.placeholderText || ""
        return String(name).trim() === ""
    }).forEach(it => {
        const p = it.mapToItem(null, 0, 0)
        out.push(String(it).replace(/_QMLTYPE_\d+/, "").replace(/\(0x[0-9a-f]+\)/, "") + " at " + Math.round(p.x) + "," + Math.round(p.y))
    })
    return out
}
