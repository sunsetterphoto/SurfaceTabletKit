# shellcheck shell=bash
# Shared helpers for SurfaceTabletKit modules. Source it, do not execute it.
#
#   KIT_ROOT    repository root (wherever it was cloned; nothing at runtime depends on it)
#   STATE_DIR   per-user state, e.g. which mutter version gnome-rounded-blur was built against
#   DEVICE_ID   surface-pro-7-plus | surface-go-2 | unknown   (from DMI, see devices/*.conf)

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/surfacetabletkit"
ROOT_STATE_DIR="/var/lib/surfacetabletkit"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32mok\033[0m  %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# Run a command as root (sudo when needed).
as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

# The GNOME session modules must run as the desktop user, not as root.
require_user() { [[ $EUID -ne 0 ]] || die "Run this module as your normal user (it asks for sudo itself)."; }

# Install missing RPMs.
need_rpms() {
    local missing=() p
    for p in "$@"; do rpm -q "$p" &>/dev/null || missing+=("$p"); done
    (( ${#missing[@]} )) || return 0
    log "Installing: ${missing[*]}"
    as_root dnf install -y "${missing[@]}"
}

# Device detection from DMI. Profiles live in devices/<id>.conf and are plain bash.
detect_device() {
    local product f
    product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
    DEVICE_ID=unknown
    for f in "$KIT_ROOT"/devices/*.conf; do
        # shellcheck disable=SC1090
        ( source "$f"; [[ "$product" == "$DMI_PRODUCT_NAME" ]] ) && DEVICE_ID="$(basename "$f" .conf)" && break
    done
    DEVICE_PRODUCT="$product"
    if [[ "$DEVICE_ID" != unknown ]]; then
        # shellcheck disable=SC1090
        source "$KIT_ROOT/devices/$DEVICE_ID.conf"
    fi
}

# Enable GNOME Shell extensions by appending to enabled-extensions (never replaces the list)
# and removing them from disabled-extensions.
enable_extensions() {
    python3 -I - "$@" <<'EOF'
import ast, subprocess, sys
def get(k):
    out = subprocess.check_output(["gsettings", "get", "org.gnome.shell", k], text=True)
    return ast.literal_eval(out.replace("@as ", ""))
enabled, disabled = get("enabled-extensions"), get("disabled-extensions")
new = [u for u in sys.argv[1:] if u not in enabled]
if new:
    subprocess.check_call(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(enabled + new)])
rest = [u for u in disabled if u not in sys.argv[1:]]
if rest != disabled:
    subprocess.check_call(["gsettings", "set", "org.gnome.shell", "disabled-extensions", str(rest)])
print("  enabled:", ", ".join(new) if new else "nothing new")
EOF
}

disable_extensions() {
    python3 -I - "$@" <<'EOF'
import ast, subprocess, sys
k = ["gsettings", "get", "org.gnome.shell", "enabled-extensions"]
l = ast.literal_eval(subprocess.check_output(k, text=True).replace("@as ", ""))
rest = [u for u in l if u not in sys.argv[1:]]
if rest != l:
    subprocess.check_call(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(rest)])
EOF
}

EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
