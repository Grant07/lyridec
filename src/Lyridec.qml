import QtQuick
import "components"
import Quickshell
import qs.Services
import qs.Widgets
import qs.Common
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root
    minWidth: 320
    minHeight: 300
    readonly property real defaultWidth: 440
    readonly property real defaultHeight: 520
    readonly property bool acceptsKeyboardFocus: true
    implicitWidth: 440
    implicitHeight: 520

    Component.onCompleted: LyricsService.clients++
    Component.onDestruction: LyricsService.clients = Math.max(0, LyricsService.clients - 1)

    WindowBlur {
        targetWindow: root.QsWindow.window
        blurEnabled: view.visible && view.opacity > 0 && view.effectsAvailable && view.backgroundOpacity > 0 && view.glassIntensity > 0
        blurWidth: root.width
        blurHeight: root.height
        blurRadius: 24
    }

    LyricsView {
        id: view
        backdropBlur: BlurService.enabled
        glassIntensity: Math.max(0, Math.min(100, root.pluginData.glassIntensity ?? 100)) / 100
        anchors.fill: parent
        service: LyricsService
        focusMode: (root.pluginData.layout ?? "reading") === "focus"
        textSize: Math.max(18, Math.min(44, root.pluginData.textSize ?? 30))
        backgroundOpacity: (root.pluginData.backgroundOpacity ?? 94) / 100
        reducedMotion: root.pluginData.reducedMotion ?? false
        hideWhenIdle: root.pluginData.hideWhenIdle ?? false
        font.family: Theme.fontFamily
        palette.window: Qt.hsla(Theme.surfaceContainer.hslHue, Theme.surfaceContainer.hslSaturation * 0.15, Theme.surfaceContainer.hslLightness, 1)
        palette.windowText: Qt.hsla(Theme.surfaceText.hslHue, Theme.surfaceText.hslSaturation * 0.1, Theme.surfaceText.hslLightness, 1)
        palette.text: Theme.surfaceText
        palette.buttonText: Theme.surfaceText
        palette.placeholderText: Theme.surfaceVariantText
        palette.highlight: Theme.primary
        palette.highlightedText: Theme.primaryText
        palette.button: Theme.surfaceContainerHigh
        palette.base: Theme.surfaceContainerHigh
        palette.mid: Theme.surfaceContainerHighest
        onFocusModeRequested: enabled => root.setData("layout", enabled ? "focus" : "reading")
    }
}
