import QtQuick
import Quickshell

ShellRoot {
    Loader {
        source: Quickshell.env("LYRIDEC_SMOKE") === "1" ? "tests/ServiceSmoke.qml" : "tests/Preview.qml"
    }
}
