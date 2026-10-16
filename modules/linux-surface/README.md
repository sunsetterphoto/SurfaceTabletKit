# linux-surface - Surface kernel and touch/pen stack (base layer)

Sets up the linux-surface kernel and the touch/pen stack exactly as the official linux-surface
wiki describes it for Fedora
(<https://github.com/linux-surface/linux-surface/wiki/Installation-and-Setup>). Every other module
of the kit assumes this base layer.

## What it does

1. Adds the linux-surface repository, unless `/etc/yum.repos.d/linux-surface.repo` exists:
   ```bash
   sudo dnf config-manager addrepo --from-repofile=https://pkg.surfacelinux.com/fedora/linux-surface.repo
   ```
   (dnf5 syntax, Fedora 41+; the old `--add-repo` no longer exists.)
2. Installs `kernel-surface`, `iptsd` (touch daemon) and `libwacom-surface` (pen data) with
   `--allowerasing`.
3. Under Secure Boot: installs `surface-secureboot`. If it asks for it, enroll the linux-surface
   key on the next boot in the blue MOK screen; the password is `surface`, as documented by
   linux-surface.
4. Enables `linux-surface-default-watchdog.path`, which keeps the Surface kernel as the default
   boot entry when Fedora kernels are updated.

## Usage

```bash
./install.sh run linux-surface       # = modules/linux-surface/apply.sh
```

Idempotent. **Reboot** into the Surface kernel afterwards (`uname -r` contains `surface`), then
continue with the other modules.

## When to re-run

Not needed for normal updates: the kernel comes through `dnf upgrade` from the linux-surface
repository. Before a Fedora release upgrade, check that linux-surface already provides a
repository for the new release (the `linux-surface-watch` module automates that check).

## Undo

Boot a Fedora kernel, then remove the packages and the repository:

```bash
sudo systemctl disable --now linux-surface-default-watchdog.path
sudo dnf remove kernel-surface iptsd libwacom-surface surface-secureboot
sudo rm /etc/yum.repos.d/linux-surface.repo
```

Other modules (`sp7p-kernel`, `touch-right-click`, `touch-anchor`) rely on this layer.

## License

The linux-surface kernel is GPL-2.0; the packages come from the linux-surface project and are not
bundled in this repository.
