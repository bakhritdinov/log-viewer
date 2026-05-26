import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import LogViewerApp

// Pop-out details viewer for a single ecotone_error_messages row.
//
// Used from ReplayFifoGroupDialog where the parent dialog is too small to
// fit headers + payload alongside the preview list. The window is reused
// across row clicks — properties are reassigned, no new instance per click.
Window {
    id: win
    width: 1100
    height: 640
    minimumWidth: 600
    minimumHeight: 400
    title: qsTr("Message — %1").arg(messageId || "—")
    flags: Qt.Window

    color: Theme.bg

    property string messageId:        ""
    property string failedAt:         ""
    property string channel:          ""
    property string contractId:       ""
    property string payload:          ""
    property string headers:          ""
    property string replayStatus:     ""
    property int    replayRequestId:  0

    EcotoneDetailsPane {
        anchors.fill: parent
        anchors.margins: Theme.sp2
        messageId:        win.messageId
        failedAt:         win.failedAt
        channel:          win.channel
        contractId:       win.contractId
        payload:          win.payload
        headers:          win.headers
        replayStatus:     win.replayStatus
        replayRequestId:  win.replayRequestId
    }
}
