# design - macOS-style look for GNOME 49

Installs the themes, icons, cursors and GNOME Shell extensions of the kit and loads their settings:
MacTahoe-Dark for GTK3, GTK4/libadwaita and the Shell, Colloid-Dark icons, WhiteSur cursors, the
Inter font, a bottom dock and "Liquid Glass" blur for dock and top bar.

## Usage

```bash
./install.sh run design            # = modules/design/apply.sh all
modules/design/apply.sh <step> [--force]
```

| Step | What it does |
|---|---|
| `packages` | installs missing RPMs: `rsms-inter-fonts`, `git`, `unzip`, `gnome-shell-extension-screen-autorotate`; warns if `gnome-backgrounds` (glass-chip wallpaper) is missing |
| `themes` | unpacks MacTahoe-Dark (+hdpi/xhdpi) to `~/.themes`, Colloid-Dark to `~/.local/share/icons`, installs WhiteSur cursors with their own installer, puts MacTahoe's libadwaita part into `~/.config/gtk-4.0` (`gtk.css -> gtk-Dark.css`; an existing `~/.config/gtk-4.0` is backed up first) |
| `extensions` | installs the vendored extensions to `~/.local/share/gnome-shell/extensions`, downloads space-bar from extensions.gnome.org, enables them, disables `background-logo@fedorahosted.org` |
| `dconf` | loads `config/*.conf` (current values are dumped to a backup first) and points the on-screen keyboard at the built-in `eDP` panel |
| `css` | appends `css/mactahoe-shell-overrides.css` to the MacTahoe Shell theme and installs `css/ding-stylesheet-override.css` for the desktop icons |
| `healthpanel` | optional: installs and enables the HealthPanel top-bar system monitor (CPU load + temperature) |
| `all` | `packages themes extensions dconf css` |

Existing themes and extensions are skipped; `--force` replaces them. Every step is idempotent.

Extensions load only at login on Wayland: **log out and back in** afterwards, then run `./verify.sh`.

Backups go to `~/.local/state/surfacetabletkit/backup-<date>-design/`.

## The look (values from `config/`)

- **GTK/Shell:** `gtk-theme` and user-theme `MacTahoe-Dark`, `color-scheme` `prefer-dark`, accent
  blue. Icons `Colloid-Dark`, cursor `WhiteSur-cursors` size 24. Font `Inter 11`, titlebar
  `Inter Display Bold 11`, grayscale antialiasing, slight hinting.
- **Window buttons left:** `button-layout='close,minimize,maximize:'`.
- **Wallpaper:** GNOME's glass-chip (`glass-chip-l.jxl` / `glass-chip-d.jxl`).
- **Top bar (just-perfection):** no Activities button, no hot corner. Workspaces are shown
  by space-bar. The top bar stays visible on purpose.
- **Dock (dash-to-dock):** at the bottom, `dock-fixed=false`, `autohide=true`,
  `intellihide=true` with `intellihide-mode='ALL_WINDOWS'` - it hides when any window overlaps it.
  In practice it shows only over the empty desktop. This is deliberate - do not make it fixed, and
  do not set `transparency-mode` to `DYNAMIC` (it fights blur-my-shell). Icon size max 56, dots as
  running indicator, click minimises, scroll cycles windows.
- **Minimise animation:** compiz-alike-magic-lamp-effect (`sine`, 280 ms).
- **Desktop icons:** gtk4-ding, starting at the top-right corner.
- Also enabled: appindicator, caffeine, gjsosk (on-screen keyboard, see `modules/osk`),
  screen-rotate (see `modules/screen-rotate`).

Display scaling and stylus calibration are deliberately not part of `gnome-desktop.conf`: they are
device specific (the Surface Pro 7+ default is 200 % at 2736x1824, see `devices/*.conf`).

### Liquid Glass (blur-my-shell)

Dock and top bar use static blur-my-shell pipelines with the **refraction** effect:

| Pipeline | Used by | Main values |
|---|---|---|
| `pipeline_dock_glass` | dash-to-dock | gaussian radius 1, refraction strength 0.55, edge 26, rim 4, corner radius 28, gloss 0.8, tint 0.4 of (0.11, 0.11, 0.13), rgb fringing 0.08; corner effect 28 |
| `pipeline_panel_glass` | top bar | gaussian radius 1, refraction strength 0.45, edge 12, rim 3, corner radius 0, gloss 0.7, tint 0.4, rgb fringing 0.06 |

- The refraction effect needs **blur-my-shell >= 74**; `./verify.sh` checks the version.
- Radii are in CSS px; blur-my-shell applies the display scale factor itself.
- `pipelines` is a single dconf dict: when changing one pipeline, write all of them back.
- Application blur is on for all apps (`enable-all=true`, radius 24) with
  `dynamic-opacity=false`: MacTahoe's sidebars are transparent and rely on the blur behind them.
- Popup radii: menus 14, quick settings 33, dialogs 40, OSD 24, on-screen keyboard 28.
  Rounded corners on blurred menus additionally need the `rounded-blur` module.

### rounded-window-corners blacklist

`rounded-window-corners-reborn` rounds windows with a shader (radius 24). That shader prevents
blur-my-shell's blur behind GTK3 windows (A/B tested). GTK3 apps that MacTahoe already rounds
itself are therefore blacklisted (`gtk3-widget-factory`, `virt-manager`, Remmina, GIMP, darktable,
RawTherapee, ART, `gnome-disks`, `gcr-viewer`, ColorProfileViewer and others, see
`config/rounded-window-corners-reborn.conf`). If a new GTK3 app looks transparent/sharp instead of
blurred, add its `wm_class` there.

### CSS overrides

- `css/mactahoe-shell-overrides.css` - quick settings (system menu, top right) about **10 %
  smaller** than MacTahoe's default (paddings, spacing, toggle size; fonts and icons unchanged so
  it stays touch-friendly), plus the on-screen keyboard panel radius (28 px, like the dock) and
  translucent white keys. `css/apply-shell-overrides.sh` appends it between markers to
  `~/.themes/MacTahoe-Dark/gnome-shell/gnome-shell.css` (original kept as `.orig`) and reloads
  the theme; `--remove` takes it out again.
- `css/ding-stylesheet-override.css` - desktop context menus of gtk4-ding, copied to
  `~/.config/com.desktop.ding/stylesheet-override.css`. GTK4 popovers are separate `xdg_popup`
  windows that blur-my-shell cannot blur, so instead of glass they get a dense tint in the dock's
  colour (`rgba(28, 28, 33, 0.88)`) with a light inner rim.

## When to re-run

- After reinstalling or updating MacTahoe: `modules/design/apply.sh css` (the override block is
  appended to the theme file and lost when it is replaced).
- After a GNOME major update: `modules/design/apply.sh extensions --force` warns about extensions
  whose `metadata.json` does not list the running Shell version; get matching versions from
  extensions.gnome.org.
- After an extension update that reset settings: `modules/design/apply.sh dconf`.

## Undo

- Settings: `dconf load <path> < <backup>.conf` with the files from the backup directory (the
  `dconf` step prints it).
- Shell CSS: `modules/design/css/apply-shell-overrides.sh --remove`.
- Desktop menu CSS: delete `~/.config/com.desktop.ding/stylesheet-override.css`.
- Themes/extensions: switch back in GNOME Tweaks / Extensions, delete the folders in `~/.themes`,
  `~/.local/share/icons`, `~/.local/share/gnome-shell/extensions`; the old `~/.config/gtk-4.0` is
  in the backup directory.

## Notes and licenses

- space-bar is not bundled: it has no upstream license, so it is downloaded from
  extensions.gnome.org for the running Shell version.
- Colloid inherits `hicolor,breeze`; without `breeze-icon-theme` missing icons fall back to
  hicolor/Adwaita.
- The bundled themes and extensions keep their own licenses; see `licenses/` in the repository
  root.
