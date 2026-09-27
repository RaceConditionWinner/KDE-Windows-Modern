#!/bin/bash
# Install the Windows Modern Show Desktop applet.
set -euo pipefail
source "$(dirname "$0")/install-lib.sh"

src="$SRC_DIR/plasma/applets/org.kde.windowsmodern.showdesktop"
[ -d "$src" ] || { err "Show Desktop source not found: $src"; exit 1; }

info "Installing Show Desktop applet..."
replace_dir "$src" "$APPLETS_DIR/org.kde.windowsmodern.showdesktop"
refresh_sycoca
info "Show Desktop installed successfully."

if ! is_batch; then
    restart_plasmashell
fi
