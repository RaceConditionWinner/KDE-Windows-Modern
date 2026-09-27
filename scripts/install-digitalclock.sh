#!/bin/bash
# Install the Windows Modern Digital Clock applet.
set -euo pipefail
source "$(dirname "$0")/install-lib.sh"

src="$SRC_DIR/plasma/applets/org.kde.windowsmodern.digitalclock"
[ -d "$src" ] || { err "Digital Clock source not found: $src"; exit 1; }

info "Installing Digital Clock applet..."
replace_dir "$src" "$APPLETS_DIR/org.kde.windowsmodern.digitalclock"
refresh_sycoca
info "Digital Clock installed successfully."

if ! is_batch; then
    restart_plasmashell
fi
