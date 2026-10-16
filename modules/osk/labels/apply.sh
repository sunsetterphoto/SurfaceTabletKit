#!/usr/bin/env bash
# Gives the gjsosk modifier keys PC text labels (Ctrl/Strg, Alt, AltGr/Alt Gr) instead of the macOS-style
# glyphs that `show-icons=true` draws (⌃ for Ctrl, ⌥ for Alt), and replaces two icons:
# Super -> Tux, Caps Lock -> framed A with padlock (icons/*.svg over ui/.../*.svg,
# originals kept as .orig-v<ver>).
# Two inserted lines before the unique `// [insert handwriting 8]` comment in doAddKey.
# Idempotent. Must be re-run after every gjsosk update; takes effect after logging out and in.
#   ./apply.sh            apply
#   ./apply.sh --remove   remove only these two lines + restore the original icons (the glass patch stays)
set -euo pipefail
EXT="$HOME/.local/share/gnome-shell/extensions/gjsosk@vishram1123.com"
JS="$EXT/extension.js"
VER="$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$EXT/metadata.json")"
MARK="// surfaceos: PC-Beschriftung"
ICONS="$EXT/ui/icons/hicolor/scalable/actions"
HERE="$(cd "$(dirname "$0")" && pwd)"
# gjsosk icon name -> our replacement in icons/
declare -A REPL=([super]=tux [super-dark]=tux-dark [capslock]=capslock [capslock-dark]=capslock-dark)

if [[ "${1:-}" == "--remove" ]]; then
    sed -i "\|$MARK|d" "$JS"
    for f in "${!REPL[@]}"; do if [[ -f "$ICONS/$f.svg.orig-v$VER" ]]; then cp "$ICONS/$f.svg.orig-v$VER" "$ICONS/$f.svg"; fi; done
    echo "Removed. Takes effect after logging out and in."; exit 0
fi
for f in "${!REPL[@]}"; do
    [[ -f "$ICONS/$f.svg.orig-v$VER" ]] || cp "$ICONS/$f.svg" "$ICONS/$f.svg.orig-v$VER"
    cp "$HERE/icons/${REPL[$f]}.svg" "$ICONS/$f.svg"
done
if grep -q "$MARK" "$JS"; then echo "Patch already applied (gjsosk v$VER), icons refreshed."; exit 0; fi
[[ "$(grep -c '// \[insert handwriting 8\]' "$JS")" == 1 ]] || { echo "Anchor not unique - gjsosk v$VER changed, check the patch by hand"; exit 1; }
[[ -f "$JS.orig-v$VER" ]] || cp "$JS" "$JS.orig-v$VER"
L1='iconKeys = iconKeys.filter(k => !["ctrl", "alt"].includes(k)); '"$MARK"
# German labels when the first input source is German, PC/English labels otherwise
if gsettings get org.gnome.desktop.input-sources sources | grep -qE "^\[\('xkb', 'de"; then
    CTRL=Strg; ALTGR="Alt Gr"
else
    CTRL=Ctrl; ALTGR=AltGr
fi
L2='{ const pcLabel = { 29: "'"$CTRL"'", 97: "'"$CTRL"'", 56: "Alt", 100: "'"$ALTGR"'" }[i.code]; if (pcLabel) for (const l of Object.keys(i.layers)) i.layers[l] = pcLabel; } '"$MARK"
python3 -I - "$JS" "$L1" "$L2" <<'EOF'
import re, sys
p, l1, l2 = sys.argv[1:]
t = open(p).read()
t = re.sub(r"^(\s*)(// \[insert handwriting 8\])$", lambda m: f"{m[1]}{l1}\n{m[1]}{l2}\n{m[1]}{m[2]}", t, count=1, flags=re.M)
open(p, "w").write(t)
EOF
grep -n "$MARK" "$JS"
echo "Patched (gjsosk v$VER). Takes effect after logging out and in."
