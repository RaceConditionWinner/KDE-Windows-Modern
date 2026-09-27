#!/bin/bash
# Windows Modern shared installer library.
# Keep this small: paths, safe file replacement/removal, Plasma refresh,
# and common apply helpers live here so install/uninstall behavior stays aligned.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

WM_COMPONENTS=(themes icons lookfeel layout showdesk systray icontasks digitalclock)
WM_APPLETS=(showdesk systray icontasks digitalclock)

BOLD="\033[1m"; GREEN="\033[32m"; BLUE="\033[34m"; YELLOW="\033[33m"; RED="\033[31m"; CYAN="\033[36m"; RESET="\033[0m"
info()  { echo -e "${GREEN}==>${RESET} ${BOLD}$*${RESET}"; }
warn()  { echo -e "${YELLOW}==>${RESET} $*"; }
err()   { echo -e "${RED}==>${RESET} $*" >&2; }
step()  { echo -e "${CYAN}  >>${RESET} $*"; }

if [ "$UID" -eq 0 ]; then
    AURORAE_DIR="/usr/share/aurorae/themes"
    SCHEMES_DIR="/usr/share/color-schemes"
    PLASMA_DIR="/usr/share/plasma/desktoptheme"
    LAYOUT_DIR="/usr/share/plasma/layout-templates"
    LOOKFEEL_DIR="/usr/share/plasma/look-and-feel"
    KVANTUM_DIR="/usr/share/Kvantum"
    WALLPAPER_DIR="/usr/share/wallpapers"
    ICONS_DIR="/usr/share/icons"
    APPLETS_DIR="/usr/share/plasma/plasmoids"
else
    AURORAE_DIR="$XDG_DATA_HOME/aurorae/themes"
    SCHEMES_DIR="$XDG_DATA_HOME/color-schemes"
    PLASMA_DIR="$XDG_DATA_HOME/plasma/desktoptheme"
    LAYOUT_DIR="$XDG_DATA_HOME/plasma/layout-templates"
    LOOKFEEL_DIR="$XDG_DATA_HOME/plasma/look-and-feel"
    KVANTUM_DIR="$XDG_CONFIG_HOME/Kvantum"
    WALLPAPER_DIR="$XDG_DATA_HOME/wallpapers"
    ICONS_DIR="$XDG_DATA_HOME/icons"
    APPLETS_DIR="$XDG_DATA_HOME/plasma/plasmoids"
fi

is_interactive() { [ -t 0 ]; }
is_batch() { [ "${WM_BATCH:-0}" = "1" ]; }
wm_has_component() {
    local wanted="$1" c
    for c in "${WM_COMPONENTS[@]}"; do [ "$c" = "$wanted" ] && return 0; done
    return 1
}

ensure_dir() {
    mkdir -p -- "$1" 2>/dev/null || { err "Cannot create $1."; return 1; }
}

# Run a command through exactly one privilege boundary. Prefer the graphical
# polkit path in a real desktop session, otherwise use sudo for TTY/headless
# execution. Never silently fall back to unprivileged execution.
run_privileged() {
    if [ "$UID" -eq 0 ]; then
        "$@"
    elif [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v pkexec &>/dev/null; then
        pkexec "$@"
    elif command -v sudo &>/dev/null; then
        sudo "$@"
    elif command -v pkexec &>/dev/null; then
        pkexec "$@"
    else
        err "Root privileges are required for: $*"
        err "Install polkit pkexec or sudo, then retry."
        return 1
    fi
}

# Atomically replace a directory on the same filesystem. The old directory is
# moved aside until the new copy is in place, so a failed copy does not destroy
# an existing working installation.
replace_dir() {
    local src="$1"
    local dest="$2"
    [ -d "$src" ] || { err "Source directory not found: $src"; return 1; }
    local parent base tmp old
    parent="$(dirname "$dest")"
    base="$(basename "$dest")"
    ensure_dir "$parent"
    tmp="$(mktemp -d "$parent/.${base}.install.XXXXXX")"
    old="${dest}.old.$$"
    cleanup_replace() { rm -rf -- "$tmp" "$old" 2>/dev/null || true; }
    trap cleanup_replace RETURN

    cp -a -- "$src/." "$tmp/"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mv -- "$dest" "$old"
    fi
    if ! mv -- "$tmp" "$dest"; then
        [ -e "$old" ] || [ -L "$old" ] && mv -- "$old" "$dest" || true
        return 1
    fi
    rm -rf -- "$old" 2>/dev/null || warn "Could not remove temporary previous copy: $old"
    trap - RETURN
}

replace_file() {
    local src="$1"
    local dest="$2"
    [ -f "$src" ] || { err "Source file not found: $src"; return 1; }
    local parent tmp
    parent="$(dirname "$dest")"
    ensure_dir "$parent"
    tmp="$(mktemp "$parent/.$(basename "$dest").install.XXXXXX")"
    if ! cp -a -- "$src" "$tmp"; then
        rm -f -- "$tmp"
        return 1
    fi
    chmod --reference="$src" "$tmp" 2>/dev/null || true
    if ! mv -f -- "$tmp" "$dest"; then
        rm -f -- "$tmp"
        return 1
    fi
}

remove_path() {
    local path="$1"
    [ -e "$path" ] || [ -L "$path" ] || return 0
    rm -rf -- "$path"
}

remove_paths_privileged() {
    [ "$#" -gt 0 ] || return 0
    local -a existing=()
    local path
    for path in "$@"; do
        if [ -e "$path" ] || [ -L "$path" ]; then
            existing+=("$path")
        fi
    done
    [ "${#existing[@]}" -gt 0 ] || return 0
    run_privileged rm -rf -- "${existing[@]}"
}

qt6_plugin_dir() {
    local dir=""
    if [ -n "${QT_PLUGIN_DIR:-}" ]; then
        dir="$QT_PLUGIN_DIR"
    elif command -v qtpaths6 &>/dev/null; then
        dir="$(qtpaths6 --plugin-dir 2>/dev/null || true)"
    elif command -v qtpaths &>/dev/null; then
        dir="$(qtpaths --plugin-dir 2>/dev/null || true)"
    fi
    if [ -z "$dir" ] && command -v pkg-config &>/dev/null; then
        dir="$(pkg-config --variable=plugindir Qt6Core 2>/dev/null || true)"
    fi
    if [ -z "$dir" ]; then
        for candidate in /usr/lib/qt6/plugins /usr/lib64/qt6/plugins; do
            if [ -d "$candidate" ]; then dir="$candidate"; break; fi
        done
    fi
    [ -n "$dir" ] || return 1
    printf '%s\n' "$dir"
}

plasma_applet_plugin_dir() {
    local qt_plugins
    qt_plugins="$(qt6_plugin_dir)" || return 1
    printf '%s/plasma/applets\n' "$qt_plugins"
}

# Install a compiled Plasma applet as a plugin only. Plasma discovers this
# runtime artifact from the Qt plugin path; do not install a KPackage payload.
install_system_plugin() {
    local src="$1"
    local app_id="$2"
    [ -f "$src" ] || { err "Built plugin not found: $src"; return 1; }
    local plugin_dir
    plugin_dir="$(plasma_applet_plugin_dir)" || {
        err "Unable to resolve the Qt6 plugin directory. Install qtpaths6 or Qt6Core metadata."
        return 1
    }
    local target="$plugin_dir/${app_id}.so"
    run_privileged bash -s -- "$src" "$plugin_dir" "$app_id" <<'ROOT'
set -euo pipefail
src="$1"
plugin_dir="$2"
app_id="$3"
mkdir -p -- "$plugin_dir"
tmp="$(mktemp "$plugin_dir/.${app_id}.XXXXXX")"
trap 'rm -f -- "$tmp"' EXIT
cp -- "$src" "$tmp"
chmod 0644 -- "$tmp"
mv -f -- "$tmp" "$plugin_dir/${app_id}.so"
rm -rf -- "/usr/share/plasma/plasmoids/${app_id}"
trap - EXIT
ROOT

# Remove user-local copies of this same plugin that could shadow the system copy.
    local -a local_targets=(
        "$HOME/.local/lib64/qt6/plugins/plasma/applets/${app_id}.so"
        "$HOME/.local/lib/qt6/plugins/plasma/applets/${app_id}.so"
    )
    rm -f -- "${local_targets[@]}" 2>/dev/null || true
    printf '%s\n' "$target"
}

refresh_sycoca() {
    [ "$UID" -ne 0 ] || return 0
    if command -v kbuildsycoca6 &>/dev/null; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || warn "KDE service cache refresh failed; Plasma may need a restart."
    fi
}

_wait_plasmashell_exit() {
    local i
    for i in {1..25}; do
        pgrep -x plasmashell >/dev/null 2>&1 || return 0
        sleep 0.2
    done
    return 1
}

_kstart_cmd() {
    if command -v kstart6 &>/dev/null; then echo kstart6
    elif command -v kstart &>/dev/null; then echo kstart
    else echo ""; fi
}

restart_plasmashell() {
    [ "$UID" -ne 0 ] || { warn "Running as root; not touching the user's Plasma Shell."; return 0; }
    pgrep -x plasmashell >/dev/null 2>&1 || return 0
    info "Restarting Plasma Shell..."

    if command -v systemctl &>/dev/null && systemctl --user list-unit-files plasma-plasmashell.service >/dev/null 2>&1 \
       && systemctl --user restart plasma-plasmashell.service 2>/dev/null; then
        sleep 0.5
        pgrep -x plasmashell >/dev/null 2>&1 || {
            sleep 1
        }
        if pgrep -x plasmashell >/dev/null 2>&1; then return 0; fi
    fi

    if command -v kquitapp6 &>/dev/null; then
        kquitapp6 plasmashell >/dev/null 2>&1 || true
    elif command -v killall &>/dev/null; then
        killall plasmashell >/dev/null 2>&1 || true
    fi

    if ! _wait_plasmashell_exit; then
        warn "Plasma Shell did not stop gracefully; forcing termination."
        killall -9 plasmashell >/dev/null 2>&1 || true
        sleep 0.5
    fi

    local kstart
    kstart="$(_kstart_cmd)"
    if [ -n "$kstart" ]; then
        command "$kstart" plasmashell >/dev/null 2>&1 &
    elif command -v plasmashell &>/dev/null; then
        plasmashell >/dev/null 2>&1 &
    else
        err "Cannot restart Plasma Shell: neither kstart6 nor plasmashell was found."
        return 1
    fi

    for _ in {1..20}; do
        pgrep -x plasmashell >/dev/null 2>&1 && { sleep 0.5; return 0; }
        sleep 0.25
    done

    err "Plasma Shell could not be restarted."
    return 1
}

plasma_layout_file() {
    printf '%s\n' "$XDG_CONFIG_HOME/plasma-org.kde.plasma.desktop-appletsrc"
}

windows_modern_layout_present() {
    local layout
    layout="$(plasma_layout_file)"
    [ -f "$layout" ] || return 1
    grep -Eq 'org\.kde\.windowsmodern\.' "$layout"
}

backup_plasma_layout() {
    local layout
    layout="$(plasma_layout_file)"
    [ -f "$layout" ] || return 0
    local backup_dir="$XDG_STATE_HOME/windows-modern/layout-backups"
    ensure_dir "$backup_dir"

    # Avoid accumulating identical backups on repeated idempotent installs.
    local latest=""
    latest="$(ls -1t "$backup_dir"/plasma-org.kde.plasma.desktop-appletsrc.* 2>/dev/null | head -n1 || true)"
    if [ -n "$latest" ] && cmp -s "$layout" "$latest"; then
        info "Existing identical Plasma layout backup retained: $latest"
        return 0
    fi

    local stamp backup
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="$backup_dir/plasma-org.kde.plasma.desktop-appletsrc.$stamp"
    cp -a -- "$layout" "$backup"
    info "Backed up current Plasma layout to $backup"
}

active_lookandfeel_id() {
    local id=""
    if command -v kreadconfig6 &>/dev/null; then
        id="$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage 2>/dev/null || true)"
    elif [ -f "$XDG_CONFIG_HOME/kdeglobals" ]; then
        id="$(awk -F= '/^LookAndFeelPackage=/{print $2; exit}' "$XDG_CONFIG_HOME/kdeglobals" 2>/dev/null || true)"
    fi
    printf '%s\n' "$id"
}

restore_default_theme_if_active() {
    [ "$UID" -ne 0 ] || return 0
    local current
    current="$(active_lookandfeel_id)"
    case "$current" in
        org.kde.windowsmodern.dark|org.kde.windowsmodern.light)
            command -v plasma-apply-lookandfeel &>/dev/null || {
                err "Windows Modern is active, but plasma-apply-lookandfeel is unavailable; refusing to remove the active theme."
                return 1
            }
            info "Windows Modern is active; restoring Breeze before removing its assets."
            if ! plasma-apply-lookandfeel -a org.kde.breeze.desktop >/dev/null 2>&1; then
                err "Could not restore Breeze; refusing to remove the active Windows Modern theme."
                return 1
            fi
            ;;
    esac
}

apply_lookandfeel() {
    local id="$1"
    local reset_flag=""
    [ "${2:-}" = "reset" ] && reset_flag="--resetLayout"
    [ "$UID" -ne 0 ] || { warn "Running as root; apply the theme manually from the user session."; return 0; }
    command -v plasma-apply-lookandfeel &>/dev/null || {
        err "plasma-apply-lookandfeel is required to apply the global theme automatically."
        return 1
    }
    [ -z "$reset_flag" ] || backup_plasma_layout
    info "Applying $id ${reset_flag:+with layout reset}..."
    if [ -n "$reset_flag" ]; then
        plasma-apply-lookandfeel -a "$id" "$reset_flag"
    else
        plasma-apply-lookandfeel -a "$id"
    fi
    if ! bash "$SRC_DIR/scripts/set-wallpaper.sh"; then
        warn "Wallpaper could not be applied; the theme itself was applied successfully."
    fi
}

apply_kvantum_engine() {
    local variant="${1:-dark}"
    [ "$UID" -ne 0 ] || return 0
    command -v kwriteconfig6 &>/dev/null || { warn "kwriteconfig6 not found; Application Style was not changed."; return 0; }
    local style=kvantum
    [ "$variant" = "dark" ] && style=kvantum-dark
    step "Setting Application Style → $style"
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle "$style"
}

post_kwin_borders() {
    [ "$UID" -ne 0 ] || return 0
    command -v kwriteconfig6 &>/dev/null || return 0
    step "KWin border size → Tiny"
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize Tiny
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto false
    if command -v dbus-send &>/dev/null; then
        dbus-send --session --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
    fi
}

restore_kwin_borders_if_needed() {
    [ "$UID" -ne 0 ] || return 0
    local current
    current="$(active_lookandfeel_id)"
    case "$current" in
        org.kde.windowsmodern.dark|org.kde.windowsmodern.light)
            command -v kwriteconfig6 &>/dev/null || {
                err "Windows Modern is active, but kwriteconfig6 is unavailable; KWin border state cannot be safely restored."
                return 1
            }
            kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize Normal
            kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto true
            if command -v dbus-send &>/dev/null; then
                dbus-send --session --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
            fi
            ;;
    esac
}

ask_theme_variant() {
    if ! is_interactive; then
        echo dark
        return
    fi
    echo "" >&2
    echo -e "${BOLD}Choose the Windows Modern theme variant${RESET}" >&2
    echo -e "  1) Light" >&2
    echo -e "  2) Dark" >&2
    read -r -p "  Choice [2]: " choice
    choice="${choice:-2}"
    case "$choice" in
        1|light|Light) echo light ;;
        2|dark|Dark) echo dark ;;
        *) err "Invalid theme choice: $choice"; return 1 ;;
    esac
}

lookfeel_id() {
    case "$1" in
        light) echo org.kde.windowsmodern.light ;;
        dark) echo org.kde.windowsmodern.dark ;;
        *) err "Invalid theme variant: $1"; return 1 ;;
    esac
}
