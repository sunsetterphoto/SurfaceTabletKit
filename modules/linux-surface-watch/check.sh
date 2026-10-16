#!/usr/bin/env bash
# Checks daily whether linux-surface already has a repository for the NEXT Fedora release.
# Upgrading Fedora before that silently drops the Surface kernel (the repo uses f$releasever
# with skip_if_unavailable=1). When the repo answers HTTP 200: desktop notification, marker
# file, and the timer disables itself.
set -uo pipefail
NEXT=$(( $(rpm -E %fedora) + 1 ))
URL="https://pkg.surfacelinux.com/fedora/f$NEXT/"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/surfacetabletkit"
mkdir -p "$STATE"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$URL")"
printf '%s  HTTP %s  %s\n' "$(date '+%F %H:%M')" "$code" "$URL" >> "$STATE/linux-surface-watch.log"
if [[ "$code" == 200 ]]; then
    notify-send -u critical -a "Surface" "linux-surface repository for Fedora $NEXT is online" \
        "Upgrading to Fedora $NEXT keeps the Surface kernel now. Afterwards re-run the kernel modules of SurfaceTabletKit."
    touch "$STATE/fedora-$NEXT-available"
    systemctl --user disable --now linux-surface-watch.timer
fi
