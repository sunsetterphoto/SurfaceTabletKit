#!/usr/bin/env bash
# Builds touch-anchor and installs it as a system service. Idempotent.
#   ./apply.sh            build + install + (re)start
#   ./apply.sh --remove   stop and remove the service
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
if [[ "${1:-}" == "--remove" ]]; then
    as_root systemctl disable --now touch-anchor.service 2>/dev/null || true
    as_root rm -f /etc/systemd/system/touch-anchor.service /usr/local/bin/touch-anchor
    as_root systemctl daemon-reload; echo "Removed."; exit 0
fi
need_rpms gcc libevdev-devel pkgconf-pkg-config
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# shellcheck disable=SC2046
gcc -O2 -Wall -Wextra $(pkg-config --cflags libevdev) -o "$TMP/touch-anchor" "$HERE/touch-anchor.c" $(pkg-config --libs libevdev)
as_root install -Dm755 "$TMP/touch-anchor" /usr/local/bin/touch-anchor
as_root install -Dm644 "$HERE/touch-anchor.service" /etc/systemd/system/touch-anchor.service
as_root systemctl daemon-reload
as_root systemctl enable touch-anchor.service
as_root systemctl restart touch-anchor.service   # restart, not enable --now: picks up a new binary
sleep 1
systemctl is-active touch-anchor.service
journalctl -u touch-anchor.service -n 2 --no-pager -o cat
echo "Restart apps (or log out and in) that already went through a suspend before this."
