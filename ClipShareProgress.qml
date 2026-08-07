import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: root

    property var daemon: null
    property var targetScreen: CompositorService.getFocusedScreen()
    readonly property string position: daemon ? daemon.progressPosition : "top-right"
    readonly property real edgeMargin: Theme.spacingL
    readonly property real topOffset: Theme.barHeight + Theme.spacingM

    screen: targetScreen
    visible: daemon && daemon.operationState !== "idle"
    color: "transparent"
    implicitWidth: 340
    implicitHeight: 96
    mask: Region {
        item: root.daemon && root.daemon.operationState === "error" ? hudCard : null
    }

    anchors {
        top: true
        left: true
    }

    WlrLayershell.namespace: "dms:plugins:clipShare:progress"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    WlrLayershell.margins {
        left: root.position.endsWith("right")
            ? Math.max(root.edgeMargin, (root.screen ? root.screen.width : 1920) - root.width - root.edgeMargin)
            : root.edgeMargin
        top: root.position.startsWith("bottom")
            ? Math.max(root.edgeMargin, (root.screen ? root.screen.height : 1080) - root.height - root.edgeMargin)
            : root.topOffset
    }

    Rectangle {
        id: hudCard
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.96)
        border.width: 1
        border.color: root.daemon && root.daemon.operationState === "error" ? Theme.error : Theme.outline

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankIcon {
                    name: root.daemon && root.daemon.operationState === "error" ? "error"
                        : root.daemon && root.daemon.operationState === "success" ? "check_circle"
                        : "compress"
                    size: Theme.iconSize
                    color: root.daemon && root.daemon.operationState === "error" ? Theme.error : Theme.primary
                }

                Column {
                    width: parent.width - Theme.iconSize - parent.spacing
                    spacing: 2

                    StyledText {
                        width: parent.width
                        text: {
                            if (!root.daemon)
                                return ""
                            if (root.daemon.operationState === "error")
                                return "ClipShare failed - click to retry"
                            if (root.daemon.operationState === "success")
                                return "Recording ready and copied"
                            if (root.daemon.compressionStage === "checking")
                                return "Checking recording..."
                            if (root.daemon.compressionStage === "copying-file")
                                return "Copying compressed recording..."
                            return "Compressing recording - " + root.daemon.compressionProgress + "%"
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: root.daemon && root.daemon.operationState === "error"
                            ? root.daemon.compressionError
                            : root.daemon ? root.daemon.operationFileName : ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.daemon && root.daemon.operationState === "error" ? Theme.error : Theme.surfaceVariantText
                        elide: Text.ElideMiddle
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                visible: root.daemon && root.daemon.operationState === "working"
                color: Theme.surfaceVariant

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (root.daemon ? root.daemon.compressionProgress : 0) / 100))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.daemon && root.daemon.operationState === "error"
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.daemon.reopenFailedOperation()
        }
    }
}
