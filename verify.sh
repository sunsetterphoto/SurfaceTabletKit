#!/usr/bin/env bash
# SurfaceTabletKit: checks that everything is in place. Read-only.
# Exit 0 = all good, 1 = at least one item needs attention.
# Useful after: kernel, mutter, gnome-shell or extension updates, and after a Plasma session.
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=lib/common.sh
source lib/common.sh
detect_device
FAIL=0
ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; }
bad()  { printf '  \033[31mFIX\033[0m   %s\n' "$1"; FAIL=1; }
note() { printf '        %s\n' "$1"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }
gs() { local v; v=$(gsettings get "$1" "$2" 2>/dev/null)
       [ "$v" = "$3" ] && ok "$2 = $v" || bad "$2 = $v  (expected $3)"; }
dc() { local v; v=$(dconf read "$1")
       [ "$v" = "$2" ] && ok "${1#/org/gnome/shell/extensions/} = $v" || bad "${1#/org/gnome/shell/extensions/} = ${v:-<default>}  (expected $2)"; }
enabled=$(gsettings get org.gnome.shell enabled-extensions)
ext_ok() {   # uuid [legacy-uuid]  - INACTIVE is normal while the screen is locked
    local u st
    for u in "$@"; do
        [[ "$enabled" == *"'$u'"* ]] || continue
        st=$(gnome-extensions info "$u" 2>/dev/null | sed -n 's/^ *\(Status\|State\): *//p')
        if [[ "$st" =~ ^(ACTIVE|INACTIVE)$ ]]; then ok "$u ($st)"; else bad "$u state ${st:-not installed} -> journalctl --user -b | grep -i '${u%%@*}'"; fi
        return
    done
    bad "$1 is not enabled"
}

head_ "System"
note "device: ${DEVICE_PRODUCT:-?} (profile $DEVICE_ID) · Fedora $(rpm -E %fedora) · $(gnome-shell --version 2>/dev/null) · mutter $(rpm -q --qf '%{VERSION}-%{RELEASE}' mutter) · kernel $(uname -r)"
[[ "$(uname -r)" == *surface* ]] && ok "linux-surface kernel" || bad "not a linux-surface kernel -> ./install.sh run linux-surface"
note "scale per connector (monitors.xml): $(python3 -I -c '
import re,sys
t=open(sys.argv[1]).read()
print(sorted({f"{c}: {s}" for lm in re.findall(r"<logicalmonitor>(.*?)</logicalmonitor>",t,re.S)
  for s in re.findall(r"<scale>([^<]+)",lm)[:1] for c in re.findall(r"<connector>([^<]+)",lm)[:1]}))' ~/.config/monitors.xml 2>/dev/null || echo '?')"

head_ "Theme, icons, font, window buttons"
gs org.gnome.desktop.interface gtk-theme    "'MacTahoe-Dark'"
gs org.gnome.desktop.interface icon-theme   "'Colloid-Dark'"
gs org.gnome.desktop.interface cursor-theme "'WhiteSur-cursors'"
gs org.gnome.desktop.interface color-scheme "'prefer-dark'"
gs org.gnome.desktop.wm.preferences button-layout "'close,minimize,maximize:'"
dc /org/gnome/shell/extensions/user-theme/name "'MacTahoe-Dark'"
[ "$(basename "$(readlink -f ~/.config/gtk-4.0/gtk.css)")" = "gtk-Dark.css" ] && ok "libadwaita part (gtk-4.0/gtk.css -> gtk-Dark.css)" || bad "~/.config/gtk-4.0/gtk.css does not point to gtk-Dark.css -> design themes"
fc-list | grep -q 'Inter' && ok "font Inter installed" || bad "Inter missing -> sudo dnf install rsms-inter-fonts"

head_ "Extensions"
for u in dash-to-dock@micxgx.gmail.com blur-my-shell@aunetx just-perfection-desktop@just-perfection \
         user-theme@gnome-shell-extensions.gcampax.github.com rounded-window-corners@fxgn space-bar@luchrioh \
         compiz-alike-magic-lamp-effect@hermes83.github.com gtk4-ding@smedius.gitlab.com gjsosk@vishram1123.com \
         screen-rotate@shyzus.github.io; do ext_ok "$u"; done
ext_ok panel-portrait@surfacetabletkit
v=$(gnome-extensions info blur-my-shell@aunetx 2>/dev/null | sed -n 's/^ *Version: *//p')
[ "${v:-0}" -ge 74 ] 2>/dev/null && ok "blur-my-shell v$v (Liquid Glass needs >= 74)" || bad "blur-my-shell v${v:-?}: the refraction (Liquid Glass) effect needs v74+"

head_ "Glass: dock, top bar, windows, menus"
dc /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/pipeline "'pipeline_dock_glass'"
dc /org/gnome/shell/extensions/blur-my-shell/panel/pipeline "'pipeline_panel_glass'"
dc /org/gnome/shell/extensions/blur-my-shell/applications/dynamic-opacity "false"
dc /org/gnome/shell/extensions/blur-my-shell/popup/menu-corner-radius "14"
grep -q 'surfaceos-overrides' ~/.themes/MacTahoe-Dark/gnome-shell/gnome-shell.css 2>/dev/null && ok "shell overrides (quick settings, keyboard CSS)" || bad "shell overrides missing -> modules/design/apply.sh css"
[ -s ~/.config/com.desktop.ding/stylesheet-override.css ] && ok "desktop context-menu CSS" || bad "desktop context-menu CSS missing -> modules/design/apply.sh css"
if [ -e /usr/lib64/girepository-1.0/Blur-1.0.typelib ]; then
    built=$(cat /var/lib/surfacetabletkit/rounded-blur/built-against.txt 2>/dev/null)
    now=$(rpm -q --qf '%{VERSION}-%{RELEASE}' mutter)
    [ "$built" = "$now" ] && ok "gnome-rounded-blur built against mutter $now" || bad "gnome-rounded-blur built against ${built:-?}, mutter is $now -> modules/rounded-blur/apply.sh + log out/in"
else
    bad "gnome-rounded-blur missing -> modules/rounded-blur/apply.sh"
fi
dc /org/gnome/shell/extensions/blur-my-shell/rounded-blur-found "true"

head_ "Rotation and top bar"
grep -q 'surfaceos:' "$EXT_DIR/screen-rotate@shyzus.github.io/sensorProxy.js" 2>/dev/null \
    && ok "screen-rotate uses its own D-Bus connection" || bad "screen-rotate unpatched (RPM update?) -> modules/screen-rotate/apply.sh + log out/in"

head_ "On-screen keyboard (gjsosk)"
J=$EXT_DIR/gjsosk@vishram1123.com/extension.js
grep -q 'surfaceos: blur-my-shell glass' "$J" 2>/dev/null && ok "glass patch" || bad "glass patch missing (gjsosk update?) -> modules/osk/glass/apply.sh"
grep -q 'surfaceos: PC-Beschriftung' "$J" 2>/dev/null && ok "PC key labels" || bad "PC key labels missing -> modules/osk/labels/apply.sh"
grep -q 'surfaceosHasHwKeyboard' "$J" 2>/dev/null && ok "auto-open only without a hardware keyboard" || bad "auto-open patch missing -> modules/osk/autoshow/apply.sh"
dc /org/gnome/shell/extensions/gjsosk/layout-landscape "10"

head_ "Touch"
if [[ "${NEEDS_TOUCH_ANCHOR:-}" == yes ]]; then
    [ "$(systemctl is-active touch-anchor.service 2>/dev/null)" = active ] && ok "touch-anchor running" || bad "touch-anchor not running -> modules/touch-anchor/apply.sh"
elif systemctl is-enabled touch-anchor.service &>/dev/null; then
    ok "touch-anchor installed ($(systemctl is-active touch-anchor.service))"
else
    note "touch-anchor not installed (profile: ${NEEDS_TOUCH_ANCHOR:-?})"
fi
if systemctl is-enabled evdev-rce.service &>/dev/null; then
    [ "$(systemctl is-active evdev-rce.service)" = active ] && ok "long-press right click (evdev-rce)" || bad "evdev-rce not active -> journalctl -u evdev-rce -n 30"
else
    note "long-press right click not installed"
fi

head_ "Boot splash, login screen"
v=$(plymouth-set-default-theme 2>/dev/null)
[[ "$v" == surfacetabletkit || "$v" == surfaceos ]] && ok "Plymouth theme $v" || bad "Plymouth theme is '$v' -> modules/plymouth/apply.sh"
grep -q 'rhgb' /proc/cmdline && ok "kernel command line has rhgb" || bad "rhgb missing on the kernel command line - no splash"
[ -f /usr/share/gnome-shell/gnome-shell-theme.gresource.bak ] && ok "login screen themed (re-run gdm-theme after gnome-shell updates)" || note "login screen: Fedora default (optional module gdm-theme)"

if [[ "$DEVICE_ID" == surface-pro-7-plus ]]; then
    head_ "Surface Pro 7+ kernel modules (signer = own key -> patch active)"
    for m in surface_gpe intel_skl_int3472_discrete ov5693 ov7251; do
        s=$(modinfo -F signer "$m" 2>/dev/null)
        case "$s" in
            "SurfaceTabletKit module signing key"|"Int3472 Camera Fix") ok "$m ($s)" ;;
            "") bad "$m not found" ;;
            *)  bad "$m signed by '$s' (kernel update?) -> modules/sp7p-kernel/apply.sh all, reboot" ;;
        esac
    done
    cams=$(cam -l 2>/dev/null | grep -cE '^[0-9]+: ')
    [ "${cams:-0}" -ge 2 ] && ok "libcamera sees $cams cameras" || bad "libcamera sees ${cams:-0} cameras -> dmesg | grep -E 'int3472|ov5693|ov8865'"
fi

head_ "Audio, Flatpak"
ee=~/.var/app/com.github.wwmm.easyeffects/data/easyeffects/output
if [[ -n "${AUDIO_PRESET:-}" ]]; then
    [ -f "$ee/$AUDIO_PRESET.json" ] && ok "EasyEffects preset '$AUDIO_PRESET' installed" || bad "preset '$AUDIO_PRESET' missing -> modules/audio/apply.sh"
else
    note "no measured speaker preset for this device yet (tools/measure-speakers.py)"
fi
grep -q '~/.themes:ro' ~/.local/share/flatpak/overrides/global 2>/dev/null && ok "Flatpaks can read ~/.themes" || bad "global Flatpak override missing -> modules/flatpak-theming/apply.sh"
grep -q 'GTK_THEME' ~/.local/share/flatpak/overrides/global 2>/dev/null && bad "GTK_THEME in the global override - remove it (the portal provides the theme)" || ok "no hard-wired GTK_THEME"

echo
[ "$FAIL" -eq 0 ] && printf '\033[32mAll good.\033[0m\n' || printf '\033[31mAt least one item needs attention, see above.\033[0m\n'
exit "$FAIL"
