#!/bin/bash
# Install the Windows Modern icon theme.
set -euo pipefail
source "$(dirname "$0")/install-lib.sh"

THEME_NAME="windows-modern"
SRC="$SRC_DIR/icons/$THEME_NAME"
DEST="$ICONS_DIR/$THEME_NAME"
[ -d "$SRC" ] || { err "Icon pack not found: $SRC"; exit 1; }

info "Installing icon pack ($THEME_NAME)..."
replace_dir "$SRC" "$DEST"

if command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache -f "$DEST" >/dev/null 2>&1 || warn "GTK icon cache refresh failed; KDE will refresh its icon cache as needed."
fi

refresh_sycoca
info "Icons installed successfully."

if ! is_batch && [ "$UID" -ne 0 ]; then
    if command -v kwriteconfig6 &>/dev/null; then
        kwriteconfig6 --file kdeglobals --group Icons --key Theme "$THEME_NAME"
        kwriteconfig6 --file kcmicons --group Icons --key Theme "$THEME_NAME"
    else
        warn "kwriteconfig6 not found; activate windows-modern manually in System Settings → Icons."
    fi
fi
