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
