#!/usr/bin/env bash
# Base layer: the linux-surface kernel and touch/pen stack, exactly as the linux-surface
# wiki describes it for Fedora (https://github.com/linux-surface/linux-surface/wiki/Installation-and-Setup).
# Everything else in this kit assumes it. Needs a reboot afterwards. Idempotent.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$HERE/../../lib/common.sh"
# shellcheck source=../../lib/mok.sh
source "$KIT_ROOT/lib/mok.sh"

log "linux-surface repository"
if [[ -f /etc/yum.repos.d/linux-surface.repo ]]; then
    ok "already configured"
else
    # dnf5 (Fedora 41+): "--add-repo" no longer exists
    as_root dnf config-manager addrepo --from-repofile=https://pkg.surfacelinux.com/fedora/linux-surface.repo
fi

log "Kernel, touch daemon, pen data"
as_root dnf install -y --allowerasing kernel-surface iptsd libwacom-surface

if secure_boot_enabled; then
    log "Secure Boot is on: linux-surface signing key"
    need_rpms surface-secureboot
    echo "  If surface-secureboot asked for it: on the next boot enroll the key in the blue"
    echo "  MOK screen, password: surface (as documented by linux-surface)."
fi

log "Keep the Surface kernel as default when Fedora kernels update"
as_root systemctl enable --now linux-surface-default-watchdog.path || warn "watchdog unit not found"

if [[ "$(uname -r)" != *surface* ]]; then
    warn "Reboot now into the Surface kernel, then continue with the other modules."
else
    ok "running $(uname -r)"
fi
