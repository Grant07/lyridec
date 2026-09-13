import QtQuick
import Quickshell
import "../../src" as Lyridec

ShellRoot {
    Component.onCompleted: Lyridec.LyricsService.clients++
    Component.onDestruction: Lyridec.LyricsService.clients = Math.max(0, Lyridec.LyricsService.clients - 1)
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            const s = Lyridec.LyricsService;
            if (["ready", "missing", "instrumental", "error"].includes(s.state)) {
                console.log("LYRIDEC_SERVICE", JSON.stringify({ state: s.state, track: s.track.title,
                    synced: s.document.synced, lines: s.document.lines.length, cached: s.cached,
                    position: s.position, message: s.message, storage: s.storageMessage }));
                Qt.exit(s.state === "error" ? 1 : 0);
            }
        }
    }
    Timer {
        interval: 16000
        running: true
        onTriggered: { console.log("LYRIDEC_TIMEOUT", Lyridec.LyricsService.state); Qt.exit(1); }
    }
}
