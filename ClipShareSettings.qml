import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "clipShare"
    property string appliedRecordShortcut: "Shift+Print"
    property string pendingRecordShortcut: ""

    function syncRecordShortcut() {
        const value = loadValue("recordShortcut", "Shift+Print")
        if (!keybindProcess.running && value !== appliedRecordShortcut) {
            pendingRecordShortcut = value
            keybindProcess.command = ["bash", Qt.resolvedUrl("scripts/clipshare-keybind").toString().replace("file://", ""), value]
            keybindProcess.running = true
        }
    }

    Component.onCompleted: Qt.callLater(function() {
        appliedRecordShortcut = loadValue("recordShortcut", "Shift+Print")
    })
    onSettingChanged: Qt.callLater(syncRecordShortcut)

    Process {
        id: keybindProcess
        running: false
        property string errorText: ""

        stderr: StdioCollector {
            onStreamFinished: keybindProcess.errorText = text.trim()
        }

        onRunningChanged: {
            if (running)
                errorText = ""
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                root.appliedRecordShortcut = root.pendingRecordShortcut
                ToastService.showInfo("Recording shortcut updated")
            } else {
                root.saveValue("recordShortcut", root.appliedRecordShortcut)
                ToastService.showError(errorText || "Could not update recording shortcut")
            }
            root.pendingRecordShortcut = ""
        }
    }

    StyledText {
        width: parent.width
        text: "ClipShare"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Choose how recordings are compressed and where progress appears."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "compressionMode"
        label: "Compression mode"
        description: "Balanced is faster with a small quality tradeoff. Best quality is slower. Fast GPU prioritizes speed."
        defaultValue: "balanced"
        options: [
            { label: "Best quality", value: "best" },
            { label: "Balanced", value: "balanced" },
            { label: "Fast GPU", value: "gpu" }
        ]
    }

    SelectionSetting {
        settingKey: "uploadMode"
        label: "Upload mode"
        description: "Catbox only copies the direct video URL. Catbox + Autocompressor creates a short embed link with a thumbnail."
        defaultValue: "embed"
        options: [
            { label: "Catbox + Autocompressor", value: "embed" },
            { label: "Catbox only", value: "catbox" }
        ]
    }

    StringSetting {
        settingKey: "recordShortcut"
        label: "Start/stop recording shortcut"
        description: "Niri shortcut syntax, such as Shift+Print or Mod+Print. Existing shortcuts cannot be replaced."
        defaultValue: "Shift+Print"
    }

    StringSetting {
        settingKey: "recordingDirectory"
        label: "Recording folder"
        description: "Use an absolute path or a path starting with ~/. The folder is created automatically."
        defaultValue: "~/Videos/ClipShare"
    }

    StringSetting {
        settingKey: "copyShortcut"
        label: "Copy shortcut"
        description: "One key, such as Enter or C."
        defaultValue: "Enter"
    }

    StringSetting {
        settingKey: "compressShortcut"
        label: "Compress shortcut"
        description: "One key, such as Space or K."
        defaultValue: "Space"
    }

    StringSetting {
        settingKey: "shareShortcut"
        label: "Share shortcut"
        description: "Two keys joined by +, such as Space+Enter."
        defaultValue: "Space+Enter"
    }

    StringSetting {
        settingKey: "discardShortcut"
        label: "Discard shortcut"
        description: "One key, such as Escape or Delete."
        defaultValue: "Escape"
    }

    SelectionSetting {
        settingKey: "progressPosition"
        label: "Progress position"
        description: "The corner used by the non-blocking progress HUD."
        defaultValue: "top-right"
        options: [
            { label: "Top right", value: "top-right" },
            { label: "Top left", value: "top-left" },
            { label: "Bottom right", value: "bottom-right" },
            { label: "Bottom left", value: "bottom-left" }
        ]
    }
}
