#!/bin/sh
set -eu
qt_bindir=${QT_BINDIR:-/usr/lib/qt6/bin}
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
mkdir "$test_dir/tests"
# The view has no Quickshell dependency; omit the service module's qmldir.
cp LyricsView.qml LyridecButton.qml Lyrics.js "$test_dir/"
cp -R shaders "$test_dir/"
cp tests/tst_view.qml "$test_dir/tests/"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen "$qt_bindir/qmltestrunner" -input "$test_dir/tests/tst_view.qml" -o -,txt
