#!/bin/bash
# Install the Windows Modern Global Themes.
set -euo pipefail
source "$(dirname "$0")/install-lib.sh"

info "Installing global themes..."
replace_dir "$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.dark" "$LOOKFEEL_DIR/org.kde.windowsmodern.dark"
replace_dir "$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.light" "$LOOKFEEL_DIR/org.kde.windowsmodern.light"
refresh_sycoca
info "Global themes installed successfully."

if is_batch || [ "$UID" -eq 0 ]; then
    exit 0
fi

variant="$(ask_theme_variant)"
theme="$(lookfeel_id "$variant")"
if windows_modern_layout_present; then
    apply_lookandfeel "$theme"
else
    apply_lookandfeel "$theme" reset
fi
apply_kvantum_engine "$variant"
post_kwin_borders
restart_plasmashell
