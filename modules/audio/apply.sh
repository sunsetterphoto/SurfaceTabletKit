#!/usr/bin/env bash
# Speaker tuning with EasyEffects (Flatpak). Installs the measured preset of this device and,
# for devices that are not measured yet, explains how to measure (tools/measure-speakers.py).
#   ./apply.sh            install EasyEffects (if missing) + the preset for this device
#   ./apply.sh --all      install every preset in presets/ (e.g. to use one as a template)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
require_user
detect_device
APP=com.github.wwmm.easyeffects
if ! flatpak info "$APP" &>/dev/null; then
    log "Installing EasyEffects from Flathub"
    flatpak install -y flathub "$APP"
fi
OUT="$HOME/.var/app/$APP/data/easyeffects/output"
mkdir -p "$OUT"
STAMP="$(date +%F-%H%M%S)"
install_preset() {
    local src="$1" name dest; name="$(basename "$src")"; dest="$OUT/$name"
    if [[ -f "$dest" ]] && ! cmp -s "$src" "$dest"; then cp -a "$dest" "$dest.bak-$STAMP"; ok "backed up $name"; fi
    cp "$src" "$dest"; ok "preset installed: ${name%.json}"
}
if [[ "${1:-}" == "--all" ]]; then
    for f in "$HERE"/presets/*.json; do install_preset "$f"; done
elif [[ -n "${AUDIO_PRESET:-}" && -f "$HERE/presets/$AUDIO_PRESET.json" ]]; then
    install_preset "$HERE/presets/$AUDIO_PRESET.json"
else
    cat <<MSG
No measured preset for this device ($DEVICE_PRODUCT) yet. Speakers differ per model, so a
preset from another device would correct the wrong frequencies. Measure first:
  1. flatpak run $APP -q                       # quit EasyEffects for a raw measurement
  2. python3 -I $KIT_ROOT/tools/measure-speakers.py
  3. build a preset from presets/SurfacePro7+ v3.json (same chain, your numbers),
     see README.md "Building a preset"
  4. check it: start EasyEffects, select the preset, run measure-speakers.py --processed
MSG
    exit 0
fi
cat <<MSG
Select the preset in EasyEffects (Presets -> Output). Loading presets from the command line
while EasyEffects runs is unreliable (it keeps state in memory and writes it on exit).
Enable "Start service at login" in EasyEffects' preferences so it is always active.
MSG
