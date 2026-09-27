#!/bin/bash
# Windows Modern unified installer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/scripts/install-lib.sh"

install_component() {
    local name="$1"
    local script="$SCRIPT_DIR/scripts/install-${name}.sh"
    if ! wm_has_component "$name" || [ ! -x "$script" ]; then
        err "Unknown component: $name"
        return 1
    fi
    bash "$script" || {
        err "Component '$name' failed. Re-run: ./install.sh $name"
        return 1
    }
}

install_everything() {
    local variant="${1:-}"
    [ -n "$variant" ] || variant="$(ask_theme_variant)"
    local theme
    theme="$(lookfeel_id "$variant")"

    info "Installing everything ($variant)..."
    export WM_BATCH=1

    info "[1/3] Installing themes, icons, and applets..."
    install_component themes
    install_component icons
    install_component showdesk
    install_component systray
    install_component icontasks
    install_component digitalclock

    info "[2/3] Installing layout and global themes..."
    install_component layout
    install_component lookfeel
    unset WM_BATCH

    info "[3/3] Applying theme ($variant)..."
    # Do not destroy an already configured Windows Modern panel on repeat runs.
    # The first run creates it through --resetLayout; subsequent runs only refresh
    # appearance and installed applets.
    if windows_modern_layout_present; then
        apply_lookandfeel "$theme"
    else
        apply_lookandfeel "$theme" reset
    fi
    apply_kvantum_engine "$variant"
    post_kwin_borders
    restart_plasmashell

    echo ""
    info "Everything installed successfully."
    echo "Enable Panel Configuration → Floating → Applets Only for the Win11 inset look."
}

install_all_applets() {
    export WM_BATCH=1
    info "Installing all applets..."
    for component in "${WM_APPLETS[@]}"; do
        install_component "$component"
    done
    unset WM_BATCH
    restart_plasmashell
}

menu() {
    if ! is_interactive; then
        info "No interactive terminal detected; installing everything with the default Dark variant."
        install_everything dark
        return
    fi

    echo ""
    echo -e "${BOLD}${BLUE}Windows Modern — Unified Installer${RESET}"
    echo ""
    echo "  1) Everything"
    echo "  2) Themes"
    echo "  3) Icon pack"
    echo "  4) Global themes"
    echo "  5) Panel layout template"
    echo ""
    echo "  6) All applets"
    echo "  7) Show Desktop"
    echo "  8) System Tray"
    echo "  9) Icon Tasks"
    echo " 10) Digital Clock"
    echo ""
    echo "  0) Quit"
    echo ""
    read -r -p "  Choice [1]: " choice
    choice="${choice:-1}"
    case "$choice" in
        1) install_everything ;;
        2) install_component themes ;;
        3) install_component icons ;;
        4) install_component lookfeel ;;
        5) install_component layout ;;
        6) install_all_applets ;;
        7) install_component showdesk ;;
        8) install_component systray ;;
        9) install_component icontasks ;;
        10) install_component digitalclock ;;
        0) exit 0 ;;
        *) err "Invalid choice: $choice"; exit 1 ;;
    esac
}

variant=""
component=""
for arg in "$@"; do
    case "$arg" in
        --light|--dark)
            requested="${arg#--}"
            if [ -n "$variant" ] && [ "$variant" != "$requested" ]; then
                err "Conflicting theme flags: --$variant and --$requested"
                exit 2
            fi
            variant="$requested"
            ;;
        -h|--help)
            echo "Usage: ./install.sh [all|component] [--light|--dark]"
            echo ""
            echo "Components: ${WM_COMPONENTS[*]}"
            exit 0
            ;;
        all)
            [ -z "$component" ] || { err "Only one component may be specified."; exit 2; }
            component=all
            ;;
        systemtray)
            [ -z "$component" ] || { err "Only one component may be specified."; exit 2; }
            component=systray
            ;;
        *)
            [ -z "$component" ] || { err "Too many components: $component $arg"; exit 2; }
            component="$arg"
            ;;
    esac
done

if [ -z "$component" ] && [ -n "$variant" ]; then
    component=all
fi
if [ -n "$variant" ] && [ -n "$component" ] && [ "$component" != all ]; then
    err "Theme flags may only be used with 'all'."
    exit 2
fi

case "${component:-menu}" in
    menu) menu ;;
    all) install_everything "$variant" ;;
    applets) install_all_applets ;;
    *) install_component "$component" ;;
esac
