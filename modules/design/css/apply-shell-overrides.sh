#!/usr/bin/env bash
# Appends mactahoe-shell-overrides.css to the MacTahoe-Dark shell theme (between markers,
# idempotent) and reloads the shell theme live. Re-run after reinstalling MacTahoe.
#   ./apply-shell-overrides.sh           apply
#   ./apply-shell-overrides.sh --remove  remove the block again
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSS="$HOME/.themes/MacTahoe-Dark/gnome-shell/gnome-shell.css"
BEGIN="/* >>> surfaceos-overrides >>> */"
END="/* <<< surfaceos-overrides <<< */"

[[ -f "$CSS" ]] || { echo "Not found: $CSS"; exit 1; }
[[ -f "$CSS.orig" ]] || cp "$CSS" "$CSS.orig"

# drop an existing block
python3 -I - "$CSS" "$BEGIN" "$END" <<'EOF'
import sys
path, begin, end = sys.argv[1:4]
s = open(path).read()
if begin in s:
    a = s.index(begin); b = s.index(end) + len(end)
    s = s[:a].rstrip('\n') + '\n' + s[b:].lstrip('\n')
    open(path, 'w').write(s)
EOF

if [[ "${1:-}" != "--remove" ]]; then
    { echo; echo "$BEGIN"; cat "$HERE/mactahoe-shell-overrides.css"; echo "$END"; } >> "$CSS"
fi

# reload the shell theme: user-theme only reloads on a name change
KEY=/org/gnome/shell/extensions/user-theme/name
NAME="$(dconf read "$KEY")"
dconf write "$KEY" "''"; sleep 1; dconf write "$KEY" "$NAME"
echo "Done: $(grep -c 'surfaceos-overrides' "$CSS") markers in $CSS, theme $NAME reloaded"
