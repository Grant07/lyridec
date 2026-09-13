#!/bin/sh
set -eu
qt_bindir=${QT_BINDIR:-/usr/lib/qt6/bin}
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
mkdir -p "$test_dir/tests/unit" "$test_dir/src/components"
# The view has no Quickshell dependency; omit the service module's qmldir.
cp src/components/qmldir src/components/*.qml "$test_dir/src/components/"
cp src/Lyrics.js "$test_dir/src/"
cp -R src/shaders "$test_dir/src/"
cp tests/unit/tst_view.qml "$test_dir/tests/unit/"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen "$qt_bindir/qmltestrunner" -input "$test_dir/tests/unit/tst_view.qml" -o -,txt
