#!/bin/bash
# Build and install the Windows Modern C++ Icon Tasks applet.
set -euo pipefail
source "$(dirname "$0")/install-lib.sh"

dir="$SRC_DIR/plasma/applets/org.kde.windowsmodern.icontasks"
[ -d "$dir" ] || { err "Icon Tasks source not found: $dir"; exit 1; }

info "Building Icon Tasks (C++)..."
[ -x "$dir/dev.sh" ] || { err "dev.sh not found in $dir"; exit 1; }

export WM_BATCH=1
bash "$dir/dev.sh"
unset WM_BATCH
refresh_sycoca

if ! is_batch; then
    restart_plasmashell
fi
info "Icon Tasks installed successfully."
