#!/usr/bin/env bash
# Installs the daily linux-surface repository watch as a systemd user timer (a copy of
# check.sh in ~/.local/libexec, nothing points into the repository).
#   ./apply.sh            install + enable   ·   ./apply.sh --remove   remove
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
require_user
BIN="$HOME/.local/libexec/surfacetabletkit/linux-surface-watch"
UNITS="$HOME/.config/systemd/user"
if [[ "${1:-}" == "--remove" ]]; then
    systemctl --user disable --now linux-surface-watch.timer 2>/dev/null || true
    rm -f "$BIN" "$UNITS/linux-surface-watch."{service,timer}; systemctl --user daemon-reload; echo "Removed."; exit 0
fi
install -Dm755 "$HERE/check.sh" "$BIN"
install -Dm644 "$HERE/systemd-user/linux-surface-watch.service" "$UNITS/linux-surface-watch.service"
install -Dm644 "$HERE/systemd-user/linux-surface-watch.timer" "$UNITS/linux-surface-watch.timer"
systemctl --user daemon-reload
systemctl --user enable --now linux-surface-watch.timer
systemctl --user start linux-surface-watch.service
tail -1 "$STATE_DIR/linux-surface-watch.log"
