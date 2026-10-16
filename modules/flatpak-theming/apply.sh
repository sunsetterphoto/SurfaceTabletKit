#!/usr/bin/env bash
# Global Flatpak override (themes readable, no hard-wired GTK_THEME) + Spotify on X11 so GNOME
# draws the MacTahoe window frame. Idempotent.
set -euo pipefail
G="$HOME/.local/share/flatpak/overrides/global"
mkdir -p "$(dirname "$G")"
[[ -f "$G" ]] && cp -n "$G" "$G.bak-$(date +%F)"
flatpak override --user --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro \
    --filesystem=xdg-data/themes:ro --filesystem=~/.themes:ro
# drop an old GTK_THEME entry (not via --unset-env, that would write GTK_THEME= permanently)
python3 -I - "$G" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r"^GTK_THEME=.*\n?", "", s, flags=re.M)
s = re.sub(r"\n*\[Environment\]\n*(?=\[|\Z)", "\n", s)
open(p, "w").write(s.strip() + "\n")
PY
echo "== global:"; cat "$G"

if flatpak info com.spotify.Client &>/dev/null; then
    F="$HOME/.var/app/com.spotify.Client/config/spotify-flags.conf"
    mkdir -p "$(dirname "$F")"
    grep -qx -- '--ozone-platform=x11' "$F" 2>/dev/null || {
        echo '# surfacetabletkit: force X11 so GNOME draws the theme window frame (on Wayland CEF draws a fallback frame)' >> "$F"
        echo '--ozone-platform=x11' >> "$F"; }
    flatpak override --user --nosocket=fallback-x11 --socket=x11 com.spotify.Client
    echo "== Spotify:"; flatpak override --user --show com.spotify.Client
else
    echo "Spotify Flatpak not installed - part 2 skipped."
fi
