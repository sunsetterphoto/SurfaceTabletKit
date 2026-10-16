# gdm-theme - login and lock screen in the WhiteSur look (optional)

Runs WhiteSur-gtk-theme's own `tweaks.sh -g`, which installs a themed
`/usr/share/gnome-shell/gnome-shell-theme.gresource` (WhiteSur GDM theme with its default
wallpaper, blur and darkening). The original Fedora file is kept as
`gnome-shell-theme.gresource.bak`.

## Why it has to be re-applied

Every `gnome-shell` package update (e.g. GNOME 49.5 -> 49.6) overwrites
`/usr/share/gnome-shell/gnome-shell-theme.gresource` with the stock Fedora version, and the
login/lock screen is back to stock GNOME. `rpm -V gnome-shell` is clean after such an update,
which confirms that the package itself replaced the themed file. The `.bak` copy is not touched by
updates.

## Usage

```bash
./install.sh run gdm-theme           # = modules/gdm-theme/apply.sh
modules/gdm-theme/apply.sh --restore # put the original gresource back
```

The script installs `git sassc glib2-devel` if missing, shallow-clones
`vinceliuice/WhiteSur-gtk-theme` into a temp directory, runs `sudo ./tweaks.sh -g` and removes the
clone. The change is visible at the next lock or login.

## When to re-run

After every update that bumps `gnome-shell`. Quick check:

```bash
md5sum /usr/share/gnome-shell/gnome-shell-theme.gresource{,.bak}
# both sums equal -> the stock theme is active, re-run the module
```

## Undo

```bash
modules/gdm-theme/apply.sh --restore
# same as: sudo cp /usr/share/gnome-shell/gnome-shell-theme.gresource{.bak,}
```

## Notes

- This module covers only the GDM/lock screen. The session look (GTK, Shell theme, cursor, fonts,
  extensions) is the `design` module.
- WhiteSur-gtk-theme is MIT licensed; it is cloned at run time, not bundled.
