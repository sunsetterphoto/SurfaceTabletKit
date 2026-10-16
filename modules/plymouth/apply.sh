#!/usr/bin/env bash
# Boot splash: white Tux with a pear cut out of its belly and a thin macOS-style
# progress bar (boot only). Installs the Plymouth theme and rebuilds the initramfs of the
# running kernel; later kernels pick the theme up automatically through dracut. Idempotent.
#
#   ./apply.sh             install and activate
#   ./apply.sh --restore   go back to the theme that was active before the first install
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"

NAME=surfacetabletkit
DEST=/usr/share/plymouth/themes/$NAME
PREV="$ROOT_STATE_DIR/plymouth-previous-theme"

need_rpms plymouth-plugin-script plymouth-scripts

if [[ "${1:-}" == "--restore" ]]; then
    old="$(cat "$PREV" 2>/dev/null || echo bgrt)"
    log "Restoring Plymouth theme '$old' and rebuilding the initramfs for $(uname -r)"
    as_root plymouth-set-default-theme -R "$old"
    as_root rm -rf "$DEST"
    exit 0
fi

current="$(plymouth-set-default-theme 2>/dev/null || true)"
if [[ "$current" != "$NAME" && ! -f "$PREV" ]]; then
    as_root install -d -m 755 "$ROOT_STATE_DIR"
    echo "${current:-bgrt}" | as_root tee "$PREV" >/dev/null
    ok "previous theme '${current:-bgrt}' recorded for --restore"
fi

grep -q 'rhgb' /proc/cmdline || warn "'rhgb' is not on the kernel command line - Plymouth will not show a splash"

log "Installing theme to $DEST"
as_root rm -rf "$DEST"
as_root install -d -m 755 "$DEST"
as_root install -m 644 "$HERE/$NAME"/*.plymouth "$HERE/$NAME"/*.script "$HERE/$NAME"/*.png "$DEST"/

log "Activating it and rebuilding the initramfs for $(uname -r)"
as_root plymouth-set-default-theme -R "$NAME"

log "Check"
plymouth-set-default-theme
as_root lsinitrd "/boot/initramfs-$(uname -r).img" | grep "plymouth/themes/$NAME/" | awk '{print $NF}'
echo "To re-render the logo after editing tux.svg: rsvg-convert -h 640 $NAME/tux.svg -o $NAME/tux.png"
