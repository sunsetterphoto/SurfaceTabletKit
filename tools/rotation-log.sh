#!/usr/bin/env bash
# Diagnostics: logs accelerometer claims/releases on the system bus, screen rotations
# (ApplyMonitorsConfig + current transform), sensor orientation, suspend and USB keyboard
# (type cover) changes into one time-stamped file, for 4 hours.
#   tools/rotation-log.sh [logfile]   (needs sudo for dbus-monitor on the system bus)
OUT="${1:-$HOME/.local/state/surfacetabletkit/rotation-$(date +%F-%H%M).log}"; mkdir -p "$(dirname "$OUT")"
ts() { while IFS= read -r l; do printf '%s %s\n' "$(date +%T.%3N)" "$l"; done; }
END=14400
sudo -n timeout $END dbus-monitor --system "type='method_call',interface='net.hadess.SensorProxy'" 2>/dev/null \
  | grep --line-buffered -E 'member=(Claim|Release)Accelerometer' | sed -u -E 's/.*sender=([^ ]+).*member=([A-Za-z]+).*/CLAIM  \1 \2/' | ts >> "$OUT" &
timeout $END dbus-monitor --session "type='method_call',member='ApplyMonitorsConfig'" 2>/dev/null \
  | grep --line-buffered 'member=ApplyMonitorsConfig' | sed -u 's/.*/APPLY  ApplyMonitorsConfig/' | ts >> "$OUT" &
timeout $END monitor-sensor --accel 2>&1 | grep --line-buffered -E 'orientation' | sed -u 's/^/SENSOR /' | ts >> "$OUT" &
timeout $END journalctl -f -n0 -o cat 2>/dev/null \
  | grep --line-buffered -E 'PM: suspend (entry|exit)|USB disconnect|New USB device found|Session .*(locked|unlocked)|Simulated Right Button as|evdev-rce.*Started|Lock screen' \
  | sed -u 's/^/EVENT  /' | ts >> "$OUT" &
LAST=""
for ((i=0;i<END/5;i++)); do
  T=$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
      --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null | grep -oE '\(0, 0, [0-9.]+, uint32 [0-9]' | grep -oE '[0-9]$')
  [[ "$T" != "$LAST" ]] && echo "$(date +%T.%3N) DISPLAY transform=$T" >> "$OUT" && LAST=$T
  sleep 5
done
wait
