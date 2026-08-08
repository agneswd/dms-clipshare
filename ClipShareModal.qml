import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Widgets

DankModal {
    id: root

    property var daemon: null
    property string videoPath: ""
    property real videoSizeBytes: 0
    property string state: "ready"
    property string errorMessage: ""
    property bool shareFirstPressed: false
    property bool shareSecondPressed: false
    property bool chordHandled: false

    layerNamespace: "dms:plugins:clipShare"
    keepPopoutsOpen: true
    closeOnEscapeKey: false
    closeOnBackgroundClick: false
    modalWidth: 500
    modalHeight: 360
    shouldHaveFocus: true

    function openFor(path, sizeBytes, message) {
        videoPath = path
        videoSizeBytes = sizeBytes
        state = "ready"
        errorMessage = message || ""
        shouldBeVisible = true
        open()
    }

    function closePanel() {
        shouldBeVisible = false
        close()
    }

    function copyOriginal() {
        if (state !== "ready" || !daemon)
            return
        state = "copying"
        daemon.copyLocalFile(videoPath, success => {
            if (success)
                closePanel()
            else
                state = "ready"
        })
    }

    function discardRecording() {
        if (state !== "ready" || !daemon)
            return
        state = "discarding"
        daemon.discardLocalFile(videoPath, success => {
            if (success)
                closePanel()
            else
                state = "ready"
        })
    }

    function compressRecording() {
        if (state !== "ready" || !daemon)
            return
        if (daemon.startLocalCompression(videoPath, videoSizeBytes))
            closePanel()
    }

    function shareRecording() {
        if (state !== "ready" || !daemon)
            return
        if (daemon.startShare(videoPath, videoSizeBytes))
            closePanel()
    }

    function keyCode(name) {
        const clean = String(name || "").trim()
        const aliases = { "Enter": "Return", "Esc": "Escape" }
        const qtName = aliases[clean] || (clean.length === 1 ? clean.toUpperCase() : clean)
        return Qt["Key_" + qtName] || 0
    }

    function shareKeys() {
        const parts = daemon ? daemon.shareShortcut.split("+") : []
        const first = parts.length === 2 ? keyCode(parts[0]) : Qt.Key_Space
        const second = parts.length === 2 ? keyCode(parts[1]) : Qt.Key_Return
        return first && second && first !== second ? [first, second] : [Qt.Key_Space, Qt.Key_Return]
    }

    function formatFileSize(bytes) {
        if (bytes >= 1000000000)
            return (bytes / 1000000000).toFixed(1) + " GB"
        if (bytes >= 1000000)
            return (bytes / 1000000).toFixed(1) + " MB"
        if (bytes >= 1000)
            return (bytes / 1000).toFixed(1) + " KB"
        return bytes + " B"
    }

    onOpened: Qt.callLater(function() {
        if (contentLoader.item)
            contentLoader.item.forceActiveFocus()
    })
    onDialogClosed: shouldBeVisible = false

    content: Component {
        FocusScope {
            id: contentRoot
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.isAutoRepeat) {
                    event.accepted = true
                    return
                }
                const share = root.shareKeys()
                if (event.key === root.keyCode(root.daemon ? root.daemon.discardShortcut : "Escape")) {
                    copyTimer.stop()
                    compressTimer.stop()
                    root.discardRecording()
                    event.accepted = true
                } else {
                    if (event.key === share[0])
                        root.shareFirstPressed = true
                    if (event.key === share[1])
                        root.shareSecondPressed = true
                    if (root.shareFirstPressed && root.shareSecondPressed) {
                        copyTimer.stop()
                        compressTimer.stop()
                        root.chordHandled = true
                        root.shareRecording()
                        event.accepted = true
                    } else if (event.key === root.keyCode(root.daemon ? root.daemon.copyShortcut : "Enter")) {
                        copyTimer.restart()
                        event.accepted = true
                    } else if (event.key === root.keyCode(root.daemon ? root.daemon.compressShortcut : "Space")) {
                        compressTimer.restart()
                        event.accepted = true
                    }
                }
            }

            Keys.onReleased: event => {
                const share = root.shareKeys()
                if (event.key === share[0])
                    root.shareFirstPressed = false
                if (event.key === share[1])
                    root.shareSecondPressed = false
                if (!root.shareFirstPressed && !root.shareSecondPressed)
                    root.chordHandled = false
            }

            Timer {
                id: copyTimer
                interval: 180
                onTriggered: {
                    if (!root.chordHandled)
                        root.copyOriginal()
                }
            }

            Timer {
                id: compressTimer
                interval: 180
                onTriggered: {
                    if (!root.chordHandled)
                        root.compressRecording()
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                StyledText {
                    text: "Recording ready"
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width - sizeLabel.implicitWidth - parent.spacing
                        text: root.videoPath.split("/").pop()
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        elide: Text.ElideMiddle
                    }

                    StyledText {
                        id: sizeLabel
                        text: root.formatFileSize(root.videoSizeBytes)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 56
                    radius: Theme.cornerRadius
                    color: copyArea.containsMouse ? Theme.surfaceHover : Theme.surfaceVariantAlpha
                    opacity: root.state === "ready" ? 1 : 0.6

                    Column {
                        anchors.left: parent.left
                        anchors.right: shortcut.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        spacing: 2

                        StyledText {
                            text: root.state === "copying" ? "Saving and copying recording..."
                                : root.state === "discarding" ? "Discarding recording..."
                                : "Save and copy recording"
                            width: parent.width
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                    }

                    Rectangle {
                        id: shortcut
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        width: keyLabel.implicitWidth + Theme.spacingM
                        height: keyLabel.implicitHeight + Theme.spacingXS
                        radius: Theme.cornerRadiusSmall
                        color: Theme.surfaceContainerHigh

                        StyledText {
                            id: keyLabel
                            anchors.centerIn: parent
                            text: root.daemon ? root.daemon.copyShortcut : "Enter"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: copyArea
                        anchors.fill: parent
                        enabled: root.state === "ready"
                        onClicked: root.copyOriginal()
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 56
                    radius: Theme.cornerRadius
                    color: shareArea.containsMouse ? Theme.surfaceHover : Theme.surfaceVariantAlpha
                    opacity: root.state === "ready" ? 1 : 0.6

                    StyledText {
                        anchors.left: parent.left
                        anchors.right: shareShortcut.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        text: "Upload and copy share link"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: shareShortcut
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        width: shareKeyLabel.implicitWidth + Theme.spacingM
                        height: shareKeyLabel.implicitHeight + Theme.spacingXS
                        radius: Theme.cornerRadiusSmall
                        color: Theme.surfaceContainerHigh

                        StyledText {
                            id: shareKeyLabel
                            anchors.centerIn: parent
                            text: root.daemon ? root.daemon.shareShortcut.split("+").join(" + ") : "Space + Enter"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: shareArea
                        anchors.fill: parent
                        enabled: root.state === "ready"
                        onClicked: root.shareRecording()
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 56
                    radius: Theme.cornerRadius
                    color: compressArea.containsMouse ? Theme.surfaceHover : Theme.surfaceVariantAlpha
                    opacity: root.state === "ready" ? 1 : 0.6

                    StyledText {
                        anchors.left: parent.left
                        anchors.right: compressShortcut.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        text: "Compress below " + (root.daemon ? root.daemon.compressionLimitMb : 10) + " MB"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: compressShortcut
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        width: compressKeyLabel.implicitWidth + Theme.spacingM
                        height: compressKeyLabel.implicitHeight + Theme.spacingXS
                        radius: Theme.cornerRadiusSmall
                        color: Theme.surfaceContainerHigh

                        StyledText {
                            id: compressKeyLabel
                            anchors.centerIn: parent
                            text: root.daemon ? root.daemon.compressShortcut : "Space"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                    }

                    MouseArea {
                        id: compressArea
                        anchors.fill: parent
                        enabled: root.state === "ready"
                        onClicked: root.compressRecording()
                    }
                }

                StyledText {
                    width: parent.width
                    text: root.errorMessage || (root.daemon ? root.daemon.discardShortcut : "Escape") + " discards this recording."
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.errorMessage ? Theme.error : Theme.surfaceVariantText
                    elide: Text.ElideRight
                }
            }
        }
    }
}
