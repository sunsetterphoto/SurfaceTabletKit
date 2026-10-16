#!/usr/bin/env bash
# SurfaceTabletKit - turns a Microsoft Surface running Fedora Workstation (GNOME) into a
# polished Linux tablet. Detects the device and runs the modules one by one.
#
#   ./install.sh                   show the device, the recommended modules and what they do
#   ./install.sh guided            go through the recommended modules, asking before each one
#   ./install.sh run MODULE...     run specific modules (see the list)
#   ./verify.sh                    check afterwards (read-only)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=lib/common.sh
source lib/common.sh
require_user

# module -> command, in install order
declare -A CMD=(
    [linux-surface]="modules/linux-surface/apply.sh"
    [sp7p-kernel]="modules/sp7p-kernel/apply.sh all"
    [design]="modules/design/apply.sh all"
    [rounded-blur]="modules/rounded-blur/apply.sh"
    [osk]="modules/osk/glass/apply.sh && modules/osk/labels/apply.sh && modules/osk/autoshow/apply.sh"
    [screen-rotate]="modules/screen-rotate/apply.sh"
    [panel-portrait]="modules/panel-portrait/apply.sh"
    [plymouth]="modules/plymouth/apply.sh"
    [gdm-theme]="modules/gdm-theme/apply.sh"
    [flatpak-theming]="modules/flatpak-theming/apply.sh"
    [touch-right-click]="modules/touch-right-click/apply.sh"
    [touch-anchor]="modules/touch-anchor/apply.sh"
    [audio]="modules/audio/apply.sh"
    [power]="modules/power/apply.sh"
    [healthpanel]="modules/design/apply.sh healthpanel"
    [kde-coexistence]="modules/kde-coexistence/apply.sh"
    [linux-surface-watch]="modules/linux-surface-watch/apply.sh"
)
ORDER=(linux-surface sp7p-kernel design rounded-blur osk screen-rotate panel-portrait plymouth
       gdm-theme flatpak-theming touch-right-click touch-anchor audio power healthpanel
       kde-coexistence linux-surface-watch)
declare -A WHAT=(
    [linux-surface]="linux-surface kernel, iptsd, libwacom-surface (base layer, reboot)"
    [sp7p-kernel]="SP7+ only: cameras + wake on lid open (own MOK key, reboot)"
    [design]="MacTahoe theme, Colloid icons, cursors, extensions, dock/top bar/window settings"
    [rounded-blur]="rounded corners for blurred menus (built against mutter, re-run after mutter updates)"
    [osk]="on-screen keyboard: glass, PC labels, auto-open only without a hardware keyboard"
    [screen-rotate]="reliable auto-rotation (own D-Bus connection for the accelerometer)"
    [panel-portrait]="top bar fits in portrait: tighter spacing first, hide icons/date only if needed"
    [plymouth]="boot splash: Tux with a bitten apple, macOS-style progress bar"
    [gdm-theme]="optional: login/lock screen in the WhiteSur look"
    [flatpak-theming]="Flatpak apps follow the theme; Spotify gets a proper window frame"
    [touch-right-click]="long-press = right click everywhere (needs the measured touchscreen)"
    [touch-anchor]="touch keeps working in apps after suspend (devices that re-create touch devices)"
    [audio]="EasyEffects speaker preset (measured per device) + measurement tool"
    [power]="balanced power profile, no TLP conflict, no impossible hibernate setup"
    [healthpanel]="optional: HealthPanel top-bar system monitor"
    [kde-coexistence]="only with KDE Plasma installed: keep Plasma from changing GNOME"
    [linux-surface-watch]="optional: daily check before upgrading Fedora (Surface kernel availability)"
)

detect_device
recommended() { [[ " ${RECOMMENDED_MODULES:-} " == *" $1 "* ]] || [[ "$1" == linux-surface ]]; }

show() {
    echo "Device:  ${DEVICE_PRODUCT:-?}  ->  profile: $DEVICE_ID"
    echo "Fedora:  $(rpm -E %fedora)   GNOME: $(gnome-shell --version 2>/dev/null | grep -oE '[0-9.]+$')   kernel: $(uname -r)   session: ${XDG_SESSION_TYPE:-?}"
    [[ "$DEVICE_ID" == unknown ]] && warn "unknown device: only generic modules make sense; touch/audio values must be measured"
    echo
    printf '  %-20s %-4s %s\n' MODULE REC WHAT
    for m in "${ORDER[@]}"; do
        printf '  %-20s %-4s %s\n' "$m" "$(recommended "$m" && echo yes || echo -)" "${WHAT[$m]}"
    done
    echo
    echo "Next: ./install.sh guided   (or ./install.sh run <module>)"
}

run_module() {
    local m="$1"
    [[ -n "${CMD[$m]:-}" ]] || die "unknown module: $m"
    log "Module $m: ${WHAT[$m]}"
    bash -c "${CMD[$m]}"
}

case "${1:-}" in
    "") show ;;
    run) shift; (( $# )) || die "which module?"; for m in "$@"; do run_module "$m"; done ;;
    guided)
        show
        for m in "${ORDER[@]}"; do
            recommended "$m" || continue
            read -r -p "Run module '$m'? [y/N/q] " a
            case "$a" in y|Y) run_module "$m" ;; q|Q) break ;; *) echo "  skipped" ;; esac
        done
        echo; echo "Log out and in once (extensions load only at login), then run ./verify.sh." ;;
    *) sed -n '2,9p' "$0"; exit 1 ;;
esac
