# Guide for AI coding agents (Claude Code) applying SurfaceTabletKit

You are on a Microsoft Surface with Fedora Workstation (GNOME) and the user wants this kit
applied. Read `README.md` first, then follow this guide. Each module's `README.md` explains
its root cause, usage, re-apply triggers and undo.

## Working rules

1. **Measure, do not guess.** Every value in this repository was measured on a Surface Pro 7+.
   On any other device (Surface Go 2 and others) treat device-specific values as unknown until
   measured: `rpm -q`, `gsettings get`, `dconf read`, `systemctl`, `libinput list-devices`,
   reading the actual file. If something stays unclear, say so instead of picking a plausible
   value. Report success only when a measurement shows it (screenshot, `verify.sh`, log).
2. **One change at a time when debugging.** Form a hypothesis, change one variable, measure.
3. **Nothing at runtime may depend on the cloned repository.** Modules copy files to their
   system locations; keep it that way if you add something.
4. **Ask before decisions that are the user's**: display scale, optional modules (`gdm-theme`,
   `healthpanel`, `kde-coexistence`, `linux-surface-watch`), anything that needs a reboot.
5. **Keep a record** of what you changed, where, why and how to undo it (in your memory or a
   notes file the user agrees on).

## Before changing anything

```bash
./install.sh                                  # device, Fedora/GNOME/kernel, recommended modules
cat /etc/fedora-release; gnome-shell --version; rpm -q mutter
mokutil --sb-state; cat /proc/cmdline         # Secure Boot? rhgb present (needed for the splash)?
echo $XDG_SESSION_TYPE                        # must be wayland
gnome-extensions list --enabled; ls ~/.themes ~/.local/share/icons
cat ~/.config/monitors.xml                    # connector, resolution, scale
sudo libinput list-devices | grep -B2 -A12 -i touch
rpm -q plasma-workspace                       # KDE installed next to GNOME?
```

Show the user a short summary. Do not overwrite an existing setup without asking (the `design`
module skips existing themes/extensions unless `--force` and backs up settings it overwrites).

- **GNOME version:** the bundled extensions target GNOME 49. On another version
  `modules/design/apply.sh extensions` warns per extension; install matching versions from
  extensions.gnome.org instead and check that the dconf keys still exist. Liquid Glass needs
  blur-my-shell >= 74.
- **Unknown device** (`profile: unknown`): use only generic modules; measure touch/audio values
  first (see `devices/surface-go-2.md` for the method) and create a profile in `devices/`.

## Order of work

| Step | Command | Afterwards |
|---|---|---|
| 1 | `./install.sh run linux-surface` | reboot (Secure Boot: enroll the linux-surface key, password `surface`) |
| 2 | Surface Pro 7+ only: `./install.sh run sp7p-kernel` | first time: reboot to enroll the kit's MOK key, run again, reboot |
| 3 | `./install.sh run design` | - |
| 4 | `./install.sh run rounded-blur osk screen-rotate panel-portrait` | - |
| 5 | choose the display scale with the user | log out and in, check with screenshots |
| 6 | `./install.sh run plymouth flatpak-theming power` | splash visible at next boot |
| 7 | `./install.sh run touch-right-click` (needs measured touch values) | test: hold one second, lift |
| 8 | `./install.sh run touch-anchor` if the profile says `yes` or `tools/touch-log.sh` shows touch devices re-created on resume | test: suspend, resume, drag a GTK window by touch |
| 9 | `./install.sh run audio` (or measure first, see `modules/audio`) | select the preset in EasyEffects |
| 10 | optional modules after asking | - |
| 11 | `./verify.sh` | all items OK |

Extension code is loaded only at login on Wayland (GJS caches modules; `ReloadExtension` does
not work on GNOME 49). Collect the steps that need it and ask for one logout.

## Checking your own work

- Screenshots without a dialog: `python3 -I tools/portal-screenshot.py` (writes to the
  Pictures folder, may overwrite an older one - move it away). `org.gnome.Shell.Screenshot` and
  `Shell.Eval` are denied on GNOME 49.
- You cannot open menus or quick settings yourself; ask the user to look.
- Touch problems: `tools/touch-log.sh`. Rotation problems: `tools/rotation-log.sh`. A small GTK4
  test window that logs `TOUCH_BEGIN` events (run with `WAYLAND_DEBUG=client`) tells whether
  touches reach the app; create it with `Gio.ApplicationFlags.NON_UNIQUE`, otherwise a second
  start hands over to a running instance and exits.
- `pkill -f <pattern>` can kill your own shell when the pattern appears in its command line;
  use PIDs.

## Facts that look like bugs but are deliberate

- Dock: Dash to Dock at the bottom, `dock-fixed=false`, `intellihide-mode=ALL_WINDOWS`,
  `autohide=true` - it shows only over the empty desktop. Do not make it permanent.
  Do not set `transparency-mode` to `DYNAMIC` (fights blur-my-shell).
- blur-my-shell `pipelines` is one dict: when changing one pipeline write all of them back.
  Pipeline radii are in CSS px; blur-my-shell multiplies by the scale factor itself.
- `applications/dynamic-opacity=false`: MacTahoe draws sidebars transparent and needs the blur
  behind focused windows too.
- rounded-window-corners has a blacklist of GTK3 apps: its shader prevents the blur behind GTK3
  windows (A/B tested). A new GTK3 app that looks transparent/sharp -> add its `wm_class`.
- Window buttons on the left (`close,minimize,maximize:`); falling back to the GNOME default is
  a regression, not taste.
- Top bar stays visible (`hidetopbar` is not part of the kit).
- `Can't update stage views actor dashtodockContainer ... needs an allocation` in the journal
  is harmless.
- `gnome-extensions info` shows most extensions `INACTIVE` while the screen is locked.

## Maintenance

See "After updates" in `README.md`; `./verify.sh` reports each case.
