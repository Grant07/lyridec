import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    pluginId: "lyridec"

    SelectionSetting {
        settingKey: "layout"
        label: "Layout"
        options: [{ label: "Reading", value: "reading" }, { label: "Focus", value: "focus" }]
        defaultValue: "reading"
    }
    SliderSetting {
        settingKey: "textSize"
        label: "Lyric size"
        minimum: 18; maximum: 44; defaultValue: 30
        unit: "px"
    }
    SliderSetting {
        settingKey: "backgroundOpacity"
        label: "Background opacity"
        minimum: 0; maximum: 100; defaultValue: 94
        unit: "%"
    }
    SliderSetting {
        settingKey: "glassIntensity"
        label: "Glass intensity"
        minimum: 0; maximum: 100; defaultValue: 100
        unit: "%"
    }
    ToggleSetting {
        settingKey: "reducedMotion"
        label: "Reduce motion"
        defaultValue: false
    }
    ToggleSetting {
        settingKey: "hideWhenIdle"
        label: "Hide when Spotify has no track"
        defaultValue: false
    }
}
