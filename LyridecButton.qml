import QtQuick
import QtQuick.Controls

ToolButton {
    id: root
    property string symbol: ""
    property string label: ""
    property bool selected: false
    readonly property var paths: ({
        more: "M12 4.5 V5 M12 11.75 V12.25 M12 19 V19.5", close: "M6 6 L18 18 M18 6 L6 18",
        search: "M16 16 L21 21 M18 10 A8 8 0 1 1 2 10 A8 8 0 1 1 18 10",
        minus: "M5 12 H19", plus: "M5 12 H19 M12 5 V19"
    })
    implicitWidth: symbol ? 36 : Math.max(44, caption.implicitWidth + 24)
    implicitHeight: 36
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: label
    ToolTip.text: label
    ToolTip.visible: hovered && symbol !== ""
    ToolTip.delay: 600
    background: Rectangle {
        radius: 10
        color: root.down || root.selected ? root.palette.mid : root.hovered ? root.palette.button : "transparent"
        border.width: root.visualFocus ? 2 : 0
        border.color: root.palette.highlight
        opacity: root.enabled ? 1 : 0.4
    }
    contentItem: Item {
        opacity: root.enabled ? 1 : 0.4
        Image {
            anchors.centerIn: parent
            width: 20; height: 20
            visible: root.symbol !== ""
            source: visible ? "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="'
                    + (root.paths[root.symbol] || root.paths.more) + '" fill="none" stroke="' + root.palette.windowText
                    + '" stroke-width="' + (root.symbol === "more" ? 3.5 : 1.8) + '" stroke-linecap="round" stroke-linejoin="round"/></svg>') : ""
        }
        Text {
            id: caption
            anchors.centerIn: parent
            visible: !root.symbol
            text: root.label
            textFormat: Text.PlainText
            font: root.font
            color: root.palette.windowText
        }
    }
}
