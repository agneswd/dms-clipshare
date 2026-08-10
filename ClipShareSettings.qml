import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import "./dms-common"

PluginSettings {
    id: root
    pluginId: "clipShare"
    property string appliedRecordShortcut: "Shift+Print"
    property string pendingRecordShortcut: ""

    function syncRecordShortcut() {
        const value = loadValue("recordShortcut", "Shift+Print")
        if (!keybindProcess.running && value !== appliedRecordShortcut) {
            pendingRecordShortcut = value
            const provider = CompositorService.isHyprland ? "hyprland" : CompositorService.isMango ? "mangowc" : "niri"
            keybindProcess.command = ["bash", Qt.resolvedUrl("scripts/clipshare-keybind").toString().replace("file://", ""), value, provider]
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
                ToastService.showInfo(I18n.tr("Recording shortcut updated"))
            } else {
                root.saveValue("recordShortcut", root.appliedRecordShortcut)
                ToastService.showError(errorText || I18n.tr("Could not update recording shortcut"))
            }
            root.pendingRecordShortcut = ""
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Recording")
            icon: "videocam"
            showReset: compressionMode.isDirty || compressionLimitMb.isDirty || recordShortcut.isDirty || recordingDirectory.isDirty
            onResetClicked: {
                compressionMode.resetToDefault()
                compressionLimitMb.resetToDefault()
                recordShortcut.resetToDefault()
                recordingDirectory.resetToDefault()
            }
        }

        SelectionSettingPlus {
            id: compressionMode
            settingKey: "compressionMode"
            label: I18n.tr("Compression Mode")
            description: I18n.tr("Balanced is faster with a small quality tradeoff. Best quality is slower. Fast GPU prioritizes speed.")
            defaultValue: "balanced"
            options: [
                { label: I18n.tr("Best Quality"), value: "best" },
                { label: I18n.tr("Balanced"), value: "balanced" },
                { label: I18n.tr("Fast GPU"), value: "gpu" }
            ]
        }

        Separator {}

        SliderSettingPlus {
            id: compressionLimitMb
            settingKey: "compressionLimitMb"
            label: I18n.tr("Compression Size Limit")
            description: I18n.tr("Recordings below this size are copied without recompression. Larger recordings are compressed below the limit.")
            defaultValue: 10
            minimum: 1
            maximum: 100
            unit: "MB"
            leftLabel: "1 MB"
            rightLabel: "100 MB"
        }

        Separator {}

        StringSettingPlus {
            id: recordShortcut
            settingKey: "recordShortcut"
            label: I18n.tr("Start or Stop Recording Shortcut")
            description: I18n.tr("Use Niri, Hyprland, or MangoWC shortcut syntax, such as Shift+Print or Mod+Print. Existing shortcuts cannot be replaced.")
            defaultValue: "Shift+Print"
        }

        Separator {}

        StringSettingPlus {
            id: recordingDirectory
            settingKey: "recordingDirectory"
            label: I18n.tr("Recording Folder")
            description: I18n.tr("Use an absolute path or a path starting with ~/. The folder is created automatically.")
            defaultValue: "~/Videos/ClipShare"
            isDirectory: true
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Sharing and Shortcuts")
            icon: "share"
            showReset: uploadMode.isDirty || copyShortcut.isDirty || compressShortcut.isDirty || shareShortcut.isDirty || discardShortcut.isDirty
            onResetClicked: {
                uploadMode.resetToDefault()
                copyShortcut.resetToDefault()
                compressShortcut.resetToDefault()
                shareShortcut.resetToDefault()
                discardShortcut.resetToDefault()
            }
        }

        SelectionSettingPlus {
            id: uploadMode
            settingKey: "uploadMode"
            label: I18n.tr("Upload Mode")
            description: I18n.tr("Catbox only copies the direct video URL. Catbox with Autocompressor creates a short embed link with a thumbnail.")
            defaultValue: "embed"
            options: [
                { label: I18n.tr("Catbox with Autocompressor"), value: "embed" },
                { label: I18n.tr("Catbox Only"), value: "catbox" }
            ]
        }

        Separator {}

        StringSettingPlus {
            id: copyShortcut
            settingKey: "copyShortcut"
            label: I18n.tr("Copy Shortcut")
            description: I18n.tr("Use one key, such as Enter or C.")
            defaultValue: "Enter"
        }

        Separator {}

        StringSettingPlus {
            id: compressShortcut
            settingKey: "compressShortcut"
            label: I18n.tr("Compress Shortcut")
            description: I18n.tr("Use one key, such as Space or K.")
            defaultValue: "Space"
        }

        Separator {}

        StringSettingPlus {
            id: shareShortcut
            settingKey: "shareShortcut"
            label: I18n.tr("Share Shortcut")
            description: I18n.tr("Use two keys joined by +, such as Space+Enter.")
            defaultValue: "Space+Enter"
        }

        Separator {}

        StringSettingPlus {
            id: discardShortcut
            settingKey: "discardShortcut"
            label: I18n.tr("Discard Shortcut")
            description: I18n.tr("Use one key, such as Escape or Delete.")
            defaultValue: "Escape"
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Progress Display")
            icon: "picture_in_picture_alt"
            showReset: progressPosition.isDirty
            onResetClicked: progressPosition.resetToDefault()
        }

        SelectionSettingPlus {
            id: progressPosition
            settingKey: "progressPosition"
            label: I18n.tr("Progress Position")
            description: I18n.tr("Choose the corner used by the non-blocking progress display.")
            defaultValue: "top-right"
            options: [
                { label: I18n.tr("Top Right"), value: "top-right" },
                { label: I18n.tr("Top Left"), value: "top-left" },
                { label: I18n.tr("Bottom Right"), value: "bottom-right" },
                { label: I18n.tr("Bottom Left"), value: "bottom-left" }
            ]
        }
    }
}
