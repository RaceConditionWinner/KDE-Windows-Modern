#!/bin/bash
# Install the Windows Modern panel layout template.
set -euo pipefail
source "$(dirname "$0")/install-lib.sh"

src="$SRC_DIR/plasma/layout-templates/org.kde.windowsmodern.panel"
[ -d "$src" ] || { err "Panel layout source not found: $src"; exit 1; }

info "Installing panel layout template..."
replace_dir "$src" "$LAYOUT_DIR/org.kde.windowsmodern.panel"
refresh_sycoca
info "Panel layout installed successfully."

if ! is_batch; then
    echo "To add it: right-click desktop → Add Panel → Windows Modern Panel."
    echo "For the Win11 inset look: Panel Configuration → Floating → Applets Only."
fi
