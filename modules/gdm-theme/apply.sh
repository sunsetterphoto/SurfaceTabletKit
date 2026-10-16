#!/usr/bin/env bash
# Login and lock screen in the WhiteSur look: runs WhiteSur's own `tweaks.sh -g`, which
# replaces /usr/share/gnome-shell/gnome-shell-theme.gresource (original kept as .bak).
# Every gnome-shell package update puts the stock file back - run this again afterwards.
#   ./apply.sh            apply
#   ./apply.sh --restore  put the original gresource back
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
GR=/usr/share/gnome-shell/gnome-shell-theme.gresource
if [[ "${1:-}" == "--restore" ]]; then
    [[ -f "$GR.bak" ]] || die "no $GR.bak"
    as_root cp "$GR.bak" "$GR"; ok "original login screen restored (visible at the next lock/login)"; exit 0
fi
need_rpms git sassc glib2-devel
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
log "Cloning WhiteSur-gtk-theme (MIT)"
git clone --depth=1 -q https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$TMP/WhiteSur"
log "Installing the GDM theme (sudo, modifies $GR)"
( cd "$TMP/WhiteSur" && as_root ./tweaks.sh -g )
ok "applied - visible at the next lock or login. Undo: $0 --restore"
