#!/bin/bash
# Build and install the Windows Modern C++ System Tray applet.
set -euo pipefail
source "$(dirname "$0")/install-lib.sh"

dir="$SRC_DIR/plasma/applets/org.kde.windowsmodern.systemtray"
[ -d "$dir" ] || { err "System Tray source not found: $dir"; exit 1; }

info "Building System Tray (C++)..."
[ -x "$dir/dev.sh" ] || { err "dev.sh not found in $dir"; exit 1; }

# dev.sh owns the CMake build and normally restarts Plasma. Preserve the
# caller's batch state so a parent `install.sh all` still gets exactly one
# final Shell restart.
outer_batch="${WM_BATCH:-0}"
export WM_BATCH=1
bash "$dir/dev.sh"
if [ "$outer_batch" = "1" ]; then
    export WM_BATCH=1
else
    unset WM_BATCH
fi
refresh_sycoca

if [ "$outer_batch" != "1" ]; then
    restart_plasmashell
    bash "$dir/verify.sh"
fi
info "System Tray installed successfully."
