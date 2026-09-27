#!/bin/bash
# Windows Modern System Tray - standalone compatibility wrapper.
# The repository root installer is the single source of installation logic.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
exec bash "$ROOT_DIR/scripts/install-systray.sh" "$@"
