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
        text: "Choose where compression and upload progress appears while you continue using the desktop."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
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
