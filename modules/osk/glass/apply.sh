#!/usr/bin/env bash
# Marks the gjsosk keyboard panel with the style class blur-my-shell uses for on-screen
# keyboards (`bms-keyboard-surface`), so it gets a real glass blur behind it.
# One inserted line after `this.box.clear_actions();` in Keyboard._init. Idempotent.
# Must be re-run after every gjsosk update; takes effect after logging out and in.
#   ./apply.sh            apply
#   ./apply.sh --restore  restore the backed-up original
set -euo pipefail
EXT="$HOME/.local/share/gnome-shell/extensions/gjsosk@vishram1123.com"
JS="$EXT/extension.js"
VER="$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$EXT/metadata.json")"
MARK="// surfaceos: blur-my-shell glass"

if [[ "${1:-}" == "--restore" ]]; then
    cp -v "$JS.orig-v$VER" "$JS"; echo "Restored. Takes effect after logging out and in."; exit 0
fi
if grep -q "$MARK" "$JS"; then echo "Patch already applied (gjsosk v$VER)."; exit 0; fi
[[ "$(grep -c 'this.box.clear_actions();' "$JS")" == 1 ]] || { echo "Anchor not unique - gjsosk v$VER changed, check the patch by hand"; exit 1; }
[[ -f "$JS.orig-v$VER" ]] || cp "$JS" "$JS.orig-v$VER"
sed -i "s|^\(\s*\)this.box.clear_actions();|&\n\1this.box.add_style_class_name('bms-keyboard-surface'); $MARK|" "$JS"
grep -n "$MARK" "$JS"
echo "Patched (gjsosk v$VER). Takes effect after logging out and in."
