import QtQuick
import qs.Common
import qs.Modals.Common
import qs.Widgets

DankModal {
    id: root

    property var daemon: null
    property string videoPath: ""
    property string state: "ready"

    layerNamespace: "dms:plugins:clipShare"
    keepPopoutsOpen: true
    closeOnEscapeKey: false
    closeOnBackgroundClick: false
    modalWidth: 500
    modalHeight: 210
    shouldHaveFocus: true

    function openFor(path) {
        videoPath = path
        state = "ready"
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

                StyledText {
                    width: parent.width
                    text: root.videoPath.split("/").pop()
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    elide: Text.ElideMiddle
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

                StyledText {
                    width: parent.width
                    text: "Esc discards this recording."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
