# SurfaceTabletKit

Turn a Microsoft Surface running **Fedora Workstation (GNOME)** into a polished Linux tablet:
a macOS-inspired glass look, touch that keeps working after suspend, reliable auto-rotation,
an on-screen keyboard that appears only when it is needed, long-press right click everywhere,
a custom boot splash, tuned speakers and - on the Surface Pro 7+ - working cameras and
wake-on-lid-open.

Every fix in this kit was found by measuring on real hardware first. Each module documents
the root cause it addresses (with source references and test results), how to undo it, and
when it has to be re-applied after updates.

## Supported devices

| Device | Status |
|---|---|
| Surface Pro 7+ | Fully measured and in daily use: all modules, including cameras, wake on lid open and the speaker preset |
| Surface Go 2 | Device profile prepared. Touchscreen name, display scale and speaker preset must be measured on the device first (the kit tells you how) |
| Other Surface models | The generic modules (look, rotation, keyboard, portrait top bar, Flatpak theming, power) should work; device-specific values must be measured |

Requirements: Fedora Workstation 43 with GNOME 49 on Wayland, the
[linux-surface](https://github.com/linux-surface/linux-surface) kernel (the `linux-surface`
module installs it), internet access during installation.

## Install

```bash
git clone https://github.com/sunsetterphoto/SurfaceTabletKit.git
cd SurfaceTabletKit
./install.sh            # shows the detected device and the recommended modules
./install.sh guided     # goes through them, asking before each one
./verify.sh             # read-only check afterwards
```

Run it as your normal user; modules ask for `sudo` where they need it. Single modules:
`./install.sh run <module>`. Nothing at runtime depends on the cloned folder - files are
copied to their system locations, so you can delete or move the clone afterwards.

Log out and back in once at the end: GNOME Shell loads extension code only at login.

## Modules

| Module | What it does |
|---|---|
| `linux-surface` | Base layer from the linux-surface project: kernel, `iptsd` (touch), `libwacom-surface` (pen) |
| `sp7p-kernel` | Surface Pro 7+ only: front and rear camera (libcamera), wake on lid open. Built for the running kernel and signed with a key generated on *your* device |
| `design` | MacTahoe-Dark theme (GTK3, GTK4/libadwaita, Shell), Colloid-Dark icons, WhiteSur cursors, Inter font, dock, "Liquid Glass" dock and top bar, rounded windows, window buttons on the left, desktop icons |
| `rounded-blur` | Rounded corners behind blurred menus and quick settings (builds `gi://Blur` against mutter) |
| `osk` | On-screen keyboard: glass background, PC key labels, opens automatically only when no hardware keyboard is attached |
| `screen-rotate` | Auto-rotation that keeps working after screen blanking and suspend |
| `panel-portrait` | Top bar fits in portrait: tighter spacing first, then hides tray icons and the date only if still needed |
| `plymouth` | Boot splash: white Tux with a bitten apple cut out, thin macOS-style progress bar |
| `gdm-theme` | Optional: login and lock screen in the WhiteSur look |
| `flatpak-theming` | Flatpak apps follow the theme; Spotify gets a proper window frame |
| `touch-right-click` | Hold a finger for one second, lift it: right click, in every app |
| `touch-anchor` | Keeps touch working in GTK apps after suspend (prevents freezes and crashes when dragging windows) |
| `audio` | EasyEffects speaker preset measured per device, plus a measurement tool for new devices |
| `power` | Balanced power profile, no TLP/tuned conflict, removes an impossible hibernate setup |
| `healthpanel` | Optional: [HealthPanel](https://github.com/sunsetterphoto/HealthPanel) system monitor in the top bar |
| `kde-coexistence` | Only if KDE Plasma is installed too: stops Plasma from overwriting GNOME's look |
| `linux-surface-watch` | Optional: notifies you once linux-surface supports the next Fedora release, so upgrading does not drop the Surface kernel |

Details for each module are in `modules/<module>/README.md`.

## After updates

`./verify.sh` tells you what needs re-applying. In short:

| After an update of | Re-run |
|---|---|
| the kernel (Surface Pro 7+) | `sp7p-kernel`, then reboot |
| `mutter` | `rounded-blur`, then log out and in |
| `gnome-shell` | `gdm-theme` (if used) |
| the GJS OSK extension | `osk`, then log out and in |
| `gnome-shell-extension-screen-autorotate` | `screen-rotate`, then log out and in |

Before upgrading Fedora to a new release, make sure linux-surface already provides packages
for it (`linux-surface-watch`).

## Secure Boot and kernel modules

The Surface Pro 7+ camera and lid drivers are out-of-tree kernel modules. Under Secure Boot
they must be signed. The kit generates a signing key **on your device**
(`/var/lib/surfacetabletkit/mok`, readable by root only) - no key is shipped in this repository.
The first time, `mokutil --import` asks for a one-time password, and the next boot shows a
blue "MOK management" screen where you enroll the key. After that, rebuilding after kernel
updates needs no further interaction.

## Undo

Every module can be undone (`--remove`, `--restore` or `--uninstall`, see its README). Settings
changed by the `design` module are backed up to `~/.local/state/surfacetabletkit/` before they
are overwritten.

## Tools

- `tools/measure-speakers.py` - measures the speakers with a microphone and suggests the
  high-pass and the resonances to cut (pure Python, no extra packages)
- `tools/touch-log.sh`, `tools/rotation-log.sh` - log touch devices, suspend, rotation and
  sensor claims over hours, to find out what triggers a problem
- `tools/portal-screenshot.py` - take a screenshot without a confirmation dialog (for checks)

## Disclaimer

This kit changes system files, installs kernel modules and touches the boot process. It is
tested on the hardware listed above; use it at your own risk and read a module's README before
running it.

## License

GPL-3.0 for the kit itself. Bundled third-party components keep their own licenses, see
[THIRD_PARTY.md](THIRD_PARTY.md).
