#!/bin/bash
# Windows Modern component uninstaller.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/scripts/install-lib.sh"

FAILURES=0
SHELL_REFRESH=0

remove_user() {
    local path="$1"
    if [ -e "$path" ] || [ -L "$path" ]; then
        if ! remove_path "$path"; then
            err "Could not remove: $path"
            FAILURES=$((FAILURES + 1))
        fi
    fi
}

remove_system() {
    local path
    for path in "$@"; do
        if [ -e "$path" ] || [ -L "$path" ]; then
            if ! remove_paths_privileged "$path"; then
                err "Could not remove: $path"
                FAILURES=$((FAILURES + 1))
            fi
        fi
    done
}

remove_both() {
    if [ "$UID" -eq 0 ]; then
        remove_system "$2"
    else
        remove_user "$1"
        remove_system "$2"
    fi
}

warn_if_applet_is_configured() {
    local app_id="$1" layout
    [ "$UID" -ne 0 ] || return 0
    layout="$(plasma_layout_file)"
    if [ -f "$layout" ] && grep -Eq "(^|[[:space:]])plugin=${app_id}([[:space:]]|$)" "$layout"; then
        warn "The running Plasma layout still references ${app_id}. It will become unavailable after uninstall; use './uninstall.sh all' to restore Breeze automatically, or remove the widget first."
    fi
}

uninstall_component() {
    local name="$1"
    info "Uninstalling: $name"

    case "$name" in
        themes)
            if ! restore_kwin_borders_if_needed; then
                FAILURES=$((FAILURES + 1))
                return 1
            fi
            if ! restore_default_theme_if_active; then
                FAILURES=$((FAILURES + 1))
                return 1
            fi
            remove_both "$AURORAE_DIR/windows-modern-dark-aurorae" "/usr/share/aurorae/themes/windows-modern-dark-aurorae"
            remove_both "$AURORAE_DIR/windows-modern-light-aurorae" "/usr/share/aurorae/themes/windows-modern-light-aurorae"
            remove_both "$SCHEMES_DIR/WindowsModernDark.colors" "/usr/share/color-schemes/WindowsModernDark.colors"
            remove_both "$SCHEMES_DIR/WindowsModernLight.colors" "/usr/share/color-schemes/WindowsModernLight.colors"
            remove_both "$KVANTUM_DIR/Windows-modern" "/usr/share/Kvantum/Windows-modern"
            remove_both "$PLASMA_DIR/Windows-modern-dark" "/usr/share/plasma/desktoptheme/Windows-modern-dark"
            remove_both "$PLASMA_DIR/Windows-modern-light" "/usr/share/plasma/desktoptheme/Windows-modern-light"
            remove_both "$WALLPAPER_DIR/Windows-modern" "/usr/share/wallpapers/Windows-modern"
            if [ "$UID" -ne 0 ] && [ -f "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" ]; then
                # Only change the user's Kvantum selection if it still points at us.
                sed -i '/^[[:space:]]*theme=Windows-modern[[:space:]]*$/d' "$XDG_CONFIG_HOME/Kvantum/kvantum.kvconfig" || true
            fi
            SHELL_REFRESH=1
            refresh_sycoca
            info "Themes uninstalled."
            ;;
        icons)
            if [ "$UID" -ne 0 ]; then
                remove_user "$ICONS_DIR/windows-modern"
            else
                remove_system "/usr/share/icons/windows-modern"
            fi
            SHELL_REFRESH=1
            refresh_sycoca
            info "Icons uninstalled."
            ;;
        lookfeel)
            if ! restore_default_theme_if_active; then
                FAILURES=$((FAILURES + 1))
                return 1
            fi
            remove_both "$LOOKFEEL_DIR/org.kde.windowsmodern.dark" "/usr/share/plasma/look-and-feel/org.kde.windowsmodern.dark"
            remove_both "$LOOKFEEL_DIR/org.kde.windowsmodern.light" "/usr/share/plasma/look-and-feel/org.kde.windowsmodern.light"
            SHELL_REFRESH=1
            refresh_sycoca
            info "Global themes uninstalled."
            ;;
        layout)
            remove_both "$LAYOUT_DIR/org.kde.windowsmodern.panel" "/usr/share/plasma/layout-templates/org.kde.windowsmodern.panel"
            refresh_sycoca
            info "Panel layout template uninstalled."
            ;;
        showdesk)
            warn_if_applet_is_configured org.kde.windowsmodern.showdesktop
            remove_both "$APPLETS_DIR/org.kde.windowsmodern.showdesktop" "/usr/share/plasma/plasmoids/org.kde.windowsmodern.showdesktop"
            SHELL_REFRESH=1
            ;;
        systray)
            warn_if_applet_is_configured org.kde.windowsmodern.systemtray
            local plugin_dir=""
            plugin_dir="$(plasma_applet_plugin_dir 2>/dev/null || true)"
            [ -n "$plugin_dir" ] && remove_system "$plugin_dir/org.kde.windowsmodern.systemtray.so"
            remove_both "$XDG_DATA_HOME/plasma/plasmoids/org.kde.windowsmodern.systemtray" "/usr/share/plasma/plasmoids/org.kde.windowsmodern.systemtray"
            remove_user "$HOME/.local/lib64/qt6/plugins/plasma/applets/org.kde.windowsmodern.systemtray.so"
            remove_user "$HOME/.local/lib/qt6/plugins/plasma/applets/org.kde.windowsmodern.systemtray.so"
            SHELL_REFRESH=1
            refresh_sycoca
            info "System Tray uninstalled."
            ;;
        icontasks)
            warn_if_applet_is_configured org.kde.windowsmodern.icontasks
            local plugin_dir=""
            plugin_dir="$(plasma_applet_plugin_dir 2>/dev/null || true)"
            [ -n "$plugin_dir" ] && remove_system "$plugin_dir/org.kde.windowsmodern.icontasks.so"
            remove_both "$XDG_DATA_HOME/plasma/plasmoids/org.kde.windowsmodern.icontasks" "/usr/share/plasma/plasmoids/org.kde.windowsmodern.icontasks"
            remove_user "$HOME/.local/lib64/qt6/plugins/plasma/applets/org.kde.windowsmodern.icontasks.so"
            remove_user "$HOME/.local/lib/qt6/plugins/plasma/applets/org.kde.windowsmodern.icontasks.so"
            SHELL_REFRESH=1
            refresh_sycoca
            info "Icon Tasks uninstalled."
            ;;
        digitalclock)
            warn_if_applet_is_configured org.kde.windowsmodern.digitalclock
            remove_both "$APPLETS_DIR/org.kde.windowsmodern.digitalclock" "/usr/share/plasma/plasmoids/org.kde.windowsmodern.digitalclock"
            SHELL_REFRESH=1
            refresh_sycoca
            info "Digital Clock uninstalled."
            ;;
        all)
            # Restore settings while the Windows Modern state is still detectable,
            # then remove its packages so the running session never resolves missing assets.
            if ! restore_kwin_borders_if_needed; then
                FAILURES=$((FAILURES + 1))
                return 1
            fi
            if ! restore_default_theme_if_active; then
                FAILURES=$((FAILURES + 1))
                return 1
            fi
            for component in "${WM_COMPONENTS[@]}"; do
                uninstall_component "$component"
            done
            # All custom applets are now gone. Reset to Breeze's stock panel layout
            # only when the current configuration still references Windows Modern.
            if [ "$UID" -ne 0 ] && windows_modern_layout_present; then
                if command -v plasma-apply-lookandfeel &>/dev/null; then
                    info "Removing Windows Modern panel references via Breeze layout..."
                    plasma-apply-lookandfeel -a org.kde.breeze.desktop --resetLayout >/dev/null 2>&1 || \
                        warn "Could not reset the panel layout automatically; remove stale Windows Modern widgets manually."
                else
                    warn "plasma-apply-lookandfeel not found; stale panel references may remain until manually removed."
                fi
            fi
            SHELL_REFRESH=1
            ;;
        *)
            err "Unknown component: $name"
            echo "Available: ${WM_COMPONENTS[*]} all"
            return 2
            ;;
    esac
}

component="all"
case "${1:-}" in
    "") component=all ;;
    --help|-h)
        echo "Usage: ./uninstall.sh [component]"
        echo "No argument is equivalent to: ./uninstall.sh all"
        echo "Components: ${WM_COMPONENTS[*]} all"
        exit 0
        ;;
    all|themes|icons|lookfeel|layout|showdesk|systray|icontasks|digitalclock|systemtray)
        component="$1"
        [ "$component" != systemtray ] || component=systray
        ;;
    *)
        err "Unknown component: $1"
        echo "Available: ${WM_COMPONENTS[*]} all"
        exit 2
        ;;
esac

uninstall_component "$component"

# Removing the complete theme must also eliminate stale compiled/config state
# from the running shell. One restart is enough, regardless of component count.
if [ "$SHELL_REFRESH" -eq 1 ] && [ "$UID" -ne 0 ]; then
    restart_plasmashell || FAILURES=$((FAILURES + 1))
fi

if [ "$FAILURES" -ne 0 ]; then
    err "Uninstall completed with $FAILURES failure(s)."
    exit 1
fi
info "Uninstall completed successfully."
