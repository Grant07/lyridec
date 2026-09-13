import QtQuick
import Quickshell
import ".." as Lyridec

// Synthetic lyric content; no network and no playback changes.
ShellRoot {
    id: harness
    property int step: 0
    readonly property string scene: scenes[Math.min(step, scenes.length - 1)]
    property string output: Quickshell.env("LYRIDEC_CAPTURE_DIR")
    property var scenes: ["reading", "controls", "focus", "details", "search", "loading", "missing", "error", "instrumental", "idle", "light", "minimum", "minimum-loading", "minimum-error", "glass-off", "glass-mid", "glass-full"]

    QtObject {
        id: fake
        property string key: "preview"
        property bool playing: true
        property var track: ({ title: "A little closer", artist: "lyridec · synthetic preview", duration: 224 })
        property string artwork: Quickshell.env("LYRIDEC_PREVIEW_ART")
        property real position: 48
        property int offset: 0
        property var document: ({ synced: true, source: "Local · preview.lrc", lines: [
            {time:0, text:"The city settles into blue"}, {time:18000, text:"And every window holds a view"},
            {time:36000, text:"Let the evening take its time"}, {time:48000, text:"Stay a little closer"},
            {time:64000, text:"There’s a world between the lines"}, {time:80000, text:"And a little room for you"}
        ] })
        property string state: "ready"
        property string message: ""
        property string storageMessage: ""
        property bool cached: false
        property bool hasOverride: true
        property string searchState: "ready"
        property string searchMessage: ""
        property var results: [{trackName:"A little closer", artistName:"Evening Rooms", albumName:"Window Seat", duration:224, syncedLyrics:"demo"},
            {trackName:"A little closer (Live)", artistName:"Evening Rooms", albumName:"After Hours", duration:260, plainLyrics:"demo"}]
        function seek(ms) { position = (ms - offset) / 1000; }
        function setOffset(value) { offset = value; }
        function search(query) { }
        function choose(record) { }
        function clearOverride() { }
        function importLyrics(url) { }
        function resolve(force) { }
    }

    FloatingWindow {
        id: window
        visible: true
        title: "lyridec preview"
        implicitWidth: view.width + 80
        implicitHeight: view.height + 80
        color: "#181c1a"
        Lyridec.LyricsView {
            id: view
            x: 40; y: 40
            layer.enabled: harness.output !== ""
            width: harness.scene.startsWith("minimum") ? 320 : harness.scene === "focus" ? 340 : 440
            height: harness.scene.startsWith("minimum") ? 300 : harness.scene === "focus" ? 360 : 520
            glassIntensity: harness.scene === "glass-off" ? 0 : harness.scene === "glass-mid" ? 0.5 : 1
            service: fake
            font.family: "Inter"
            reducedMotion: true
            palette.window: "#19191d"
            palette.windowText: "#e5e5ed"
            palette.text: "#e2e8e2"
            palette.buttonText: "#e2e8e2"
            palette.placeholderText: "#bac7bd"
            palette.highlight: "#b4d4a8"
            palette.highlightedText: "#183820"
            palette.button: "#2a332d"
            palette.base: "#2a332d"
            palette.mid: "#364339"
            onFocusModeRequested: enabled => focusMode = enabled
        }
    }

    Timer {
        interval: 800
        running: harness.output !== ""
        repeat: true
        onTriggered: {
            view.keyboardNavigation = harness.scene === "controls";
            if (Quickshell.env("LYRIDEC_REQUIRE_GPU") === "1" && !view.glassReady) {
                console.error("Glass shader did not compile on the graphics renderer");
                Qt.exit(1);
                return;
            }
            view.grabToImage(result => {
                if (!result.saveToFile(harness.output + "/" + harness.scenes[harness.step] + ".png"))
                    throw new Error("Screenshot could not be saved");
                harness.step++;
                if (harness.step === harness.scenes.length) { console.log("LYRIDEC_PREVIEW_PASS"); Qt.quit(); return; }
                const scene = harness.scenes[harness.step];
                view.keyboardNavigation = scene === "controls";
                fake.playing = scene !== "idle";
                fake.key = scene === "idle" ? "" : "preview";
                fake.state = ["loading", "missing", "error", "instrumental", "idle"].includes(scene) ? scene
                    : scene === "minimum-loading" ? "loading" : scene === "minimum-error" ? "error" : "ready";
                fake.message = fake.state === "error" ? "Could not reach LRCLIB. Check your connection and try again." : "";
                if (fake.state !== "ready") fake.document = {synced:false, source:"", lines:[]};
                view.page = ["details", "search"].includes(scene) ? scene : "lyrics";
                view.focusMode = scene === "focus";
                if (scene.startsWith("glass-")) {
                    view.palette.window = "#19191d"; view.palette.windowText = "#e5e5ed";
                    view.palette.placeholderText = "#bac7bd"; view.palette.highlight = "#b4d4a8";
                    view.palette.mid = "#364339"; view.palette.button = "#2a332d";
                    fake.document = {synced:true, source:"Preview", lines:[
                        {time:0, text:"Let the evening take its time"}, {time:48000, text:"Stay a little closer"},
                        {time:64000, text:"There’s a world between the lines"}]};
                }
                if (scene === "light") {
                    fake.document = {synced:true, source:"Preview", lines:[
                        {time:0, text:"Let the evening take its time"}, {time:48000, text:"Stay a little closer"},
                        {time:64000, text:"There’s a world between the lines"}]};
                    view.palette.window = "#f1f5ed"; view.palette.windowText = "#222b24";
                    view.palette.placeholderText = "#48574b"; view.palette.highlight = "#3e6235";
                    view.palette.mid = "#c7d2c5"; view.palette.button = "#dce5d8";
                }
                if (scene === "search") view.openSearch();
                if (scene === "minimum") {
                    fake.document = { synced:true, source:"Preview", lines:[
                        {time:0, text:"A longer phrase that wraps naturally across the smallest desktop widget"},
                        {time:48000, text:"Karibu nyumbani — welcome home"}, {time:64000, text:"世界は静かに歌う"}] };
                }
                if (scene === "idle") { fake.key = ""; fake.state = "idle"; fake.playing = false; }
                Qt.callLater(view.follow);
            });
        }
    }
}
