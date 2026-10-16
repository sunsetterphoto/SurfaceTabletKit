#!/usr/bin/env bash
# Copies the system extension screen-rotate (RPM gnome-shell-extension-screen-autorotate) to
# ~/.local/share/gnome-shell/extensions/ and patches sensorProxy.js to use its own system-bus
# connection, so mutter can no longer drop the extension's accelerometer claim.
# The copy in the user directory takes precedence over /usr/share. Idempotent.
# Re-run after every RPM update of the extension. Takes effect after logging out and in.
#   ./apply.sh            install
#   ./apply.sh --remove   delete the copy -> the unpatched system original is used again
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
require_user

UUID=screen-rotate@shyzus.github.io
SRC=/usr/share/gnome-shell/extensions/$UUID
DST=$EXT_DIR/$UUID
if [[ "${1:-}" == "--remove" ]]; then
    rm -rf "$DST" "$STATE_DIR/screen-rotate-built-from.txt"
    echo "Removed; from the next login $SRC is used again."; exit 0
fi
need_rpms gnome-shell-extension-screen-autorotate patch
RPMV="$(rpm -qf --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$SRC")"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp -a "$SRC" "$TMP/$UUID"
patch -s -d "$TMP/$UUID" -p1 < "$HERE/sensorProxy.patch" \
    || die "patch does not apply to $RPMV - the extension changed, port sensorProxy.patch by hand"
rm -rf "$DST"; mkdir -p "$EXT_DIR"; cp -a "$TMP/$UUID" "$DST"
mkdir -p "$STATE_DIR"; echo "$RPMV" > "$STATE_DIR/screen-rotate-built-from.txt"
enable_extensions "$UUID"
ok "installed $DST (from $RPMV). Takes effect after logging out and in."
