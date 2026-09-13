import QtQuick
import Quickshell
import "."

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int hold: 0
    property var s: LyricsService
    Component.onCompleted: s.clients++

    function check(condition, message) {
        if (!condition) { console.error("SERVICE_CHECK_FAILED", message); Qt.exit(1); }
    }

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            test.ticks++;
            test.check(test.ticks < 180, "Integration test timed out at phase " + test.phase);
            const s = test.s;
            switch (test.phase) {
            case 0:
                if (s.state !== "ready") return;
                test.check(s.document.lines[0].text === "One words", "API lyrics");
                s.importLyrics("file://" + Quickshell.env("LYRIDEC_TEST_LRC"));
                test.phase++; break;
            case 1:
                if (!s.hasOverride) return;
                test.check(s.document.lines[0].text === "Imported words", "Local LRC import");
                s.setOffset(200);
                test.check(s.offset === 200, "Offset persistence in model");
                s.seek(1200);
                test.phase++; break;
            case 2:
                if (Math.abs(s.position - 1) > 0.1) return;
                s.player.pause();
                test.phase++; break;
            case 3:
                if (s.playing) return;
                s.clearOverride();
                test.phase++; break;
            case 4:
                if (s.state !== "ready" || s.hasOverride) return;
                s.search("alternate");
                test.phase++; break;
            case 5:
                if (s.searchState !== "ready") return;
                test.check(s.results.length === 1, "Search results");
                s.choose(s.results[0]);
                test.check(s.document.lines[0].text === "Alternate words", "Manual match");
                s.player.next();
                test.phase++; break;
            case 6:
                if (s.track.title !== "Slow") return;
                if (++test.hold < 6) return;
                s.player.next();
                test.phase++; break;
            case 7:
                if (s.track.title !== "Fast" || s.state !== "ready") return;
                test.check(s.document.lines[0].text === "Fast words", "New track request");
                test.hold = 0;
                test.phase++; break;
            case 8:
                if (++test.hold < 25) return;
                test.check(s.document.lines[0].text === "Fast words", "Discard stale slow response");
                s.player.next();
                test.phase++; break;
            case 9:
                if (s.state !== "missing") return;
                s.player.next();
                test.phase++; break;
            case 10:
                if (s.state !== "error") return;
                test.check(s.nextRequestAt > Date.now(), "Retry-After cooldown");
                s.resolve(true);
                s.player.next();
                test.phase++; break;
            case 11:
                if (s.track.title !== "Fast" || s.state !== "ready") return;
                test.check(s.cached, "Cached lyrics during provider cooldown");
                s.clients = 0;
                test.check(s.player === null && s.state === "idle", "Stop when last widget closes");
                test.hold = 0;
                test.phase++; break;
            case 12:
                if (++test.hold < 5) return;
                console.log("SERVICE_CHECKS_PASSED");
                Qt.quit(); break;
            }
        }
    }
}
