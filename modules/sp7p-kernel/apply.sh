#!/usr/bin/env bash
# Surface Pro 7+ only: out-of-tree kernel drivers, built for the running linux-surface kernel
# and signed with this device's own MOK key (lib/mok.sh).
#
#   ./apply.sh cameras   int3472 power rails + ov5693 (front) + ov7251 (IR) from linux-surface
#                        PR #2252 -> front and rear camera via libcamera; hides the IR sensor in
#                        PipeWire
#   ./apply.sh gpe       surface_gpe with a Surface Pro 7+ DMI entry -> wake up on lid open
#   ./apply.sh all       both
#   add --force to build on a kernel other than the one the sources were verified on
#
# Must be re-run after every kernel update: a new kernel brings its own unpatched modules.
# verify.sh shows whether the patched modules are active (module signer).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
# shellcheck source=../../lib/mok.sh
source "$KIT_ROOT/lib/mok.sh"

VERIFIED_KERNEL="6.19.8-3.surface.fc43.x86_64"
KVER="$(uname -r)"
WHAT="${1:-}"; FORCE=0; [[ "${2:-}" == "--force" ]] && FORCE=1

detect_device
[[ "$DEVICE_ID" == surface-pro-7-plus ]] || die "These drivers are for the Surface Pro 7+ only (this is: $DEVICE_PRODUCT)."
[[ "$KVER" == *surface* ]] || die "Running kernel $KVER is not a linux-surface kernel (kernel-surface-core)."
if [[ "$KVER" != "$VERIFIED_KERNEL" && $FORCE == 0 ]]; then
    die "The driver sources were verified on $VERIFIED_KERNEL, this is $KVER.
    Check first whether linux-surface already ships the fixes (see README.md), then use --force."
fi

need_rpms gcc make elfutils-libelf-devel xz openssl mokutil "kernel-surface-devel-${KVER%.x86_64}"
mok_ensure_key
mok_ensure_enrolled || exit 0

# build in a temp copy (the repo stays free of build artefacts), sign, compress, install
build_install() {   # srcdir destdir module...
    local src="$1" dest="$2"; shift 2
    local work mod
    work="$(mktemp -d)"
    cp -a "$src/." "$work/"
    [[ -n "${PREBUILD:-}" ]] && ( cd "$work" && eval "$PREBUILD" )
    make -C "/usr/src/kernels/$KVER" M="$work" modules >/dev/null
    for mod in "$@"; do
        mok_sign "$work/$mod.ko"
        xz -fk --check=crc32 --lzma2=preset=9e,dict=1MiB "$work/$mod.ko"   # kernel xz decoder: CRC32 only
        if [[ -f "$dest/$mod.ko.xz" ]] && ! as_root test -f "$dest/$mod.ko.xz.orig" && ! is_ours "$dest/$mod.ko.xz"; then
            as_root cp "$dest/$mod.ko.xz" "$dest/$mod.ko.xz.orig"        # keep the stock module once
        fi
        as_root install -m 0644 "$work/$mod.ko.xz" "$dest/$mod.ko.xz"
        ok "$mod -> $dest"
    done
    rm -rf "$work"
}

# Signers of modules built by this kit (current key and the earlier private key name)
OUR_SIGNERS='^(SurfaceTabletKit module signing key|Int3472 Camera Fix)$'
is_ours() { modinfo -F signer "$1" 2>/dev/null | grep -qE "$OUR_SIGNERS"; }

stock_has() {   # module-path pattern -> 0 if the STOCK module (not one built by us) contains it
    local mod="/lib/modules/$KVER/$1" pat="$2"
    if [[ -f "$mod.orig" ]]; then mod="$mod.orig"
    elif is_ours "$mod"; then return 1          # only our build is there, stock unknown -> rebuild
    fi
    xz -dc "$mod" 2>/dev/null | strings | grep -q -- "$pat"
}

do_cameras() {
    log "Cameras (linux-surface PR #2252)"
    if stock_has kernel/drivers/media/i2c/ov5693.ko.xz binned_y_offset; then
        ok "the stock ov5693 already has binned_y_offset - PR #2252 is in this kernel, nothing to do"
        return 0
    fi
    # int3472: "dovdd" needs 6 bytes, the stock header reserves 5 -> -E2BIG at probe time.
    # Build against a patched copy of the header (editing kernel-devel would be undone by updates).
    local hdr="/usr/src/kernels/$KVER/include/linux/platform_data/x86/int3472.h"
    PREBUILD="mkdir -p include/linux/platform_data/x86 && sed -E 's/^(#define GPIO_SUPPLY_NAME_LENGTH[[:space:]]+)5\$/\\16/' '$hdr' > include/linux/platform_data/x86/int3472.h && grep -qE '^#define GPIO_SUPPLY_NAME_LENGTH[[:space:]]+6\$' include/linux/platform_data/x86/int3472.h" \
        build_install "$HERE/int3472" "/lib/modules/$KVER/kernel/drivers/platform/x86/intel/int3472" \
        intel_skl_int3472_discrete intel_skl_int3472_common
    PREBUILD="" build_install "$HERE/ipu6-sensors" "/lib/modules/$KVER/kernel/drivers/media/i2c" ov5693 ov7251
    as_root install -Dm644 "$HERE/ipu6-sensors/wireplumber/50-surface-hide-ir-camera.conf" \
        /etc/wireplumber/wireplumber.conf.d/50-surface-hide-ir-camera.conf
    ok "IR sensor hidden from PipeWire (it is not a usable camera)"
    need_rpms libcamera pipewire-plugin-libcamera
}

do_gpe() {
    log "Wake on lid open (surface_gpe)"
    if stock_has kernel/drivers/platform/surface/surface_gpe.ko.xz 'Surface Pro 7+'; then
        ok "the stock surface_gpe already knows the Surface Pro 7+, nothing to do"; return 0
    fi
    PREBUILD="" build_install "$HERE/surface-gpe-sp7p" "/lib/modules/$KVER/kernel/drivers/platform/surface" surface_gpe
}

case "$WHAT" in
    cameras) do_cameras ;;
    gpe)     do_gpe ;;
    all)     do_cameras; do_gpe ;;
    *) sed -n '2,15p' "${BASH_SOURCE[0]}"; exit 1 ;;
esac
as_root depmod -a "$KVER"
echo "Done. Reboot to load the new drivers cleanly, then run ./verify.sh."
