import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "clipShare"

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
