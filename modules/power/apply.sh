#!/usr/bin/env bash
# Power and sleep: measures first and changes only what is wrong. Idempotent.
#   1. disable TLP if it is enabled next to tuned-ppd (two power managers fight)
#   2. power profile "balanced" instead of a permanent "performance"
#   3. comment out a hibernate setup in /etc/systemd/sleep.conf that cannot work
#      (CanHibernate != yes, e.g. kernel lockdown under Secure Boot)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
pp() { gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles "$@"; }

log "1. TLP"
if systemctl list-unit-files tlp.service &>/dev/null && [[ "$(systemctl is-enabled tlp 2>/dev/null || true)" == enabled ]]; then
    as_root systemctl disable --now tlp; ok "disabled (tuned-ppd does the work and drives GNOME's profile switch)"
else
    ok "not installed or already disabled"
fi

log "2. Power profile"
CURRENT="$(pp --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>/dev/null | grep -o "'[a-z-]*'" | tr -d "'" || true)"
if [[ -z "$CURRENT" ]]; then warn "no PowerProfiles service (tuned-ppd installed?) - skipped"
elif [[ "$CURRENT" == balanced ]]; then ok "already balanced"
else
    pp --method org.freedesktop.DBus.Properties.Set net.hadess.PowerProfiles ActiveProfile "<'balanced'>" >/dev/null
    ok "'$CURRENT' -> 'balanced' (tuned picks balanced-battery on battery)"
fi

log "3. sleep.conf"
CAN_HIB="$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate 2>/dev/null | tr -d 's "' || true)"
if [[ "$CAN_HIB" == yes ]]; then ok "hibernate is available here - sleep.conf left alone"
elif ! grep -qE '^(AllowHibernation|AllowSuspendThenHibernate|HibernateDelaySec)' /etc/systemd/sleep.conf 2>/dev/null; then ok "nothing to clean up"
else
    as_root cp /etc/systemd/sleep.conf "/etc/systemd/sleep.conf.bak-$(date +%F)"
    as_root sed -i -E 's/^(AllowHibernation|AllowSuspendThenHibernate|HibernateDelaySec)/#\1/' /etc/systemd/sleep.conf
    as_root systemctl daemon-reload
    ok "hibernate lines commented out (CanHibernate=$CAN_HIB), backup next to it"
fi
echo; echo "Profile: $(pp --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>/dev/null | grep -o "'[a-z-]*'" | tr -d "'")  tuned: $(tuned-adm active 2>/dev/null | sed 's/.*: //')"
