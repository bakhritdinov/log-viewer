pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Shapes
import LogViewer.App
import LogViewer.Ui

// The Logs section: where, the search with its chips, the distribution in one
// line (tap: Chart), Records / Patterns, and the feed of cards — or, instead of
// the feed, the skeleton, "nothing found" or "the request failed". Entries on
// screen never vanish because of a load or an error.
Item {
    id: root

    signal chartRequested()
    signal settingsRequested()
    signal sourceRequested()
    signal environmentRequested()
    signal periodRequested()
    signal entryRequested(int row)
    signal liveEntryRequested(int row)
    signal patternSortRequested()

    // An entry opened from live tail paused it; closing the entry resumes.
    function resumeLiveAfterEntry() { if (liveView.pauseReason === "entry") liveView.resume() }
    signal notice(string text)
    signal searchRequested()
    signal saveRequested()
    signal addEnvironmentRequested(string name)

    // The environment of an opened link that is not set up here.
    property string missingEnvironment

    function scrollToTop() {
        feed.toStart()
        root.hideOffset = 0
    }

    readonly property bool empty: Session.logs.totalCount === 0
    readonly property bool stopped: Session.loadStopped && !Session.loading

    // The skeleton waits 300 ms: a quick answer must not flash it.
    property bool skeletonDue: false
    readonly property bool firstBatch: Session.loading && root.empty
    onFirstBatchChanged: { skeletonDue = false; if (firstBatch) skeletonTimer.restart() }
    Timer { id: skeletonTimer; interval: 300; onTriggered: root.skeletonDue = root.firstBatch }

    // "setup", "feed", "skeleton", "wait" (the first 300 ms), "failed", "nothing".
    readonly property string view: Session.needsSetup ? "setup"
                                 : !root.empty ? "feed"
                                 : Session.loading ? (root.skeletonDue ? "skeleton" : "wait")
                                 : Session.hasError ? "failed" : "nothing"
    onViewChanged: if (view !== "feed") hideOffset = 0
    readonly property bool patterns: Session.patternsEnabled && view === "feed"
    onPatternsChanged: hideOffset = 0

    function num(n) { return n.toLocaleString(Qt.locale(), "f", 0) }

    // WARN and above per bucket: yellow, red where errors dominate.
    readonly property var trend: {
        void Session.histogramMax                    // re-evaluated with the chart
        const values = [], colors = []
        let max = 1
        for (let i = 0; i < Session.histogram.count; ++i) {
            const b = Session.histogram.get(i)
            values.push(b.important)
            colors.push(b.error > b.warn ? Theme.danger : Theme.warn)
            max = Math.max(max, b.important)
        }
        return { values: values, colors: colors, max: max }
    }

    property real nowMs: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.nowMs = Date.now() }

    // A refresh over shown entries: the ones newer than the old top glow green
    // for 1.5 s; the old cards stay where they were.
    property real previousTopMs: Infinity
    property string previousSource
    // When the shown entries were last fetched without an error ("11:58").
    property string lastOkTime
    Connections {
        target: Session
        function onLoadingChanged() {
            if (Session.loading) {
                const top = Session.logs.totalCount > 0 ? Session.logs.rowData(0).timeMs : NaN
                const source = Session.namespaceName + "/" + Session.app
                root.previousTopMs = !isNaN(top) && source === root.previousSource ? top : Infinity
                root.previousSource = source
            } else {
                if (root.previousTopMs !== Infinity) freshTimer.restart()
                Qt.callLater(() => { if (!Session.hasError && !Session.loading) root.lastOkTime = Qt.formatTime(new Date(), "HH:mm") })
            }
        }
    }
    Timer { id: freshTimer; interval: 1500; onTriggered: root.previousTopMs = Infinity }

    // ── the header: slides away while scrolling down, back on the way up ──
    property real hideOffset: 0
    property real lastFeedY: 0
    Connections {
        target: feed
        function onContentYChanged() {
            const y = feed.contentY - feed.originY + feed.topMargin   // 0 at the top
            const delta = y - root.lastFeedY
            root.lastFeedY = y
            root.hideOffset = y <= 0 ? 0 : Math.max(0, Math.min(header.height, root.hideOffset + delta))
        }
    }
    readonly property real headerBottom: header.y + header.height

    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        y: -root.hideOffset
        z: 2
        height: headerColumn.implicitHeight
        color: Theme.bg

        ColumnLayout {
            id: headerColumn
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            AppBar {
                Layout.fillWidth: true
                onSourceRequested: root.sourceRequested()
                onEnvironmentRequested: root.environmentRequested()
            }

            // Search and the active conditions; a running line under it while loading.
            Rectangle {
                Layout.fillWidth: true
                visible: !Session.needsSetup
                implicitHeight: searchColumn.implicitHeight + 18
                color: Theme.surface
                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.border }
                ColumnLayout {
                    id: searchColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 2
                    spacing: 8
                    // The query; tapping opens the search screen, a long press saves it.
                    AbstractButton {
                        id: searchRow
                        Layout.fillWidth: true
                        implicitHeight: 44
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Search: %1").arg(Session.searchText !== "" ? Session.searchText : qsTr("all entries"))
                        onClicked: root.searchRequested()
                        onPressAndHold: if (Session.namespaceName !== "") root.saveRequested()
                        background: Rectangle {
                            radius: Theme.radiusLg
                            color: searchRow.pressed ? Theme.subtle : Theme.inputBg
                            border.width: 1
                            border.color: Session.searchError !== "" ? Theme.danger : Theme.border
                        }
                        contentItem: RowLayout {
                            spacing: 8
                            Icon { Layout.leftMargin: 12; name: "search"; size: 18; color: Theme.textMuted }
                            Text {
                                Layout.fillWidth: true
                                text: Session.searchText !== "" ? Session.searchText : qsTr("Word, key:value…")
                                elide: Text.ElideRight
                                font.family: Theme.mono
                                font.pixelSize: 16
                                color: Session.searchText !== "" ? Theme.textStrong : Theme.textDisabled
                            }
                            IconButton {
                                visible: Session.searchText !== ""
                                touch: true
                                iconName: "close"
                                label: qsTr("Clear the search")
                                onClicked: Session.clearSearch()
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: Session.searchError !== ""
                        text: Session.searchError
                        wrapMode: Text.Wrap
                        font.family: Theme.sans
                        font.pixelSize: Theme.fontSm
                        color: Theme.dangerText
                    }
                    // Period first, then the conditions; scrolls sideways, never wraps.
                    // What does not fit: a fade on the right and "+N".
                    Item {
                        id: chipsBox
                        Layout.fillWidth: true
                        implicitHeight: 32
                        Flickable {
                            id: chipsFlick
                            anchors.fill: parent
                            implicitHeight: 32
                            contentWidth: chipsRow.implicitWidth
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            Row {
                                id: chipsRow
                                spacing: 6
                                AbstractButton {
                                    id: periodChip
                                    implicitHeight: 32
                                    implicitWidth: periodRow.implicitWidth + 20
                                    Accessible.name: qsTr("Period: %1").arg(Session.timeRangeLabel)
                                    onClicked: root.periodRequested()
                                    background: Rectangle {
                                        radius: 16
                                        color: periodChip.pressed ? Theme.hover : Theme.subtle
                                        border.width: 1
                                        border.color: Theme.border
                                    }
                                    contentItem: Item {
                                        Row {
                                            id: periodRow
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Icon { anchors.verticalCenter: parent.verticalCenter; name: "clock"; size: 14; color: Theme.textStrong }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: Session.timeRangeShortLabel
                                                font.family: Theme.sans
                                                font.pixelSize: Theme.fontMd
                                                font.weight: Font.Medium
                                                color: Theme.textStrong
                                            }
                                            Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevronDown"; size: 12; color: Theme.textMuted }
                                        }
                                    }
                                }
                                FilterChipBar {
                                    id: chipBar
                                    touch: true
                                    model: Session.chips
                                    onRemoveRequested: index => Session.removeChip(index)
                                    // Tapping a chip edits the query.
                                    TapHandler { onTapped: root.searchRequested() }
                                }
                            }
                        }
                        readonly property int hiddenChips: {
                            void chipsFlick.contentX; void chipsFlick.width; void chipsRow.implicitWidth
                            let n = 0
                            for (let i = 0; i < chipBar.children.length; ++i) {
                                const c = chipBar.children[i]
                                if (!c.hasOwnProperty("exclude")) continue
                                if (c.mapToItem(chipsFlick, 0, 0).x + c.width > chipsFlick.width + 1) ++n
                            }
                            return n
                        }
                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: moreLabel.implicitWidth + 40
                            visible: chipsBox.hiddenChips > 0
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Theme.tint(Theme.surface, 0) }
                                GradientStop { position: 0.45; color: Theme.surface }
                            }
                            Text {
                                id: moreLabel
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "+" + chipsBox.hiddenChips
                                font.family: Theme.sans
                                font.pixelSize: Theme.fontMd
                                font.weight: Font.DemiBold
                                color: Theme.textMuted
                            }
                            TapHandler { onTapped: root.searchRequested() }
                        }
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 3
                    visible: Session.loading
                    color: Theme.subtle
                    clip: true
                    Accessible.role: Accessible.ProgressBar
                    Accessible.name: qsTr("Loading logs")
                    Rectangle {
                        id: runner
                        width: parent.width / 3
                        height: parent.height
                        color: Theme.accent
                        XAnimator on x {
                            running: Session.loading
                            loops: Animation.Infinite
                            from: -runner.width
                            to: root.width
                            duration: 1200
                        }
                    }
                }
            }

            // WARN and ERROR over the period in one line; tap opens the chart.
            AbstractButton {
                Layout.fillWidth: true
                visible: root.view === "skeleton" || (root.view === "feed" && root.trend.values.length > 0)
                implicitHeight: 34
                Accessible.name: qsTr("WARN and ERROR over the period, open the chart")
                enabled: root.view === "feed"
                onClicked: root.chartRequested()
                leftPadding: 12
                rightPadding: 12
                topPadding: 8
                bottomPadding: 4
                background: null
                contentItem: Item {
                    Sparkline {
                        anchors.fill: parent
                        visible: root.view === "feed"
                        values: root.trend.values
                        colors: root.trend.colors
                        maxValue: root.trend.max
                    }
                    Row {
                        anchors.fill: parent
                        visible: root.view === "skeleton"
                        spacing: 1
                        Repeater {
                            model: 48
                            delegate: Skeleton {
                                required property int index
                                anchors.bottom: parent.bottom
                                width: (parent.width - 47) / 48
                                height: parent.height * (0.3 + 0.25 * Math.abs(Math.sin(index / 4)))
                                radius: 1
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.topMargin: 4
                Layout.bottomMargin: 8
                visible: root.view === "feed"
                spacing: 8
                SegmentedControl {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1          // what Live leaves
                    touch: true
                    fill: true
                    accessibleName: qsTr("Results view")
                    model: [
                        { label: qsTr("Records · %1").arg(root.num(Session.logs.loadedCount) + (Session.loading ? "…" : "")), value: false },
                        { label: Session.loading ? qsTr("Patterns · …")
                               : Session.patterns.count > 0 ? qsTr("Patterns · %1").arg(Session.patterns.count) : qsTr("Patterns"), value: true },
                    ]
                    value: Session.patternsEnabled
                    onActivated: v => Session.patternsEnabled = v
                }
                // The order of the patterns (their tab only).
                IconButton {
                    visible: Session.patternsEnabled
                    touch: true
                    iconName: "sort"
                    label: qsTr("Sort the patterns")
                    onClicked: root.patternSortRequested()
                }
                AppButton {
                    id: liveButton
                    touch: true
                    text: "Live"
                    onClicked: Session.live.start()
                    implicitWidth: liveRow.implicitWidth + leftPadding + rightPadding
                    contentItem: Row {
                        id: liveRow
                        spacing: 6
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: Theme.danger }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: liveButton.text
                            font: liveButton.font
                            color: liveButton._fg
                        }
                    }
                }
            }

            // Opened from a share link: what it is, save it or go back. Or why it
            // did not open (its environment is not set up here).
            Rectangle {
                id: linkCard
                readonly property bool missing: root.missingEnvironment !== ""
                readonly property color tint: missing ? Theme.warn : Theme.variable
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.topMargin: root.view === "feed" ? 0 : 12
                Layout.bottomMargin: 8
                visible: missing || Session.openedFromLink
                implicitHeight: linkColumn.implicitHeight + 24
                radius: Theme.radiusLg
                color: Theme.tint(tint, 0.1)
                border.width: 1
                border.color: Theme.tint(tint, 0.45)
                Accessible.role: missing ? Accessible.AlertMessage : Accessible.StatusBar
                Accessible.name: linkText.text
                ColumnLayout {
                    id: linkColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10
                    RowLayout {
                        spacing: 10
                        Icon { Layout.alignment: Qt.AlignTop; name: linkCard.missing ? "warning" : "link"; size: 18; color: linkCard.tint }
                        Text {
                            id: linkText
                            Layout.fillWidth: true
                            textFormat: Text.StyledText
                            text: linkCard.missing
                                  ? qsTr("The link leads to the environment %1, which is not set up here").arg("<b>" + root.missingEnvironment + "</b>")
                                  : qsTr("From a link:") + "<br><b>" + [Session.environmentName, Session.app, Session.timeRangeLabel].join(" · ") + "</b>"
                            wrapMode: Text.Wrap
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontLg
                            color: Theme.textStrong
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        AppButton {
                            Layout.fillWidth: true
                            touch: true
                            variant: "primary"
                            text: linkCard.missing ? qsTr("Add the environment") : qsTr("Save")
                            onClicked: linkCard.missing ? root.addEnvironmentRequested(root.missingEnvironment) : root.saveRequested()
                        }
                        AppButton {
                            Layout.fillWidth: true
                            touch: true
                            text: linkCard.missing ? qsTr("Close") : qsTr("Back to mine")
                            onClicked: linkCard.missing ? root.missingEnvironment = "" : Session.dismissLinkBanner()
                        }
                    }
                }
            }

            ErrorBanner {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.topMargin: root.view === "feed" ? 0 : 12
                Layout.bottomMargin: 8
                visible: active && !Session.needsSetup
                touch: true
                error: Session.error
                onActionTriggered: action => {
                    switch (action) {
                    case ErrorInfo.Retry: Session.retry(); break
                    case ErrorInfo.OpenSettings: root.settingsRequested(); break
                    case ErrorInfo.NarrowRange: Session.narrowRange(); break
                    case ErrorInfo.CopyCorsHint: clipboard.copy(Session.corsHint()); root.notice(qsTr("Copied")); break
                    case ErrorInfo.CopyDetails: clipboard.copy(Session.error.detail); root.notice(qsTr("Copied")); break
                    case ErrorInfo.EditQuery: root.searchRequested(); break
                    }
                }
            }
            // The cards below are from before the error.
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.bottomMargin: 8
                visible: Session.hasError && root.view === "feed" && root.lastOkTime !== ""
                text: qsTr("Showing the data of the last successful request · %1").arg(root.lastOkTime)
                wrapMode: Text.Wrap
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
        }
    }

    // ── instead of the feed ──
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.headerBottom
        anchors.bottom: loadStrip.visible ? loadStrip.top : parent.bottom
        visible: root.view !== "feed"

        SetupGuide {
            anchors.fill: parent
            visible: root.view === "setup"
            onSettingsRequested: root.settingsRequested()
        }

        // The first batch: cards drawn as grey bars.
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            topPadding: 50
            spacing: 8
            visible: root.view === "skeleton"
            Accessible.role: Accessible.ProgressBar
            Accessible.name: qsTr("Loading logs")
            Repeater {
                model: [[0.9, 0.6], [0.8, 0.45], [0.95, 0.7], [0.7, 0.5], [0.85, 0.4]]
                delegate: Rectangle {
                    id: skeletonCard
                    required property var modelData
                    width: parent.width
                    height: 78
                    radius: Theme.radiusLg
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.borderMuted
                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        Row {
                            spacing: 8
                            Skeleton { width: 70 }
                            Skeleton { width: 40 }
                        }
                        Skeleton { width: parent.width * skeletonCard.modelData[0] }
                        Skeleton { width: parent.width * skeletonCard.modelData[1] }
                    }
                }
            }
        }

        // Nothing found: why, and the ways out that fit (as on the desktop).
        Item {
            id: nothing
            anchors.fill: parent
            visible: root.view === "nothing"
            readonly property bool noSource: Session.namespaceName === ""
            readonly property bool byInterval: Session.histogramFilterActive
            readonly property bool bySearch: Session.chips.count > 0
            readonly property var lastChip: bySearch ? Session.chips.get(Session.chips.count - 1) : null
            readonly property bool wide: ["1d", "2d", "7d"].indexOf(Session.timeRangeKey) >= 0
            EmptyState {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 24
                touch: true
                iconName: nothing.noSource ? "source" : "search"
                title: nothing.noSource ? qsTr("Choose a source")
                     : nothing.byInterval ? qsTr("Nothing in the picked interval")
                     : nothing.bySearch ? qsTr("No entries match")
                     : qsTr("No entries for “%1”").arg(Session.timeRangeLabel)
                message: nothing.noSource ? qsTr("Pick a namespace and an app to see their logs.")
                       : nothing.byInterval ? qsTr("%1 holds no entries of this level.").arg(Session.histogramFilterLabel)
                       : nothing.bySearch ? qsTr("Over “%1” %2 has no lines where %3.")
                                            .arg(Session.timeRangeLabel).arg(Session.app).arg(Session.searchText)
                       : qsTr("Nothing came from %1 during this period.").arg(Session.app)
                WideButton {
                    visible: nothing.noSource
                    variant: "primary"
                    text: qsTr("Choose a source")
                    onClicked: root.sourceRequested()
                }
                WideButton {
                    visible: !nothing.noSource && nothing.byInterval
                    text: qsTr("Show the whole period")
                    onClicked: Session.clearHistogramFilter()
                }
                WideButton {
                    visible: !nothing.noSource && !nothing.byInterval && !nothing.wide
                    text: qsTr("Widen to 24 hours")
                    onClicked: Session.setPreset("1d")
                }
                WideButton {
                    visible: !nothing.noSource && !nothing.byInterval && nothing.bySearch
                    text: nothing.lastChip ? qsTr("Remove %1").arg(nothing.lastChip.text) : ""
                    onClicked: Session.removeChip(Session.chips.count - 1)
                }
                WideButton {
                    visible: !nothing.noSource && !nothing.byInterval && Session.chips.count > 1
                    text: qsTr("Clear the search")
                    onClicked: Session.clearSearch()
                }
                WideButton {
                    visible: !nothing.noSource && !nothing.byInterval && !nothing.bySearch
                    text: qsTr("Turn on live tail")
                    onClicked: Session.live.start()
                }
            }
        }

        // The request failed and there is nothing to show (the banner explains).
        Text {
            anchors.centerIn: parent
            visible: root.view === "failed"
            text: qsTr("No entries — the request failed")
            font.family: Theme.sans
            font.pixelSize: Theme.fontLg
            color: Theme.textDisabled
        }
    }

    // ── the feed ──
    ListView {
        id: feed
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: loadStrip.visible ? loadStrip.top : parent.bottom
        visible: root.view === "feed" && !root.patterns
        topMargin: headerColumn.implicitHeight
        leftMargin: 12
        rightMargin: 12
        bottomMargin: 12
        spacing: 8
        clip: true
        model: Session.logs
        boundsBehavior: Flickable.DragOverBounds
        Accessible.role: Accessible.List
        Accessible.name: qsTr("Logs")
        // Until scrolled away, the feed stays at its start (the first card right
        // under the header) while the header or the entries change.
        // positionViewAtBeginning() ignores topMargin, hence contentY.
        property bool pinnedToStart: true
        function toStart() { contentY = originY - topMargin; pinnedToStart = true }
        function keepAtStart() { if (pinnedToStart && !moving) toStart() }
        onMovementEnded: pinnedToStart = contentY - originY + topMargin <= 1
        // Later, not inside a model reset or a layout pass.
        onTopMarginChanged: Qt.callLater(keepAtStart)
        onOriginYChanged: Qt.callLater(keepAtStart)
        onCountChanged: { if (count === 0) pinnedToStart = true; Qt.callLater(keepAtStart) }
        // One growing list: more of the loaded entries as the end comes near.
        onAtYEndChanged: if (atYEnd && Session.logs.canShowMore) Session.logs.showMore()
        Component.onCompleted: Session.logs.progressive = true

        // Pull to refresh: past 72 px, letting go searches again.
        readonly property real pull: Math.max(0, -verticalOvershoot)
        property bool refreshing: false
        onDragEnded: if (pull >= 72 && !Session.loading) { refreshing = true; Session.search() }
        Connections {
            target: Session
            function onLoadingChanged() { if (!Session.loading) feed.refreshing = false }
        }

        header: Item {
            width: ListView.view.width - 24
            height: feed.refreshing ? 56 : 0
            Behavior on height { NumberAnimation { duration: 150 } }
        }
        delegate: LogCard {
            width: ListView.view.width - 24
            highlightTerms: Session.searchTerms
            nowMs: root.nowMs
            lines: Math.max(2, Session.prefs.messageLines)
            fresh: !Session.loading && timeMs > root.previousTopMs
            onClicked: root.entryRequested(index)
            required property var model
            service: Session.prefs.showService ? model.service : ""
            fields: { void Session.logs.totalCount; return Session.prefs.extraColumns.map(f => ({ key: f, value: Session.logs.fieldText(index, f) })).filter(f => f.value !== "") }
        }
        // The end of what is loaded: more from the server, or that's all.
        footer: Column {
            width: ListView.view.width - 24
            visible: !Session.loading && !Session.logs.canShowMore && Session.logs.totalCount > 0
            height: visible ? implicitHeight : 0
            topPadding: 16
            bottomPadding: 8
            spacing: 10
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                text: Session.hasMore
                      ? qsTr("Showing all %1 loaded · the period has more")
                            .arg("<font color=\"%1\">%2</font>".arg(Theme.text).arg(root.num(Session.logs.totalCount)))
                      : qsTr("These are all the entries of the period")
                font.family: Theme.sans
                font.pixelSize: Theme.fontSm
                color: Theme.textMuted
            }
            AppButton {
                width: parent.width
                visible: Session.hasMore && !root.stopped
                touch: true
                text: qsTr("Load %1 more").arg(root.num(Session.loadStep))
                onClicked: Session.loadMore()
            }
            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                active: root.lastFeedY > 2 * feed.height
                sourceComponent: ToTopButton { }
            }
        }
    }

    // Patterns instead of the records.
    PatternsList {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.headerBottom
        anchors.bottom: loadStrip.visible ? loadStrip.top : parent.bottom
        visible: root.patterns
        onNotice: (text, actionText, action) => root.notice(text)
    }

    // Live tail covers the section while it runs.
    LiveView {
        id: liveView
        anchors.fill: parent
        z: 5
        visible: Session.live.running
        onEntryRequested: row => root.liveEntryRequested(row)
    }

    // Pull to refresh: an arc that closes as the feed is pulled, then spins.
    Column {
        id: pullIndicator
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.headerBottom + (feed.refreshing ? 10 : Math.min(feed.pull, 96) - 46)
        z: 1
        spacing: 6
        visible: root.view === "feed" && !root.patterns && (feed.pull > 8 || feed.refreshing)
        opacity: feed.refreshing ? 1 : Math.min(1, feed.pull / 48)
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 36; height: 36; radius: 18
            color: Theme.subtle
            border.width: 1
            border.color: Theme.border
            Shape {
                id: arc
                anchors.centerIn: parent
                width: 18; height: 18
                preferredRendererType: Shape.CurveRenderer
                RotationAnimator on rotation {
                    running: feed.refreshing
                    loops: Animation.Infinite
                    from: 0; to: 360; duration: 900
                    onRunningChanged: if (!running) arc.rotation = 0
                }
                ShapePath {
                    strokeColor: Theme.accent
                    strokeWidth: 2.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 9; centerY: 9
                        radiusX: 7.5; radiusY: 7.5
                        startAngle: -90
                        sweepAngle: feed.refreshing ? 270 : 300 * Math.min(1, feed.pull / 72)
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !feed.refreshing
            text: feed.pull >= 72 ? qsTr("Release to refresh") : qsTr("Pull to refresh")
            font.family: Theme.sans
            font.pixelSize: Theme.fontSm
            color: Theme.textMuted
        }
    }

    // After two screens down: back to the top (at the very end, in the footer).
    Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: feed.bottom
        anchors.bottomMargin: 12
        z: 1
        active: root.view === "feed" && root.lastFeedY > 2 * feed.height && !feed.atYEnd
        sourceComponent: ToTopButton { }
    }

    component ToTopButton: AbstractButton {
        id: toTop
        implicitHeight: 32
        implicitWidth: toTopRow.implicitWidth + 24
        Accessible.name: qsTr("To the top")
        onClicked: root.scrollToTop()
        background: Rectangle {
            radius: 16
            color: toTop.pressed ? Theme.hover : Theme.subtle
            border.width: 1
            border.color: Theme.border
        }
        contentItem: Item {
            Row {
                id: toTopRow
                anchors.centerIn: parent
                spacing: 6
                // Text, not an Icon: a curve-rendered shape scrolled inside the
                // clipped feed left a stray copy behind (Qt 6.8).
                Text { anchors.verticalCenter: parent.verticalCenter; text: "↑"; font.family: Theme.sans; font.pixelSize: Theme.fontMd; color: Theme.text }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("To the top")
                    font.family: Theme.sans
                    font.pixelSize: Theme.fontMd
                    color: Theme.text
                }
            }
        }
    }

    // Loading in batches (only while it goes), or stopped with a way on.
    Rectangle {
        id: loadStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !root.empty && (Session.loading || root.stopped)
        implicitHeight: 52
        color: Theme.surface
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: Theme.border }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            spacing: 10
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: root.stopped
                      ? qsTr("Stopped at %1").arg(root.num(Session.logs.loadedCount))
                      : qsTr("Loaded %1").arg("<font color=\"%1\">%2</font>".arg(Theme.textStrong).arg(root.num(Session.logs.loadedCount)))
                font.family: Theme.sans
                font.pixelSize: Theme.fontMd
                color: root.stopped ? Theme.warnText : Theme.text
            }
            AppButton {
                implicitHeight: 36
                text: root.stopped ? qsTr("Continue") : qsTr("Stop")
                onClicked: root.stopped ? Session.loadMore() : Session.stopLoading()
            }
        }
    }

    Clipboard { id: clipboard }

    component Skeleton: Rectangle {
        implicitHeight: 10
        radius: Theme.radiusSm
        color: Theme.subtle
        SequentialAnimation on opacity {
            running: Session.loading
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { from: 0.45; to: 0.85; duration: 700 }
            NumberAnimation { from: 0.85; to: 0.45; duration: 700 }
        }
    }

    component WideButton: AppButton {
        width: parent ? parent.width : 0
        touch: true
    }
}
