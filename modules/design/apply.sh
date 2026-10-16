#!/usr/bin/env bash
# Design: MacTahoe-Dark (GTK3/GTK4/Shell), Colloid-Dark icons, WhiteSur cursors, the GNOME
# Shell extensions, their settings (dconf) and the CSS overrides.
#
#   ./apply.sh <step> [--force]
#   steps, in this order:
#     packages    install missing RPMs (Inter font, git, auto-rotate extension, unzip)
#     themes      unpack MacTahoe-Dark, its libadwaita part, Colloid-Dark, WhiteSur cursors
#     extensions  install the vendored extensions + space-bar from extensions.gnome.org, enable them
#     dconf       load the settings (current values are backed up first)
#     css         quick-settings/keyboard overrides into MacTahoe + desktop context-menu CSS
#     healthpanel optional: enable the HealthPanel extension and load its settings
#     all         packages themes extensions dconf css
#
# --force: replace themes/extensions that already exist (otherwise they are skipped).
# Every step is idempotent. Log out and back in afterwards.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
require_user

CONFIG="$HERE/config"
VENDOR="$KIT_ROOT/vendor"
BACKUP="$STATE_DIR/backup-$(date +%F-%H%M)-design"
FORCE=0
CLEANUP=()
trap 'rm -rf "${CLEANUP[@]}"' EXIT
STEP="${1:-}"; shift || true
[[ "${1:-}" == "--force" ]] && FORCE=1

REQUIRED_EXT=(
    dash-to-dock@micxgx.gmail.com
    blur-my-shell@aunetx
    just-perfection-desktop@just-perfection
    user-theme@gnome-shell-extensions.gcampax.github.com
    rounded-window-corners@fxgn
    space-bar@luchrioh
    compiz-alike-magic-lamp-effect@hermes83.github.com
    gtk4-ding@smedius.gitlab.com
    gjsosk@vishram1123.com
    appindicatorsupport@rgcjonas.gmail.com
    caffeine@patapon.info
    screen-rotate@shyzus.github.io
)
# Not redistributable (no upstream license) -> downloaded from extensions.gnome.org
EGO_EXT=(space-bar@luchrioh)

declare -A DCONF_PATH=(
    [dash-to-dock]=/org/gnome/shell/extensions/dash-to-dock/
    [blur-my-shell]=/org/gnome/shell/extensions/blur-my-shell/
    [just-perfection]=/org/gnome/shell/extensions/just-perfection/
    [rounded-window-corners-reborn]=/org/gnome/shell/extensions/rounded-window-corners-reborn/
    [user-theme]=/org/gnome/shell/extensions/user-theme/
    [space-bar]=/org/gnome/shell/extensions/space-bar/
    [compiz-alike-magic-lamp-effect]=/org/gnome/shell/extensions/compiz-alike-magic-lamp-effect/
    [gjsosk]=/org/gnome/shell/extensions/gjsosk/
    [caffeine]=/org/gnome/shell/extensions/caffeine/
    [gtk4-ding]=/org/gnome/shell/extensions/gtk4-ding/
    [gnome-desktop]=/org/gnome/desktop/
)

shell_major() { gnome-shell --version | grep -oE '[0-9]+' | head -1; }

step_packages() {
    log "Packages"
    need_rpms rsms-inter-fonts git unzip gnome-shell-extension-screen-autorotate
    rpm -q gnome-backgrounds &>/dev/null || warn "gnome-backgrounds missing: the glass-chip wallpaper will not exist"
}

step_themes() {
    log "Themes, icons, cursors"
    mkdir -p "$HOME/.themes" "$HOME/.local/share/icons" "$HOME/.config/gtk-4.0" "$BACKUP"
    if [[ -d "$HOME/.themes/MacTahoe-Dark" && $FORCE == 0 ]]; then
        warn "~/.themes/MacTahoe-Dark exists, skipped (--force replaces it)"
    else
        tar -C "$HOME/.themes" -xzf "$VENDOR/themes-MacTahoe-Dark.tar.gz"; ok "MacTahoe-Dark (+hdpi/xhdpi) -> ~/.themes"
    fi
    local t
    for t in Colloid-Dark WhiteSur-cursors; do
        if [[ -d "$HOME/.local/share/icons/$t" && $FORCE == 0 ]]; then
            warn "~/.local/share/icons/$t exists, skipped"; continue
        fi
        case $t in
            Colloid-Dark)     tar -C "$HOME/.local/share/icons" -xzf "$VENDOR/icons-Colloid-Dark.tar.gz" ;;
            WhiteSur-cursors) # vendored as the complete upstream source (GPL-3.0), installed by its own script
                local src; src="$(mktemp -d)"
                tar -C "$src" -xzf "$VENDOR"/WhiteSur-cursors-*-source.tar.gz
                ( cd "$src"/WhiteSur-cursors-* && ./install.sh >/dev/null )
                rm -rf "$src" ;;
        esac
        ok "$t -> ~/.local/share/icons"
    done
    # libadwaita part of MacTahoe: back up what is there, then put the theme files on top
    if [[ -n "$(ls -A "$HOME/.config/gtk-4.0" 2>/dev/null)" ]]; then
        cp -a "$HOME/.config/gtk-4.0" "$BACKUP/gtk-4.0"; ok "old ~/.config/gtk-4.0 backed up to $BACKUP"
    fi
    rm -f "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk-dark.css"
    tar -C "$HOME/.config" -xzf "$VENDOR/gtk-4.0-MacTahoe-libadwaita.tar.gz"
    ok "MacTahoe libadwaita -> ~/.config/gtk-4.0 (gtk.css -> gtk-Dark.css)"
    rpm -q breeze-icon-theme &>/dev/null || \
        echo "  note: Colloid inherits 'hicolor,breeze'; without breeze-icon-theme missing icons fall back to hicolor/Adwaita."
}

install_ego() {   # uuid  -> latest version for the running shell from extensions.gnome.org
    local uuid="$1" major info url tmp
    major="$(shell_major)"
    info="$(curl -sf -m 30 "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$major")" \
        || { warn "$uuid: extensions.gnome.org has no version for GNOME $major"; return 1; }
    url="https://extensions.gnome.org$(python3 -I -c 'import json,sys;print(json.load(sys.stdin)["download_url"])' <<<"$info")"
    tmp="$(mktemp -d)"
    curl -sfL -m 60 "$url" -o "$tmp/ext.zip"
    gnome-extensions install --force "$tmp/ext.zip"
    rm -rf "$tmp"
    ok "$uuid installed from extensions.gnome.org ($(python3 -I -c 'import json,sys;print("version",json.load(sys.stdin)["version"])' <<<"$info"))"
}

step_extensions() {
    log "Extensions (GNOME $(shell_major))"
    mkdir -p "$EXT_DIR"
    local tmp d uuid compat
    tmp="$(mktemp -d)"; CLEANUP+=("$tmp")
    tar -C "$tmp" -xzf "$VENDOR/extensions.tar.gz"
    for d in "$tmp"/*@*; do
        uuid="$(basename "$d")"
        [[ "$uuid" == healthpanel@* ]] && continue   # optional, see step healthpanel
        compat="$(python3 -I -c 'import json,sys;m=json.load(open(sys.argv[1]));print("yes" if sys.argv[2] in m["shell-version"] else "no "+str(m["shell-version"]))' "$d/metadata.json" "$(shell_major)")"
        [[ "$compat" == yes ]] || warn "$uuid does not list GNOME $(shell_major) ($compat): get a matching version from extensions.gnome.org"
        if [[ -e "$EXT_DIR/$uuid" && $FORCE == 0 ]]; then warn "$uuid already installed, skipped (--force replaces it)"; continue; fi
        rm -rf "${EXT_DIR:?}/$uuid"; cp -a "$d" "$EXT_DIR/"; ok "$uuid"
    done
    for uuid in "${EGO_EXT[@]}"; do
        if [[ -e "$EXT_DIR/$uuid" && $FORCE == 0 ]]; then warn "$uuid already installed, skipped"; continue; fi
        install_ego "$uuid" || true
    done
    enable_extensions "${REQUIRED_EXT[@]}"
    disable_extensions background-logo@fedorahosted.org
    echo "  Takes effect after logging out and in (Wayland loads extension code only at login)."
}

step_dconf() {
    log "Settings (current values backed up to $BACKUP)"
    mkdir -p "$BACKUP"
    local name path file sub
    for name in "${!DCONF_PATH[@]}"; do
        path="${DCONF_PATH[$name]}"; file="$CONFIG/$name.conf"
        [[ -f "$file" ]] || { warn "missing: $file"; continue; }
        if [[ $name == gnome-desktop ]]; then
            for sub in interface wm/preferences background screensaver peripherals/touchpad; do
                dconf dump "/org/gnome/desktop/$sub/" > "$BACKUP/desktop-${sub//\//-}.conf"
            done
        else
            dconf dump "$path" > "$BACKUP/$name.conf"
        fi
        dconf load "$path" < "$file"; ok "$name"
    done
    # gjsosk: put the keyboard on the built-in panel of this device
    local edp
    edp="$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig \
          --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null | grep -oE "'eDP-[0-9]+'" | head -1 | tr -d "'" || true)"
    if [[ -n "$edp" ]]; then
        dconf write /org/gnome/shell/extensions/gjsosk/default-monitor "'1:$edp'"; ok "gjsosk default-monitor = 1:$edp"
    else
        warn "no built-in eDP panel found; check gjsosk default-monitor by hand"
    fi
    echo "  Undo: dconf load the files in $BACKUP back."
}

step_css() {
    log "CSS"
    "$HERE/css/apply-shell-overrides.sh"
    local dir="$HOME/.config/com.desktop.ding" dst
    dst="$dir/stylesheet-override.css"
    mkdir -p "$dir" "$BACKUP"
    [[ -e "$dst" || -L "$dst" ]] && cp -aL "$dst" "$BACKUP/ding-stylesheet-override.css" 2>/dev/null || true
    rm -f "$dst"; install -m 644 "$HERE/css/ding-stylesheet-override.css" "$dst"   # a copy, not a link into the repo
    ok "desktop context-menu CSS -> $dst"
    gdbus call --session --dest com.desktop.ding --object-path /com/desktop/ding \
        --method org.gtk.Actions.Activate reloadCSS [] {} &>/dev/null \
        && ok "ding reloaded its CSS" || echo "  ding not running yet; applies at login"
}

step_healthpanel() {
    log "Optional: HealthPanel (github.com/sunsetterphoto/HealthPanel)"
    local tmp; tmp="$(mktemp -d)"; CLEANUP+=("$tmp")
    tar -C "$tmp" -xzf "$VENDOR/extensions.tar.gz" ./healthpanel@sunsetterphoto
    rm -rf "${EXT_DIR:?}/healthpanel@sunsetterphoto"; mkdir -p "$EXT_DIR"; cp -a "$tmp/healthpanel@sunsetterphoto" "$EXT_DIR/"
    mkdir -p "$BACKUP"; dconf dump /org/gnome/shell/extensions/healthpanel/ > "$BACKUP/healthpanel.conf"
    dconf load /org/gnome/shell/extensions/healthpanel/ < "$CONFIG/healthpanel.conf"
    enable_extensions healthpanel@sunsetterphoto
}

case "$STEP" in
    packages|themes|extensions|dconf|css|healthpanel) "step_$STEP" ;;
    all) step_packages; step_themes; step_extensions; step_dconf; step_css ;;
    *) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 1 ;;
esac
