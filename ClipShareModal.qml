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

    layerNamespace: "dms:plugins:clipShare"
    keepPopoutsOpen: true
    closeOnEscapeKey: false
    closeOnBackgroundClick: false
    modalWidth: 500
    modalHeight: 290
    shouldHaveFocus: true

    function openFor(path, sizeBytes) {
        videoPath = path
        videoSizeBytes = sizeBytes
        state = "ready"
        if (daemon)
            daemon.compressionError = ""
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
        state = "compressing"
        daemon.startLocalCompression(videoPath, (success, path, sizeBytes) => {
            if (path) {
                videoPath = path
                videoSizeBytes = sizeBytes
            }
            if (success)
                closePanel()
            else
                state = "ready"
        })
    }

    function compressionLabel() {
        if (state !== "compressing")
            return "Compress below 10 MB"
        if (daemon && daemon.compressionStage === "checking")
            return "Checking recording..."
        if (daemon && daemon.compressionStage === "copying-file")
            return "Copying compressed recording..."
        return "Compressing recording - " + (daemon ? daemon.compressionProgress : 0) + "%"
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
                if (event.key === Qt.Key_Escape) {
                    root.discardRecording()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.copyOriginal()
                    event.accepted = true
                } else if (event.key === Qt.Key_Space) {
                    root.compressRecording()
                    event.accepted = true
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
                            text: "Enter"
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
                    height: 64
                    radius: Theme.cornerRadius
                    color: compressArea.containsMouse ? Theme.surfaceHover : Theme.surfaceVariantAlpha
                    opacity: root.state === "ready" || root.state === "compressing" ? 1 : 0.6

                    StyledText {
                        anchors.left: parent.left
                        anchors.right: compressShortcut.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        text: root.compressionLabel()
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
                            text: "Space"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 4
                        radius: 2
                        visible: root.state === "compressing"
                        color: Theme.surfaceContainerHigh

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, (root.daemon ? root.daemon.compressionProgress : 0) / 100))
                            height: parent.height
                            radius: parent.radius
                            color: Theme.primary
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
                    text: root.daemon && root.daemon.compressionError ? root.daemon.compressionError : "Esc discards this recording."
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.daemon && root.daemon.compressionError ? Theme.error : Theme.surfaceVariantText
                    elide: Text.ElideRight
                }
            }
        }
    }
}
