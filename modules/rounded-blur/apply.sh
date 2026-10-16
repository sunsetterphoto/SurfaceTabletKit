#!/usr/bin/env bash
# Builds gnome-rounded-blur (gi://Blur) against the installed mutter and installs it to /usr.
# blur-my-shell needs it for rounded corners on DYNAMIC blur (menus, quick settings, OSD).
# Must be re-run after every mutter update (verify.sh reports it). Idempotent.
#
#   ./apply.sh              build + install
#   ./apply.sh --uninstall  remove exactly the files recorded at install time
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"

STATE="$ROOT_STATE_DIR/rounded-blur"
MANIFEST="$STATE/installed-files.txt"

if [[ "${1:-}" == "--uninstall" ]]; then
    [[ -f "$MANIFEST" ]] || { echo "No $MANIFEST, nothing to remove"; exit 0; }
    while read -r f; do as_root rm -fv "$f"; done < "$MANIFEST"
    as_root rmdir --ignore-fail-on-non-empty /usr/include/blur-effect-1.0 2>/dev/null || true
    as_root ldconfig
    as_root rm -rf "$STATE"
    echo "Removed. Log out and in. Also: dconf write /org/gnome/shell/extensions/blur-my-shell/popup/blur false"
    exit 0
fi

MUTTER="$(rpm -q --qf '%{VERSION}-%{RELEASE}' mutter)"
need_rpms meson gcc gobject-introspection-devel "mutter-devel-$MUTTER"
DEVEL="$(rpm -q --qf '%{VERSION}-%{RELEASE}' mutter-devel)"
[[ "$MUTTER" == "$DEVEL" ]] || die "mutter ($MUTTER) and mutter-devel ($DEVEL) differ: sudo dnf install mutter-devel-$MUTTER"

log "Building against mutter $MUTTER"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
cp -a "$HERE/upstream" "$WORK/src"
patch -d "$WORK/src" -p1 -s < "$HERE/meson-detect-libmutter.patch"
# allow building against the running mutter major version
MAJOR="${MUTTER%%.*}"
sed -i "s/mutter_req = '>= [0-9.]*'/mutter_req = '>= ${MAJOR}.0'/" "$WORK/src/meson.build"
meson setup "$WORK/build" "$WORK/src" --prefix=/usr --libdir=lib64 >/dev/null
meson compile -C "$WORK/build" >/dev/null
DESTDIR="$WORK/stage" meson install -C "$WORK/build" >/dev/null

log "Installing"
as_root install -d -m 755 "$STATE"
( cd "$WORK/stage" && find . \( -type f -o -type l \) | sed 's|^\.||' | sort ) | as_root tee "$MANIFEST" >/dev/null
while read -r f; do
    as_root install -d -m 755 "$(dirname "$f")"
    if [[ -L "$WORK/stage$f" ]]; then as_root ln -sfn "$(readlink "$WORK/stage$f")" "$f"
    elif [[ "$f" == *.so.* ]]; then as_root install -m 755 "$WORK/stage$f" "$f"
    else as_root install -m 644 "$WORK/stage$f" "$f"; fi
done < "$MANIFEST"
as_root ldconfig
echo "$MUTTER" | as_root tee "$STATE/built-against.txt" >/dev/null
cat "$MANIFEST"
echo "Takes effect after logging out and in (GNOME Shell loads gi://Blur only at startup)."
