import QtQuick
import Quickshell

ShellRoot {
    Loader {
        source: Quickshell.env("LYRIDEC_SMOKE") === "1" ? "tests/integration/ServiceSmoke.qml" : "tests/visual/Preview.qml"
    }
}
