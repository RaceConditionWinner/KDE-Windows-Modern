#!/bin/bash
# Build and install the compiled Icon Tasks plugin.
set -euo pipefail

APPLET_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$APPLET_DIR/build"
APP_ID="org.kde.windowsmodern.icontasks"

source "$APPLET_DIR/../../../scripts/install-lib.sh"

info "Building $APP_ID..."
cmake -S "$APPLET_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
if command -v getconf &>/dev/null; then
    CPU_JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
else
    CPU_JOBS=1
fi
cmake --build "$BUILD_DIR" --parallel "$CPU_JOBS"

PLUGIN_SRC="$BUILD_DIR/lib/plasma/applets/${APP_ID}.so"
[ -f "$PLUGIN_SRC" ] || { err "Build completed without producing $PLUGIN_SRC"; exit 1; }

info "Installing compiled plugin..."
install_system_plugin "$PLUGIN_SRC" "$APP_ID"
refresh_sycoca

if [ "${WM_BATCH:-0}" = "1" ]; then
    info "Installed (batch mode)."
else
    restart_plasmashell
fi
