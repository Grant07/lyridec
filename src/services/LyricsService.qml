pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Lyrics.js" as Lyrics

Singleton {
    id: root

    // One service across widget instances: one playback clock, request, and writer.
    property int clients: 0
    readonly property var player: clients > 0 ? Mpris.players.values.find(p =>
        p.dbusName === "org.mpris.MediaPlayer2.spotify"
        || p.dbusName.startsWith("org.mpris.MediaPlayer2.spotify.")) ?? null : null
    readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing
    readonly property var track: ({
        id: player?.uniqueId ?? "",
        title: player?.trackTitle ?? "",
        artist: player?.trackArtist ?? "",
        album: player?.trackAlbum ?? "",
        duration: player?.lengthSupported ? player.length : 0
    })
    readonly property string key: player && track.title ? Lyrics.trackKey(track) : ""
    readonly property string artwork: player?.trackArtUrl ?? ""
    readonly property real position: player?.positionSupported ? player.position : 0
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/lyridec"

    property string state: "idle"
    property string message: ""
    property var document: ({ lines: [], synced: false, source: "" })
    property bool cached: false
    property var results: []
    property string searchState: "idle"
    property string searchMessage: ""
    property string storageMessage: ""
    property var library: ({ version: 1, cache: {}, overrides: {}, offsets: {} })
    property bool storageReady: false
    property bool storageWritable: false
    property int generation: 0
    property var request: null
    property real nextRequestAt: 0
    property string pendingMode: "get"
    property string pendingQuery: ""
    property string importKey: ""
    property string importName: ""
    readonly property int offset: Number(library.offsets[key]) || 0
    readonly property bool hasOverride: !!library.overrides[key]

    onKeyChanged: resetTrack()

    Timer {
        interval: 100
        running: root.playing
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    Process {
        command: ["mkdir", "-p", root.dataDir]
        running: true
        onExited: code => {
            if (code === 0) libraryFile.path = root.dataDir + "/library.json";
            else {
                root.storageReady = true;
                root.storageMessage = "Cannot create the lyrics library. Changes will not be saved.";
                root.resolve();
            }
        }
    }

    FileView {
        id: libraryFile
        printErrors: false
        blockLoading: false
        atomicWrites: true
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                if (saved.version !== 1 || !saved.cache || !saved.overrides || !saved.offsets
                    || Array.isArray(saved.cache) || Array.isArray(saved.overrides)
                    || typeof saved.cache !== "object" || typeof saved.overrides !== "object"
                    || typeof saved.offsets !== "object") throw new Error("Invalid library");
                for (const entry of Object.values(saved.overrides))
                    if (!Lyrics.validDocument(entry)) throw new Error("Invalid saved lyrics");
                root.library = saved;
                root.storageWritable = true;
            } catch (error) {
                root.storageMessage = "Lyrics library is unreadable. Repair or rename library.json to save changes.";
            }
            root.storageReady = true;
            root.resolve();
        }
        onLoadFailed: error => {
            root.storageWritable = error === FileViewError.FileNotFound;
            if (!root.storageWritable)
                root.storageMessage = "Cannot read the lyrics library. Changes will not be saved.";
            root.storageReady = true;
            root.resolve();
        }
        onSaveFailed: error => root.storageMessage = "Could not save lyrics. Check free space and library permissions."
    }

    Timer {
        id: saveTimer
        interval: 250
        onTriggered: if (root.storageWritable) libraryFile.setText(JSON.stringify(root.library))
    }

    Timer {
        id: fetchTimer
        interval: 350
        onTriggered: root.startRequest()
    }

    Timer {
        id: deadline
        interval: 12000
        onTriggered: {
            const mode = root.pendingMode;
            root.cancelRequest();
            root.fail(mode, "Lyrics request timed out. Try again.");
        }
    }

    FileView {
        id: importFile
        printErrors: false
        blockLoading: false
        onLoaded: {
            try {
                const parsed = Lyrics.parse(text(), !root.importName.toLowerCase().endsWith(".txt"));
                if (!parsed.lines.length) throw new Error("This file contains no lyrics.");
                const doc = { lines: parsed.lines, synced: parsed.synced,
                    source: "Local · " + root.importName, instrumental: false };
                if (!Lyrics.validDocument(doc)) throw new Error("This lyric file is too large.");
                root.library.overrides[root.importKey] = doc;
                root.save();
                if (root.importKey === root.key) {
                    root.cancelRequest();
                    root.apply(doc, false);
                }
            } catch (error) { root.message = error.message; }
            path = "";
        }
        onLoadFailed: error => {
            root.message = "Cannot read that lyric file. Choose a readable LRC or text file.";
            path = "";
        }
    }

    function save() {
        library = Object.assign({}, library);
        saveTimer.restart();
    }

    function cancelRequest() {
        generation++;
        fetchTimer.stop();
        deadline.stop();
        if (request) {
            request.onreadystatechange = null;
            request.abort();
            request = null;
        }
    }

    function resetTrack() {
        cancelRequest();
        document = { lines: [], synced: false, source: "" };
        message = "";
        cached = false;
        results = [];
        searchState = "idle";
        searchMessage = "";
        state = key ? "loading" : "idle";
        resolve();
    }

    function apply(doc, fromCache) {
        document = doc;
        cached = fromCache;
        state = doc.instrumental ? "instrumental" : doc.lines.length ? "ready" : "missing";
        message = "";
    }

    function resolve(force) {
        if (!key || !storageReady) return;
        const local = library.overrides[key];
        if (local) { apply(local, false); return; }
        const entry = library.cache[key];
        if (!force && entry && Lyrics.validDocument(entry.document)
            && (entry.document.lines.length || entry.document.instrumental
                || Date.now() - entry.savedAt < 3600000)) {
            apply(entry.document, true);
            return;
        }
        queueRequest("get", "");
    }

    function queueRequest(mode, query) {
        cancelRequest();
        pendingMode = mode;
        pendingQuery = query;
        if (mode === "search") {
            searchState = "loading";
            searchMessage = "";
            if (state === "loading") state = "missing";
        }
        else { state = "loading"; message = ""; }
        if (nextRequestAt - Date.now() > 1000) {
            fail(mode, "Lyrics service is cooling down. Try again after "
                 + new Date(nextRequestAt).toLocaleTimeString() + ".");
            return;
        }
        fetchTimer.interval = Math.max(350, nextRequestAt - Date.now());
        fetchTimer.restart();
    }

    function fail(mode, text) {
        if (mode === "search") { searchState = "error"; searchMessage = text; }
        else { state = "error"; message = text; }
    }

    function startRequest() {
        if (!key) return;
        const token = generation;
        const forKey = key;
        const mode = pendingMode;
        const xhr = new XMLHttpRequest();
        request = xhr;
        xhr.open("GET", "https://lrclib.net/api/" + (mode === "search"
                 ? "search?q=" + encodeURIComponent(pendingQuery) : "get?" + Lyrics.query(track)));
        xhr.setRequestHeader("User-Agent", "lyridec/0.1.0 (+https://github.com/grant07/lyridec)");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || token !== root.generation || forKey !== root.key) return;
            deadline.stop();
            root.request = null;
            root.nextRequestAt = Date.now() + 350;
            if (xhr.status === 429) {
                root.nextRequestAt = Date.now() + Lyrics.retryDelay(xhr.getResponseHeader("Retry-After"), Date.now());
                root.fail(mode, "Lyrics service is busy. Try again after "
                          + new Date(root.nextRequestAt).toLocaleTimeString() + ".");
                return;
            }
            if (xhr.status === 404 && mode === "get") {
                root.remember({ lines: [], synced: false, source: "LRCLIB", instrumental: false });
                return;
            }
            if (xhr.status !== 200) {
                root.fail(mode, xhr.status === 0 ? "Cannot reach LRCLIB. Check your connection and retry."
                          : "LRCLIB returned " + xhr.status + ". Try again later.");
                return;
            }
            try {
                if (xhr.responseText.length > 2097152) throw new Error("The lyrics response is too large.");
                const data = JSON.parse(xhr.responseText);
                if (mode === "search") {
                    if (!Array.isArray(data)) throw new Error("The lyrics search returned an invalid response.");
                    root.results = data.slice(0, 30).filter(record => record && typeof record.trackName === "string"
                        && typeof record.artistName === "string" && (record.syncedLyrics || record.plainLyrics || record.instrumental));
                    root.searchState = "ready";
                    root.searchMessage = root.results.length ? "" : "No matches. Try the song title and artist.";
                } else root.remember(Lyrics.fromRecord(data));
            } catch (error) { root.fail(mode, error.message); }
        };
        deadline.start();
        xhr.send();
    }

    function remember(doc) {
        if (!Lyrics.validDocument(doc)) { fail("get", "The lyrics record is invalid or too large."); return; }
        library.cache[key] = { document: doc, savedAt: Date.now() };
        // ponytail: retain 80 tracks; use per-track files if a larger library is needed.
        const keys = Object.keys(library.cache).sort((a, b) => library.cache[b].savedAt - library.cache[a].savedAt);
        keys.slice(80).forEach(k => delete library.cache[k]);
        save();
        apply(doc, false);
    }

    function search(query) {
        if (!key) return;
        query = query.trim().slice(0, 300);
        if (!query) return;
        results = [];
        queueRequest("search", query);
    }

    function choose(record) {
        try {
            const doc = Lyrics.fromRecord(record);
            if (!Lyrics.validDocument(doc)) throw new Error("This lyric record is too large.");
            cancelRequest();
            library.overrides[key] = doc;
            save();
            apply(doc, false);
        } catch (error) { searchMessage = error.message; }
    }

    function importLyrics(url, targetKey) {
        if (!(targetKey || key) || !storageReady) return;
        const value = url.toString();
        if (!value.startsWith("file:///")) { message = "Choose a local lyric file."; return; }
        const path = decodeURIComponent(value.slice(7));
        if (!/\.(lrc|txt)$/i.test(path)) { message = "Choose an LRC or text file."; return; }
        importKey = targetKey || key;
        importName = path.split("/").pop();
        importFile.path = path;
    }

    function clearOverride() {
        delete library.overrides[key];
        save();
        resolve(true);
    }

    function setOffset(value) {
        if (!key) return;
        library.offsets[key] = Math.max(-10000, Math.min(10000, Math.round(value)));
        save();
    }

    function seek(milliseconds) {
        if (player?.canSeek && document.synced)
            player.position = Math.max(0, Math.min(track.duration || Infinity, (milliseconds - offset) / 1000));
    }
}
