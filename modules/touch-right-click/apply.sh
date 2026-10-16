#!/usr/bin/env bash
# Builds and installs evdev-rce: touchscreen long-press -> right click, below the compositor,
# so it works everywhere under Wayland (GNOME Shell, Firefox, Electron apps). See README.md.
# The touchscreen name and the wobble tolerance come from the device profile (devices/*.conf)
# or from the environment: TOUCH_DEVICE_WHITELIST="..." TOUCH_UNITS_PER_MM=37 ./apply.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
WL_ENV="${TOUCH_DEVICE_WHITELIST:-}"; UPM_ENV="${TOUCH_UNITS_PER_MM:-}"
detect_device
WHITELIST="${WL_ENV:-${TOUCH_DEVICE_WHITELIST:-}}"
UNITS_PER_MM="${UPM_ENV:-${TOUCH_UNITS_PER_MM:-}}"
if [[ -z "$WHITELIST" || -z "$UNITS_PER_MM" ]]; then
    cat >&2 <<MSG
The touchscreen of this device ($DEVICE_PRODUCT) is not measured yet. Measure it first:
  sudo libinput list-devices      # device with "Capabilities: touch", note name and size in mm
  sudo libinput debug-events      # check that finger events really come from that device
  sudo evtest                     # ABS_MT_POSITION_X range / width in mm = units per mm
then run: TOUCH_DEVICE_WHITELIST="<name>" TOUCH_UNITS_PER_MM=<n> $0
and add both values to devices/<device>.conf.
MSG
    exit 1
fi
FUZZ=$(( UNITS_PER_MM * 27 / 10 ))   # ~2.7 mm

need_rpms gcc make libevdev-devel
BUILD="$(mktemp -d)"; trap 'rm -rf "$BUILD"' EXIT
cp "$HERE/src/"*.c "$HERE/src/"*.h "$HERE/src/Makefile" "$BUILD/"
make -C "$BUILD" all >/dev/null
as_root install -Dm755 "$BUILD/out/evdev-rce" /usr/local/bin/evdev-rce
as_root install -Dm644 "$HERE/evdev-rce.service" /etc/systemd/system/evdev-rce.service
sed -e "s|@FUZZ@|$FUZZ|" -e "s|@WHITELIST@|$WHITELIST|" "$HERE/evdev-rce.sysconfig.in" > "$BUILD/sysconfig"
if [[ -f /etc/sysconfig/evdev-rce ]] && ! cmp -s "$BUILD/sysconfig" /etc/sysconfig/evdev-rce; then
    as_root install -Dm644 "$BUILD/sysconfig" /etc/sysconfig/evdev-rce.new
    warn "/etc/sysconfig/evdev-rce differs and was left alone; the new version is evdev-rce.new"
else
    as_root install -Dm644 "$BUILD/sysconfig" /etc/sysconfig/evdev-rce
fi
as_root systemctl daemon-reload
as_root systemctl enable evdev-rce.service
# restart, not "enable --now": --now does not restart a running service, a new binary would be ignored
as_root systemctl restart evdev-rce.service
sleep 1
systemctl is-active evdev-rce.service
journalctl -u evdev-rce.service -n 12 --no-pager -o cat
echo "Test: hold a finger still for one second, then lift - the context menu opens under the finger."
