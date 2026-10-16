#!/usr/bin/env bash
# Only for systems with KDE Plasma installed next to GNOME. Two protections:
#   1. Plasma's kded module "gtkconfig" writes Plasma's theme into GNOME's gsettings at every
#      Plasma login (gtk-theme, icons, cursor, fonts) - it is switched off.
#   2. xwaylandvideobridge (comes with Plasma) autostarts in GNOME too and maps an invisible
#      full-screen X11 window: top bar and dock disappear, desktop icons stop taking clicks.
#      A same-named user autostart file with OnlyShowIn=KDE; shadows the system one.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
require_user
rpm -q plasma-workspace &>/dev/null || { ok "KDE Plasma is not installed - nothing to do"; exit 0; }

log "1. kded gtkconfig off"
# kded6 reads kded5rc (measured), not kded6rc
kwriteconfig6 --file kded5rc --group Module-gtkconfig --key autoload false
qdbus-qt6 org.kde.kded6 /kded org.kde.kded6.setModuleAutoloading gtkconfig false &>/dev/null || true
ok "~/.config/kded5rc: [Module-gtkconfig] autoload=false"

log "2. xwaylandvideobridge only in Plasma"
SYS=/etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop
if [[ -f "$SYS" ]]; then
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/org.kde.xwaylandvideobridge.desktop" <<'DESKTOP'
[Desktop Entry]
# Shadows /etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop (same file name on purpose).
# Under GNOME the bridge maps an invisible full-screen window; OnlyShowIn keeps it in Plasma.
Type=Application
Name=Xwayland Video Bridge
Exec=xwaylandvideobridge
Icon=xwaylandvideobridge
StartupNotify=false
NoDisplay=true
X-KDE-autostart-phase=2
OnlyShowIn=KDE;
DESKTOP
    ok "shadowed $SYS"
    # pgrep -x cannot match it: the name has 21 chars, the kernel truncates comm to 15
    [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && pkill -f '^/usr/bin/xwaylandvideobridge$' || true
else
    ok "xwaylandvideobridge not installed"
fi
