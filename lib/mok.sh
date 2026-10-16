# shellcheck shell=bash
# Machine Owner Key (MOK) handling for the out-of-tree kernel modules. Source it.
#
# Every device gets its OWN signing key. It is generated locally, stays in
# /var/lib/surfacetabletkit/mok (root only) and is never part of the repository.
# Under Secure Boot the public half must be enrolled once: `mokutil --import` asks for a
# one-time password, and on the next boot the blue MokManager screen asks to confirm it.
#
# An existing, already enrolled key can be used instead:
#   MOK_KEY=/path/MOK.priv MOK_CRT=/path/MOK.der ./apply.sh ...
#
# The kernel does not check X.509 validity dates for module signing keys (the checks were
# removed upstream in 2013; in 6.19 crypto/asymmetric_keys/x509_public_key.c only prints
# them). The 100-year lifetime just avoids the question.

MOK_DIR="/var/lib/surfacetabletkit/mok"
MOK_KEY="${MOK_KEY:-$MOK_DIR/MOK.priv}"
MOK_CRT="${MOK_CRT:-$MOK_DIR/MOK.der}"

secure_boot_enabled() { mokutil --sb-state 2>/dev/null | grep -q 'SecureBoot enabled'; }

# Creates the key pair if it does not exist yet.
mok_ensure_key() {
    if as_root test -f "$MOK_KEY" && as_root test -f "$MOK_CRT"; then
        ok "signing key: $MOK_CRT"
        return 0
    fi
    log "Creating a signing key for this device in $MOK_DIR"
    need_rpms openssl mokutil
    as_root install -d -m 700 "$MOK_DIR"
    as_root openssl req -new -x509 -newkey rsa:2048 -sha256 -nodes -days 36500 \
        -subj "/CN=SurfaceTabletKit module signing key/" \
        -keyout "$MOK_KEY" -outform DER -out "$MOK_CRT" 2>/dev/null
    as_root chmod 600 "$MOK_KEY"
    ok "created $MOK_CRT (private key stays root-only in $MOK_DIR)"
}

# Returns 0 if the key is enrolled (or Secure Boot is off), otherwise starts the enrollment
# and returns 1 - the caller should stop and ask for a reboot.
mok_ensure_enrolled() {
    if ! secure_boot_enabled; then
        ok "Secure Boot is off - signatures are not enforced (modules are signed anyway)"
        return 0
    fi
    local cert; cert="$(mktemp)"; as_root cat "$MOK_CRT" > "$cert"
    if mokutil --test-key "$cert" 2>/dev/null | grep -q 'already enrolled'; then
        rm -f "$cert"; ok "signing key is enrolled in MOK"; return 0
    fi
    warn "The signing key is not enrolled yet. Enrolling it now:"
    echo "  - choose a one-time password (you only need it once, at the next boot)"
    as_root mokutil --import "$cert"
    rm -f "$cert"
    cat <<'MSG'

  Next boot: a blue "MOK management" screen appears.
    Enroll MOK -> Continue -> Yes -> enter the one-time password -> Reboot.
  Then run this module again; it will build, sign and install the drivers.
MSG
    return 1
}

# Signs a .ko in place.
mok_sign() {
    local ko="$1" sign="/usr/src/kernels/$(uname -r)/scripts/sign-file"
    [[ -x "$sign" ]] || die "missing $sign - install kernel-devel for $(uname -r)"
    as_root "$sign" sha256 "$MOK_KEY" "$MOK_CRT" "$ko"
}
