#!/usr/bin/env python3
"""Run with dbus-run-session -- python3 tests/check-service.py.

Uses installed python-dbus/PyGObject. A private bus, local HTTP fixture, temporary
library, and unmodified service logic isolate this check from the user's Spotify.
"""
import http.server
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import urllib.parse

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

ROOT = Path(__file__).resolve().parent.parent
PLAYER = "org.mpris.MediaPlayer2.Player"
PROPERTIES = "org.freedesktop.DBus.Properties"
requests = []


def record(title):
    return {"id": 1, "trackName": title, "artistName": "Test artist", "albumName": "Test",
            "duration": 120, "syncedLyrics": f"[00:00]{title} words\n[00:02]Next words"}


class LyricsHTTP(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
        title = query.get("track_name", ["Alternate"])[0]
        requests.append(title)
        if title == "Slow":
            time.sleep(2)
        code = 404 if title == "Missing" else 429 if title == "Limited" else 200
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        if code == 429:
            self.send_header("Retry-After", "3")
        self.end_headers()
        try:
            data = [record(title)] if "/search?" in self.path else record(title)
            self.wfile.write(json.dumps(data).encode())
        except BrokenPipeError:
            pass  # Expected when a track change aborts the slow request.


class Spotify(dbus.service.Object):
    def __init__(self, bus):
        self.name = dbus.service.BusName("org.mpris.MediaPlayer2.spotify", bus)
        super().__init__(bus, "/org/mpris/MediaPlayer2")
        self.index = 0
        self.titles = ["One", "Slow", "Fast", "Missing", "Limited", "Fast"]
        self.position = 0
        self.status = "Playing"

    def props(self, interface):
        if interface == "org.mpris.MediaPlayer2":
            return {"Identity": "Spotify", "DesktopEntry": "spotify", "CanRaise": False, "CanQuit": False,
                    "HasTrackList": False, "SupportedUriSchemes": dbus.Array(["spotify"], signature="s"),
                    "SupportedMimeTypes": dbus.Array([], signature="s")}
        title = self.titles[self.index]
        return {"PlaybackStatus": self.status, "Rate": 1.0, "MinimumRate": 1.0, "MaximumRate": 1.0,
                "Volume": 1.0, "Position": dbus.Int64(self.position), "CanControl": True, "CanSeek": True,
                "CanPlay": True, "CanPause": True, "CanGoNext": True, "CanGoPrevious": False,
                "Metadata": dbus.Dictionary({"mpris:trackid": dbus.ObjectPath("/lyridec/" + title),
                    "mpris:length": dbus.Int64(120000000), "xesam:title": title, "xesam:album": "Test",
                    "xesam:artist": dbus.Array(["Test artist"], signature="s")}, signature="sv")}

    @dbus.service.method(PROPERTIES, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        return self.props(interface)

    @dbus.service.method(PROPERTIES, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        return self.props(interface)[name]

    @dbus.service.signal(PROPERTIES, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    @dbus.service.signal(PLAYER, signature="x")
    def Seeked(self, position):
        pass

    @dbus.service.method(PLAYER, in_signature="ox")
    def SetPosition(self, track, position):
        self.position = int(position)
        self.Seeked(self.position)

    @dbus.service.method(PLAYER)
    def Pause(self):
        self.status = "Paused"
        self.PropertiesChanged(PLAYER, {"PlaybackStatus": self.status}, [])

    @dbus.service.method(PLAYER)
    def Next(self):
        self.index += 1
        self.position = 0
        self.PropertiesChanged(PLAYER, self.props(PLAYER), [])
        self.Seeked(0)


DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
# Never register a fake player on a user's existing session.
if bus.name_has_owner("org.mpris.MediaPlayer2.spotify") or bus.name_has_owner("org.freedesktop.Notifications"):
    raise SystemExit("Use dbus-run-session to isolate this test from the desktop.")
spotify = Spotify(bus)
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), LyricsHTTP)
threading.Thread(target=server.serve_forever, daemon=True).start()
with tempfile.TemporaryDirectory(prefix="lyridec-check-") as folder:
    target = Path(folder)
    for name in ["Lyrics.js", "LyricsService.qml"]:
        code = (ROOT / name).read_text()
        if name.endswith(".qml"):
            code = code.replace("https://lrclib.net/api/", f"http://127.0.0.1:{server.server_port}/api/")
        (target / name).write_text(code)
    (target / "qmldir").write_text("singleton LyricsService 1.0 LyricsService.qml\n")
    (target / "shell.qml").write_text((ROOT / "tests/ServiceChecks.qml").read_text())
    (target / "import.lrc").write_text("[00:00]Imported words\n[00:02]Second line")
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_DATA_HOME=str(target / "data"),
               LYRIDEC_TEST_LRC=str(target / "import.lrc"))
    env.pop("WAYLAND_DISPLAY", None)
    with (target / "log").open("w+") as log:
        process = subprocess.Popen(["qs", "-p", str(target), "--no-color"], env=env, stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 22
        context = GLib.MainContext.default()
        while process.poll() is None and time.monotonic() < deadline:
            while context.pending():
                context.iteration(False)
            time.sleep(0.01)
        if process.poll() is None:
            process.kill()
        process.wait()
        log.seek(0)
        output = log.read()
        if process.returncode or "SERVICE_CHECKS_PASSED" not in output:
            print(output)
            raise SystemExit("Service integration checks failed")
    saved = json.loads((target / "data/lyridec/library.json").read_text())
    assert any(d["lines"][0]["text"] == "Alternate words" for d in saved["overrides"].values())
    assert 200 in saved["offsets"].values()
    assert requests.count("Limited") == 1, requests
    assert requests.count("Fast") == 1, requests
server.shutdown()
print("Service checks passed: fetch, import, seek, pause, match, stale replies, missing lyrics, rate limits, cache, persistence, and shutdown.")
