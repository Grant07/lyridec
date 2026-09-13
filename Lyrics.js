// Shared data logic: deliberately independent of QML so node can check it.
var maxTextLength = 131072;

function clean(value) {
    return typeof value === "string" ? value.trim() : "";
}

function trackKey(track) {
    return JSON.stringify([clean(track.id) || clean(track.title), clean(track.artist),
                           clean(track.album), Math.round(Number(track.duration) || 0)]);
}

function parse(text, timed) {
    if (typeof text !== "string") throw new Error("Lyrics must be text.");
    if (text.length > maxTextLength)
        throw new Error("Lyrics exceed the 131,072-character limit.");
    text = text.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n");
    var offsetMatch = text.match(/^\s*\[offset:([+-]?\d+)\]\s*$/mi);
    var offset = offsetMatch ? Number(offsetMatch[1]) : 0;
    var lines = [];
    var plain = [];
    text.split("\n").forEach(function (line) {
        if (/^\s*\[(ar|ti|al|by|re|ve|length|offset):.*\]\s*$/i.test(line)) return;
        var stamp = /\[(\d{1,3}):([0-5]\d)(?:[.:](\d{1,3}))?\]/g;
        var times = [], match;
        while ((match = stamp.exec(line)) !== null) {
            times.push(Number(match[1]) * 60000 + Number(match[2]) * 1000
                       + Number((match[3] || "0").padEnd(3, "0")) - offset);
        }
        var words = line.replace(/\[(\d{1,3}):([0-5]\d)(?:[.:](\d{1,3}))?\]/g, "")
                        .replace(/<\d{1,3}:[0-5]\d(?:\.\d{1,3})?>/g, "").trim();
        if (times.length && timed !== false) {
            times.forEach(function (time) { lines.push({ time: Math.max(0, time), text: words }); });
        } else if (words) plain.push({ time: -1, text: words });
    });
    if (!lines.length) return { synced: false, lines: plain };
    lines.sort(function (a, b) { return a.time - b.time; });
    var merged = [];
    lines.forEach(function (line) {
        var last = merged[merged.length - 1];
        if (last && last.time === line.time) {
            if (line.text && last.text !== line.text)
                last.text = last.text ? last.text + "\n" + line.text : line.text;
        } else merged.push(line);
    });
    return { synced: true, lines: merged };
}

function fromRecord(record) {
    if (!record || typeof record !== "object" || Array.isArray(record))
        throw new Error("The lyrics service returned an invalid record.");
    var parsed = parse(record.syncedLyrics || record.plainLyrics || "", !!record.syncedLyrics);
    return { synced: parsed.synced, lines: parsed.lines, instrumental: record.instrumental === true,
             source: "LRCLIB", recordId: Number(record.id) || 0 };
}

function currentIndex(lines, positionMs) {
    var low = 0, high = lines.length;
    while (low < high) {
        var middle = (low + high) >>> 1;
        if (lines[middle].time <= positionMs) low = middle + 1;
        else high = middle;
    }
    return low - 1;
}

function query(track) {
    var fields = { track_name: clean(track.title), artist_name: clean(track.artist) };
    if (clean(track.album)) fields.album_name = clean(track.album);
    if (track.duration >= 1 && track.duration <= 3600) fields.duration = track.duration;
    return Object.keys(fields).map(function (key) {
        return key + "=" + encodeURIComponent(fields[key]);
    }).join("&");
}

function retryDelay(header, now) {
    var seconds = Number(header);
    if (header && Number.isFinite(seconds)) return Math.max(1000, seconds * 1000);
    var date = Date.parse(header);
    return Number.isFinite(date) ? Math.max(1000, date - now) : 60000;
}

function timeLabel(seconds) {
    seconds = Math.max(0, Math.floor(Number(seconds) || 0));
    return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
}

function validDocument(doc) {
    return doc && typeof doc === "object" && Array.isArray(doc.lines)
        && doc.lines.length <= 5000 && typeof doc.synced === "boolean"
        && doc.lines.every(function (line) {
            return line && Number.isFinite(line.time) && typeof line.text === "string";
        }) && JSON.stringify(doc).length < maxTextLength * 2;
}
