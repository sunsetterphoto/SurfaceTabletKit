#!/usr/bin/env bash
# Installs the portrait top-bar extension (a copy, no link into the repo) and enables it.
#   ./apply.sh           install   ·   ./apply.sh --remove   remove
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
require_user
UUID=panel-portrait@surfacetabletkit
if [[ "${1:-}" == "--remove" ]]; then
    disable_extensions "$UUID"; rm -rf "${EXT_DIR:?}/$UUID"; echo "Removed (gone after logging out and in)"; exit 0
fi
rm -rf "${EXT_DIR:?}/$UUID"; mkdir -p "$EXT_DIR"; cp -a "$HERE/$UUID" "$EXT_DIR/"
enable_extensions "$UUID"
ok "installed $EXT_DIR/$UUID - takes effect after logging out and in"
