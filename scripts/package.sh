#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  package.sh — build per-component ZIPs for KDE Store / GitHub release
#
#  Usage:
#    ./scripts/package.sh            # build all components
#    ./scripts/package.sh <name>...   # build specific components
#    ./scripts/package.sh --list      # list available components
#
#  Output: dist/<Component>-<Version>.zip
# ───────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$SRC_DIR/dist"

BOLD="\033[1m"; GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; CYAN="\033[36m"; RESET="\033[0m"
info()  { echo -e "${GREEN}==>${RESET} ${BOLD}$*${RESET}"; }
step()  { echo -e "${CYAN}  >>${RESET} $*"; }
warn()  { echo -e "${YELLOW}==>${RESET} $*"; }
err()   { echo -e "${RED}==>${RESET} $*" >&2; }

# Extract version from a metadata file (json or desktop).
get_version() {
    local meta="$1"
    if [[ "$meta" == *.json ]]; then
        python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['KPlugin'].get('Version',''))" "$meta" 2>/dev/null \
            || echo ""
    else
        grep -E '^Version=' "$meta" 2>/dev/null | head -1 | cut -d= -f2 || echo ""
    fi
}

# ── Component registry ─────────────────────────────────────────────
# name|source-dir|metadata-file|kde-store-category
# (category blank = GitHub-only)
COMPONENTS=(
    "color-schemes|$SRC_DIR/color-schemes|colorschemes|Color Schemes"
    "icons|$SRC_DIR/icons/windows-modern|index.theme|Icons"
    "aurorae-dark|$SRC_DIR/aurorae/windows-modern-dark-aurorae|metadata.desktop|Aurorae Themes"
    "aurorae-light|$SRC_DIR/aurorae/windows-modern-light-aurorae|metadata.desktop|Aurorae Themes"
    "desktoptheme-dark|$SRC_DIR/plasma/desktoptheme/Windows-modern-dark|metadata.json|Plasma 6 Themes"
    "desktoptheme-light|$SRC_DIR/plasma/desktoptheme/Windows-modern-light|metadata.json|Plasma 6 Themes"
    "wallpaper|$SRC_DIR/wallpaper/Windows-modern|metadata.json|Wallpapers"
    "applet-showdesktop|$SRC_DIR/plasma/applets/org.kde.windowsmodern.showdesktop|metadata.json|Plasma 6 Applets"
    "applet-digitalclock|$SRC_DIR/plasma/applets/org.kde.windowsmodern.digitalclock|metadata.json|Plasma 6 Applets"
    "layout-panel|$SRC_DIR/plasma/layout-templates/org.kde.windowsmodern.panel|metadata.json|Plasma 6 Layout Templates"
    "lookfeel-dark|$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.dark|metadata.json|Global Themes (Plasma 6)"
    "lookfeel-light|$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.light|metadata.json|Global Themes (Plasma 6)"
)

list_components() {
    echo -e "${BOLD}Available components:${RESET}"
    for c in "${COMPONENTS[@]}"; do
        IFS='|' read -r name dir meta cat <<< "$c"
        printf "  %-22s %s\n" "$name" "${cat:-(GitHub only)}"
    done
}

# Build a single component into dist/
build_one() {
    local entry="$1"
    IFS='|' read -r name dir meta cat <<< "$entry"

    if [[ ! -d "$dir" ]]; then
        err "Source dir missing: $dir"
        return 1
    fi

    local version
    if [[ "$meta" == "index.theme" ]]; then
        version="$(get_version "$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.dark/metadata.json")"
    elif [[ "$meta" == "colorschemes" ]]; then
        version="$(get_version "$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.dark/metadata.json")"
    elif [[ -f "$dir/$meta" ]]; then
        version="$(get_version "$dir/$meta")"
    else
        version=""
    fi
    [[ -z "$version" ]] && version="1.0.0"

    local outname="WindowsModern-${name}-${version}.zip"
    local outpath="$DIST_DIR/$outname"

    rm -f "$outpath"
    (cd "$(dirname "$dir")" && zip -qr "$outpath" "$(basename "$dir")")
    step "built $outname  <-  $(basename "$dir")"
    echo "$outpath"
}

# ── Main ────────────────────────────────────────────────────────────
mkdir -p "$DIST_DIR"

case "${1:-}" in
    --help|-h)
        echo "Usage: ./scripts/package.sh [component ...]"
        echo ""
        echo "  no args        Build all distributable KDE Store components and the full GitHub bundle"
        echo "  --list         List component package targets"
        echo "  --help, -h     Show this help"
        echo ""
        list_components
        exit 0
        ;;
    --list)
        list_components
        exit 0
        ;;
esac

if [[ $# -gt 0 ]]; then
    info "Building selected components..."
    for want in "$@"; do
        found=""
        for c in "${COMPONENTS[@]}"; do
            IFS='|' read -r name _ _ _ <<< "$c"
            if [[ "$name" == "$want" ]]; then found="$c"; break; fi
        done
        if [[ -z "$found" ]]; then
            err "Unknown component: $want  (run with --list to see options)"
            exit 1
        fi
        build_one "$found"
    done
else
    info "Building all KDE Store components..."
    for c in "${COMPONENTS[@]}"; do
        build_one "$c"
    done
fi

# GitHub release bundle: full theme tree minus dev/build cruft.
info "Building full GitHub release bundle..."
FULL_VER="$(get_version "$SRC_DIR/plasma/look-and-feel/org.kde.windowsmodern.dark/metadata.json")"
[[ -z "$FULL_VER" ]] && FULL_VER="1.0.0"
FULL_OUT="$DIST_DIR/KDE-Windows-Modern-${FULL_VER}.zip"
rm -f "$FULL_OUT"
(cd "$SRC_DIR" && zip -qr "$FULL_OUT" \
    aurorae color-schemes icons Kvantum plasma wallpaper \
    scripts docs \
    install.sh uninstall.sh verify-all.sh README.md LICENSE AUTHORS ATTRIBUTION.md .gitignore \
    -x '*/build/*' '*/CMakeFiles/*' '*/.git/*' '*/dist/*')
step "built KDE-Windows-Modern-${FULL_VER}.zip  (full bundle)"

# Validate the release bundle itself. This prevents a successful ZIP build
# from regressing into a bundle that cannot run its documented installer.
python3 - "$FULL_OUT" <<'PY'
import sys, zipfile
from pathlib import PurePosixPath

archive = sys.argv[1]
required = {
    "scripts/install-lib.sh",
    "scripts/install-themes.sh",
    "scripts/install-icons.sh",
    "scripts/install-lookfeel.sh",
    "scripts/install-layout.sh",
    "scripts/install-showdesk.sh",
    "scripts/install-systray.sh",
    "scripts/install-icontasks.sh",
    "scripts/install-digitalclock.sh",
    "install.sh",
    "uninstall.sh",
    "verify-all.sh",
}
forbidden_fragments = (
    "app-decorations/",
    "org.kde.windowsmodern.startmenu/",
    "org.kde.windowsmodern.lockscreen/",
    "plasma-login-manager/",
    "install-greeter",
    "uninstall-greeter",
    "install-sessionlock",
    "install-startmenu",
    "update-plm.sh",
)
with zipfile.ZipFile(archive) as zf:
    names = set(zf.namelist())
    missing = sorted(required - names)
    forbidden = sorted(n for n in names if any(frag in n for frag in forbidden_fragments))
    if missing:
        raise SystemExit("release bundle missing required files: " + ", ".join(missing))
    if forbidden:
        raise SystemExit("release bundle contains removed components: " + ", ".join(forbidden))
    bad = zf.testzip()
    if bad:
        raise SystemExit("release bundle has corrupted ZIP entry: " + bad)
print("Release bundle validation passed.")
PY

echo ""
info "Done. Artifacts in ${DIST_DIR}:"
ls -1 "$DIST_DIR" | sed 's/^/    /'
