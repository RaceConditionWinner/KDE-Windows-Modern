#!/bin/bash
# ───────────────────────────────────────────────────────────────────
#  verify-all.sh — check all Windows Modern components are healthy
# ───────────────────────────────────────────────────────────────────
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN="\033[32m"; RED="\033[31m"; YELLOW="\033[33m"; BOLD="\033[1m"; RESET="\033[0m"
FAILURES=0
pass() { echo -e "  ${GREEN}✓${RESET} $1"; }
fail() { echo -e "  ${RED}✗${RESET} $1"; FAILURES=$((FAILURES + 1)); }
warn() { echo -e "  ${YELLOW}~${RESET} $1"; }

echo ""
echo -e "${BOLD}Windows Modern — Project Health Check${RESET}"
echo "======================================"
echo ""

# Themes
echo " Themes:"
[ -d "$SCRIPT_DIR/aurorae/windows-modern-dark-aurorae" ] && pass "Aurorae dark" || fail "Aurorae dark missing"
[ -f "$SCRIPT_DIR/color-schemes/WindowsModernDark.colors" ] && pass "Color scheme dark" || fail "Color scheme dark missing"
[ -d "$SCRIPT_DIR/Kvantum/Windows-modern" ] && pass "Kvantum theme" || fail "Kvantum theme missing"
[ -d "$SCRIPT_DIR/plasma/desktoptheme/Windows-modern-dark" ] && pass "Plasma theme dark" || fail "Plasma theme dark missing"

# Look-and-feel
echo ""
echo " Global themes:"
[ -d "$SCRIPT_DIR/plasma/look-and-feel/org.kde.windowsmodern.dark" ] && pass "Dark theme" || fail "Dark theme missing"
[ -d "$SCRIPT_DIR/plasma/look-and-feel/org.kde.windowsmodern.light" ] && pass "Light theme" || fail "Light theme missing"

# Layout
echo ""
echo " Layout:"
[ -d "$SCRIPT_DIR/plasma/layout-templates/org.kde.windowsmodern.panel" ] && pass "Panel layout" || fail "Panel layout missing"

# Applets
echo ""
echo " Applets:"
for applet in showdesktop digitalclock icontasks; do
    d="$SCRIPT_DIR/plasma/applets/org.kde.windowsmodern.$applet"
    [ -d "$d" ] && [ -f "$d/metadata.json" ] && pass "$applet" || fail "$applet missing"
done


# Compiled applets
echo ""
echo " Compiled Applets:"
for applet in systemtray; do
    d="$SCRIPT_DIR/plasma/applets/org.kde.windowsmodern.$applet"
    [ -d "$d" ] && [ -f "$d/CMakeLists.txt" ] && [ -x "$d/dev.sh" ] && [ -x "$d/verify.sh" ] && pass "$applet source/build/verify wiring" || fail "$applet source/build/verify wiring missing"
done

# Plasma 6 metadata and source invariants
echo ""
echo " Plasma 6 compatibility:"
if python3 - "$SCRIPT_DIR" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
for meta in (root / "plasma/applets").glob("*/metadata.json"):
    data = json.loads(meta.read_text())
    plugin = data.get("KPlugin", {})
    if not plugin.get("Id"):
        raise SystemExit(f"{meta}: missing KPlugin.Id")
    if data.get("KPackageStructure") != "Plasma/Applet":
        raise SystemExit(f"{meta}: invalid KPackageStructure")
    if data.get("X-Plasma-API-Minimum-Version") != "6.0":
        raise SystemExit(f"{meta}: missing/invalid Plasma 6 API minimum")
print("metadata.json invariants valid")
PY
then
    pass "Plasma applet metadata"
else
    fail "Plasma applet metadata validation failed"
fi

if python3 - "$SCRIPT_DIR" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
expected = {
    "plasma/desktoptheme/Windows-modern-dark/metadata.json": ("Plasma/Theme", "Windows-modern-dark"),
    "plasma/desktoptheme/Windows-modern-light/metadata.json": ("Plasma/Theme", "Windows-modern-light"),
    "plasma/look-and-feel/org.kde.windowsmodern.dark/metadata.json": ("Plasma/LookAndFeel", "org.kde.windowsmodern.dark"),
    "plasma/look-and-feel/org.kde.windowsmodern.light/metadata.json": ("Plasma/LookAndFeel", "org.kde.windowsmodern.light"),
    "plasma/layout-templates/org.kde.windowsmodern.panel/metadata.json": ("Plasma/LayoutTemplate", "org.kde.windowsmodern.panel"),
}
for rel, (structure, plugin_id) in expected.items():
    p = root / rel
    if not p.is_file():
        raise SystemExit(f"{rel}: missing metadata.json")
    data = json.loads(p.read_text())
    if data.get("KPackageStructure") != structure:
        raise SystemExit(f"{rel}: expected KPackageStructure={structure!r}")
    if data.get("KPlugin", {}).get("Id") != plugin_id:
        raise SystemExit(f"{rel}: KPlugin.Id does not match {plugin_id!r}")
print("theme/layout metadata invariants valid")
PY
then
    pass "Plasma theme and layout metadata"
else
    fail "Plasma theme/layout metadata validation failed"
fi

versioned_imports="$(mktemp)"
if grep -RInE '^[[:space:]]*import (Qt[A-Za-z0-9_.]+|org\.kde\.[A-Za-z0-9_.]+) [0-9]+(\.[0-9]+)*' "$SCRIPT_DIR/plasma" --include='*.qml' >"$versioned_imports" 2>/dev/null; then
    fail "versioned QML imports remain in Plasma 6 applets"
    sed 's#^#    #' "$versioned_imports"
else
    pass "QML imports use Plasma 6 unversioned form"
fi
rm -f "$versioned_imports"

if command -v node &>/dev/null; then
    js_failed=0
    while IFS= read -r js; do
        # QML JavaScript files may contain .pragma/.import directives that
        # Node does not understand. Strip those directives for syntax-only
        # validation while leaving the actual JavaScript intact.
        tmp_js="$(mktemp --suffix=.js)"
        sed -E '/^[[:space:]]*\.(pragma|import)\b/d' "$js" > "$tmp_js"
        if ! node --check "$tmp_js" >/dev/null 2>&1; then
            fail "JavaScript syntax error: ${js#$SCRIPT_DIR/}"
            js_failed=1
        fi
        rm -f "$tmp_js"
    done < <(find "$SCRIPT_DIR/plasma" -type f -name '*.js' -print)
    [ "$js_failed" -eq 0 ] && pass "Plasma JavaScript syntax"
else
    warn "node not installed; Plasma JavaScript syntax was not checked"
fi

# Installer wiring
echo ""
echo " Installer wiring:"
if python3 - "$SCRIPT_DIR" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
components = ["themes", "icons", "lookfeel", "layout", "showdesk", "systray", "icontasks", "digitalclock"]
install = (root / "install.sh").read_text()
uninstall = (root / "uninstall.sh").read_text()
helper = (root / "scripts/install-lib.sh").read_text()
match = re.search(r"WM_COMPONENTS=\(([^)]*)\)", helper, re.S)
if not match:
    raise SystemExit("WM_COMPONENTS registry missing")
registry = re.findall(r"[A-Za-z0-9_-]+", match.group(1))
if registry != components:
    raise SystemExit(f"component registry drift: {registry!r}")
for component in components:
    script = root / f"scripts/install-{component}.sh"
    if not script.is_file() or not (script.stat().st_mode & 0o111):
        raise SystemExit(f"missing/non-executable installer: {component}")
    source = script.read_text()
    if "install-lib.sh" not in source:
        raise SystemExit(f"installer does not source shared library: {component}")
    if not re.search(rf"\b{re.escape(component)}\)", uninstall):
        raise SystemExit(f"uninstall case missing: {component}")
print("installer registry and component wiring valid")
PY
then
    pass "installer registry and component wiring"
else
    fail "installer registry/component wiring validation failed"
fi


if grep -Eq 'SO_PATH=.*plasma/applets/\$APP_ID\.so' "$SCRIPT_DIR/plasma/applets/org.kde.windowsmodern.systemtray/verify.sh"; then
    fail "System Tray verifier duplicates the plasma/applets plugin path"
else
    pass "System Tray verifier uses the resolved plugin directory directly"
fi

if python3 - "$SCRIPT_DIR" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
checks = {
    "plasma/applets/org.kde.windowsmodern.systemtray": "org.kde.windowsmodern.systemtray",
    "plasma/applets/org.kde.windowsmodern.icontasks": "org.kde.windowsmodern.icontasks",
}
for rel, expected in checks.items():
    d = root / rel
    meta = (d / "metadata.json").read_text()
    cmake = (d / "CMakeLists.txt").read_text()
    if f'"Id": "{expected}"' not in meta:
        raise SystemExit(f"{rel}: metadata ID mismatch")
    if not re.search(rf"plasma_add_applet\(\s*{re.escape(expected)}\b", cmake):
        raise SystemExit(f"{rel}: CMake target mismatch")
    if not (d / "dev.sh").is_file():
        raise SystemExit(f"{rel}: dev.sh missing")
print("compiled applet identity/build wiring valid")
PY
then
    pass "compiled applet identity/build wiring"
else
    fail "compiled applet identity/build wiring validation failed"
fi

stock_task_id="$(mktemp)"
if grep -RInE 'org\.kde\.plasma\.icontasks' \
    "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/uninstall.sh" "$SCRIPT_DIR/scripts" \
    "$SCRIPT_DIR/plasma/layout-templates" "$SCRIPT_DIR/plasma/look-and-feel" \
    "$SCRIPT_DIR/plasma/applets/org.kde.windowsmodern.icontasks" >"$stock_task_id" 2>/dev/null; then
    fail "Windows Modern wiring still references the distro-owned org.kde.plasma.icontasks ID"
    sed 's#^#    #' "$stock_task_id"
else
    pass "stock Plasma task-manager ID is not overwritten by Windows Modern wiring"
fi
rm -f "$stock_task_id"

# Every shell script must parse before release.
shell_failed=0
while IFS= read -r script; do
    if ! bash -n "$script"; then
        fail "shell syntax error: ${script#$SCRIPT_DIR/}"
        shell_failed=1
    fi
done < <(find "$SCRIPT_DIR" -type f -name '*.sh' -not -path '*/.git/*' -not -path '*/dist/*' -print)
[ "$shell_failed" -eq 0 ] && pass "shell script syntax"

if python3 - "$SCRIPT_DIR" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
files = [root / "install.sh", root / "uninstall.sh", *root.glob("scripts/*.sh"), *root.glob("plasma/applets/*/*.sh")]
for path in files:
    if not path.is_file():
        continue
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        if re.match(r"^\s*local\s+", line) and line.count("=") > 1 and not line.lstrip().startswith("local -"):
            raise SystemExit(f"{path}:{lineno}: multiple local assignments are forbidden under set -u")
print("shell local-declaration hygiene valid")
PY
then
    pass "shell local-declaration hygiene"
else
    fail "unsafe multiple local assignments found"
fi

# Removed components must have no live source/documentation wiring.
if grep -RInE --exclude-dir=.git --exclude-dir=icons --exclude-dir=dist --exclude=package.sh \
    'app-decorations|org\.kde\.windowsmodern\.startmenu|org\.kde\.windowsmodern\.lockscreen|sessionlock|plasma-login-manager|install-greeter|uninstall-greeter|update-plm|greetersystem|STARTMENU_PLAN|third_party/plasma-login-manager' \
    "$SCRIPT_DIR/README.md" "$SCRIPT_DIR/ATTRIBUTION.md" "$SCRIPT_DIR/docs" \
    "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/uninstall.sh" \
    "$SCRIPT_DIR/scripts" "$SCRIPT_DIR/plasma" "$SCRIPT_DIR/.gitignore" >/tmp/windows-modern-removed-refs.txt 2>/dev/null; then
    fail "stale removed-component wiring found"
    sed 's#^#    #' /tmp/windows-modern-removed-refs.txt
else
    pass "no stale removed-component wiring"
fi
rm -f /tmp/windows-modern-removed-refs.txt

if [ "$FAILURES" -ne 0 ]; then
    echo ""
    echo -e "  ${RED}Health check failed with $FAILURES issue(s).${RESET}"
    exit 1
fi

pass "Project health check passed"
