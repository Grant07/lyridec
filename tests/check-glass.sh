#!/bin/sh
set -eu
qt_bindir=${QT_BINDIR:-/usr/lib/qt6/bin}
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
# Reproducible shipping shader, followed by actual GPU-rendered scenes.
"$qt_bindir/qsb" --qt6 -o "$test_dir/glass.frag.qsb" src/shaders/glass.frag
cmp src/shaders/glass.frag.qsb "$test_dir/glass.frag.qsb"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi \
    QSG_RHI_BACKEND=opengl LYRIDEC_REQUIRE_GPU=1 \
    LYRIDEC_CAPTURE_DIR="$test_dir" timeout 20 qs -p preview.qml --no-color
for scene in reading controls focus details search loading missing error instrumental idle light minimum minimum-loading minimum-error glass-off glass-mid glass-full; do
    test -s "$test_dir/$scene.png"
done

# Identical content at three settings must actually render differently.
if cmp -s "$test_dir/glass-off.png" "$test_dir/glass-mid.png" || \
   cmp -s "$test_dir/glass-mid.png" "$test_dir/glass-full.png"; then
    echo "Glass intensity did not change the rendered material" >&2
    exit 1
fi
