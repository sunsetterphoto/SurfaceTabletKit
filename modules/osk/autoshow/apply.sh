#!/usr/bin/env bash
# gjsosk opens automatically (text field tapped with a finger) only when NO hardware keyboard
# is attached (Type Cover, USB, Bluetooth). The top-bar button and the swipe gesture keep
# working as before. Idempotent.
# Re-run after every gjsosk update (after osk/glass and osk/labels); takes effect after
# logging out and in.
#   ./apply.sh            apply
#   ./apply.sh --remove   take back only this patch
set -euo pipefail
JS="$HOME/.local/share/gnome-shell/extensions/gjsosk@vishram1123.com/extension.js"
MARK="// surfaceos: Auto nur ohne Tastatur"
GUARD='!surfaceosHasHwKeyboard() \&\& '
FN='function surfaceosHasHwKeyboard() { return Clutter.get_default_backend().get_default_seat().list_devices().some(d => d.get_device_mode() === Clutter.InputMode.PHYSICAL \&\& d.get_device_type() === Clutter.InputDeviceType.KEYBOARD_DEVICE \&\& /keyboard/i.test(d.get_device_name() ?? "") \&\& !/virtual/i.test(d.get_device_name() ?? "")); } '"$MARK"

if [[ "${1:-}" == "--remove" ]]; then
    sed -i -e "\|^function surfaceosHasHwKeyboard|d" -e "s/!surfaceosHasHwKeyboard() && //g" "$JS"
    echo "Removed. Takes effect after logging out and in."; exit 0
fi
if grep -q "surfaceosHasHwKeyboard" "$JS"; then echo "Patch already applied."; exit 0; fi
for a in 'this.lastInputMethod = [false, event.type() >= 9 && event.type() <= 12, true]' \
         'let lastInputMethod = [e.type() == 11, e.type() == 11, e.type() == 7 || e.type() == 11]' \
         'export default class GjsOskExtension'; do
    [[ "$(grep -cF "$a" "$JS")" == 1 ]] || { echo "Anchor not unique: $a - gjsosk changed, check by hand"; exit 1; }
done
sed -i -e "s/= \[false, event.type() >= 9 \&\& event.type() <= 12, true\]/= ${GUARD}[false, event.type() >= 9 \&\& event.type() <= 12, true]/" \
       -e "s/let lastInputMethod = \[e.type() == 11/let lastInputMethod = ${GUARD}[e.type() == 11/" \
       -e "s|^export default class GjsOskExtension|${FN}\n&|" "$JS"
grep -n "surfaceosHasHwKeyboard" "$JS" | cut -c1-140
echo "Patched. Takes effect after logging out and in."
