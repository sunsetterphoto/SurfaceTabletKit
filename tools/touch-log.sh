#!/usr/bin/env bash
# Diagnostics: logs every touch event of every touch device (also across suspend, when devices
# are re-created) plus lid / power key / suspend from the journal, time-stamped, for 4 hours.
# Use it to decide whether a device needs modules/touch-anchor: if DEVICE_REMOVED/DEVICE_ADDED of
# the touchscreen show up right after "PM: suspend exit", it does.
#   tools/touch-log.sh [logfile]      (needs sudo for libinput)
mkdir -p "$HOME/.local/state/surfacetabletkit"
OUT="${1:-$HOME/.local/state/surfacetabletkit/touch-$(date +%F-%H%M).log}"
ts() { while IFS= read -r l; do printf '%s %s\n' "$(date +%T.%3N)" "$l"; done; }
timeout 14400 journalctl -f -n0 -o cat 2>/dev/null \
  | grep --line-buffered -E 'Lid (closed|opened)|Power key|PM: suspend (entry|exit)|iptsd@.*(Started|Stopping)|segfault' \
  | sed -u 's/^/EVENT /' | ts >> "$OUT" &
sudo -n timeout 14400 stdbuf -oL libinput debug-events 2>&1 \
  | grep --line-buffered -E 'TOUCH_(DOWN|UP|CANCEL)|DEVICE_(ADDED|REMOVED).*(Touch|IPTSD)' | ts >> "$OUT"
wait
