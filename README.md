# lyridec

A DMS / Quickshell desktop lyrics widget for the native Spotify app.

Lyrics come from [LRCLIB](https://lrclib.net/docs) or your own LRC/text files. Spotify supplies playback metadata and position through MPRIS. No Spotify login, API key, browser extension, or background server is required.

## Use

Play a song in Spotify. lyridec finds its lyrics and follows the current line. When you leave the widget, the words fill the panel. Hover or use the keyboard to reveal track details, options, source and time; the lyrics stay in place.

- **Reading / focus:** switch in the header options. Reading shows surrounding lines; focus shows the current and next lines.
- **Browse:** scroll the lyrics, then select **Back to current line** to resume following. Up/Down, Page Up/Down, Home and End also scroll when the widget has keyboard focus.
- **Seek:** select a timed lyric line to jump to it. Untimed lyrics remain a readable sheet.
- **Change match:** open the header options, search, and select the right recording. The selection is saved for that Spotify track.
- **Import:** choose a UTF-8 `.lrc` or `.txt` file from options. lyridec saves a copy for the recording selected when the file picker opened; it does not edit the original.
- **Timing:** adjust in 0.1-second steps, up to ±10 seconds. Positive values show lyrics earlier. The offset is saved per recording.
- **Appearance:** DMS widget settings provide layout, lyric size, background opacity, reduced motion, and idle visibility and glass intensity. DMS handles placement, resizing, display selection, and **Show on overlay** for keeping the widget above application windows.

This is a lyrics display, with no playback transport, queue, library browser, or account management.

## Install locally

Run from this checkout:

```sh
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins"
ln -s "$PWD" "${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins/lyridec"
dms ipc call plugin-scan scan
```

After the scan finishes, enable **lyridec** in DMS Plugins, then add it in **Settings → Desktop Widgets**. The initial size is 440 × 520; the minimum is 320 × 300. Do not replace an existing installation without checking its path first.

For local development, reload after editing:

```sh
dms ipc call plugins reload lyridec
dms ipc call plugin-scan status lyridec
```

DMS can retain imported child QML in its engine cache. If a reload still shows the previous view or service behavior, run `dms restart` once to load all changed files.

Runtime requirements are DMS 1.5.3 or newer, Quickshell 0.3 or newer, Qt 6 Quick Controls/Dialogs/Effects, and coreutils. The main widget uses DMS's QML imports and runs inside DMS.

## Glass appearance

The panel uses native background blur with a refracted rim and subtle highlights. The rim distorts album artwork; lyrics remain sharp. DMS's blur setting and compositor support control the backdrop. Niri 26.04 supports it on the development desktop. Without native blur the center remains more opaque; software rendering uses the plain rounded panel.

The shader is static and adds no animation timer. Use **Glass intensity** (0–100%) in the widget settings to adjust the rim, reflections, artwork tint and refraction. At 0% these effects and the widget’s blur request are off. **Background opacity** separately controls the surface opacity; the blur radius remains a compositor setting. Niri defaults blur to wallpaper-only “xray” mode. To blur application windows beneath lyridec, add this rule to your Niri configuration and enable **Show on overlay** in DMS:

```kdl
layer-rule {
    match namespace="^dms:desktop-widget:lyridec(:|$)"
    background-effect {
        xray false
    }
}
```

It preserves the rounded blur region requested by DMS and its blur preference. Niri 26.04 labels non-xray effects experimental: blur can disappear during window animations or tiled-window dragging, and costs more when underlying content changes. See [Niri window effects](https://niri-wm.github.io/niri/Window-Effects.html).

The packaged shader is generated from `shaders/glass.frag` with Qt Shader Tools:

```sh
/usr/lib/qt6/bin/qsb --qt6 -o shaders/glass.frag.qsb shaders/glass.frag
```

## Lyrics and storage

Lookup order is **saved override → cache → LRCLIB**. Automatic queries include title, artist, album and duration. Search selection is explicit; the widget does not silently choose a loosely matched recording.

The library is `${XDG_DATA_HOME:-$HOME/.local/share}/lyridec/library.json`. It contains up to 80 fetched recordings, imported/selected overrides, and timing offsets. Overrides are not evicted with the cache. Empty API matches expire after one hour. Writes are atomic; an unreadable library is left intact and the widget reports that changes cannot be saved.

Only recording metadata or a search you submit is sent to LRCLIB. Imported lyric files stay local. A 12-second request timeout, request spacing and `Retry-After` handling bound network work. Track changes invalidate older replies. The shared service stops following Spotify when the last widget instance closes.

V1 reads ordinary LRC timestamps (including repeated timestamps, offsets and multiple languages) and plain text. Enhanced LRC word tags are read as line lyrics; word highlighting, other subtitle formats and other players are outside v1. Coverage and timing depend on the source.

## Checks

```sh
make check
make check-glass
```

Tests default to Arch's `/usr/lib/qt6/bin`; override `QT_BINDIR` for another installation. The glass check requires Qt Shader Tools and an offscreen OpenGL context; it verifies the compiled shader matches its source and renders seventeen native scenes, including loading, missing lyrics, errors, the smallest supported size, and glass intensity at 0%, 50% and 100%. Service checks need Python `dbus` and `gi` (`python-dbus` and `python-gobject` on Arch). They run a fake Spotify player on a private D-Bus session with a local HTTP fixture and a temporary data directory; they do not control your Spotify or contact LRCLIB.

Checks cover LRC parsing, input bounds, timing selection, keyboard scrolling, stable active-phrase positioning, hover disclosure without layout shifts, error recovery, search focus, fetching, import, lyric seeking, pause state, manual matching, stale replies, missing lyrics, rate limits, cache reuse, saved offsets and service shutdown.

To check the real Spotify connection without changing playback:

```sh
LYRIDEC_SMOKE=1 qs -p preview.qml
```

To inspect the view using clearly labeled synthetic content:

```sh
qs -p preview.qml
```

Or capture the native layout matrix without opening a desktop window:

```sh
mkdir -p tests/artifacts
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen \
  LYRIDEC_CAPTURE_DIR="$PWD/tests/artifacts" qs -p preview.qml
```

Standalone checks can print scanner warnings about the DMS imports in the unused plugin wrapper. Those imports resolve inside DMS. Qt 6.11's linter also reports Quickshell's missing `QProcess::ExitStatus` type metadata; the actual process callback is covered by the service checks.

## Package installation

Build dependencies are `make` and Qt Shader Tools. The generated shader is included for DMS Git-based installs; packages rebuild it from source.

```sh
make -B
make DESTDIR="$PWD/build/stage" install
```

The staged installation contains only runtime QML/JavaScript, metadata, the compiled shader, documentation and license. Files install under `/usr/share/lyridec`; a link under `/etc/xdg/quickshell/dms-plugins` makes them discoverable by DMS. Installation does not enable the widget or modify user settings. A user-installed copy with the same ID takes precedence; remove its symlink when switching to the packaged copy.

Use `PREFIX`, `SYSCONFDIR` and `DESTDIR` to adjust installation paths. The package is data-only and does not need a desktop launcher, systemd service or install script.

## License

[MIT](LICENSE). The license covers lyridec's code; lyrics and artwork remain the property of their respective rights holders.

See [DESIGN.md](DESIGN.md) for interface and implementation details.
