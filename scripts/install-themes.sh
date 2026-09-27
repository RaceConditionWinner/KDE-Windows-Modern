#!/bin/bash
# Install Aurorae, color schemes, Kvantum, Plasma themes, and wallpapers.
set -euo pipefail
source "$(dirname "$0")/install-lib.sh"

info "Installing themes..."

step "Window decorations (Aurorae)"
for theme in windows-modern-dark-aurorae windows-modern-light-aurorae; do
    replace_dir "$SRC_DIR/aurorae/$theme" "$AURORAE_DIR/$theme"
done

step "Color schemes"
for scheme in WindowsModernDark.colors WindowsModernLight.colors; do
    replace_file "$SRC_DIR/color-schemes/$scheme" "$SCHEMES_DIR/$scheme"
done

step "Kvantum theme"
replace_dir "$SRC_DIR/Kvantum/Windows-modern" "$KVANTUM_DIR/Windows-modern"

if [ "$UID" -ne 0 ]; then
    if command -v kwriteconfig6 &>/dev/null; then
        step "Selecting Windows-modern in Kvantum"
        kwriteconfig6 --file Kvantum/kvantum.kvconfig --group General --key theme Windows-modern
        # Remove only the malformed legacy config path used by older installer
        # versions, and only when it actually points at Windows Modern.
        legacy_config="$XDG_CONFIG_HOME/kvantum.kvconfig"
        if [ -f "$legacy_config" ] && grep -q '^theme=Windows-modern[[:space:]]*$' "$legacy_config"; then
            sed -i '/^theme=Windows-modern[[:space:]]*$/d' "$legacy_config" || true
        fi
    else
        warn "kwriteconfig6 not found; select Windows-modern in Kvantum Manager."
    fi
else
    warn "Installed system-wide; Kvantum theme selection remains user-specific."
fi

step "Plasma desktop themes"
for theme in Windows-modern-dark Windows-modern-light; do
    replace_dir "$SRC_DIR/plasma/desktoptheme/$theme" "$PLASMA_DIR/$theme"
done

step "Wallpapers"
replace_dir "$SRC_DIR/wallpaper/Windows-modern" "$WALLPAPER_DIR/Windows-modern"

refresh_sycoca
info "Themes installed successfully."

if ! is_batch && [ "$UID" -ne 0 ]; then
    variant="$(active_lookandfeel_id)"
    case "$variant" in
        org.kde.windowsmodern.dark) apply_kvantum_engine dark ;;
        org.kde.windowsmodern.light) apply_kvantum_engine light ;;
        *)
            apply_kvantum_engine dark
            if command -v plasma-apply-desktoptheme &>/dev/null; then
                plasma-apply-desktoptheme Windows-modern >/dev/null 2>&1 || warn "Could not apply the desktop theme automatically."
            fi
            ;;
    esac
    if ! bash "$SRC_DIR/scripts/set-wallpaper.sh"; then
        warn "Wallpaper was installed but could not be applied automatically."
    fi
fi
