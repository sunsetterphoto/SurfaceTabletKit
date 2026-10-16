# panel-portrait - top bar that fits in portrait orientation

A small GNOME Shell extension (`panel-portrait@surfacetabletkit`, GNOME 49) that makes the top bar
fit while the primary monitor is in portrait orientation. The top bar keeps its content; only empty
space is reduced first, and less important items disappear only if that is not enough.

## Why

At 200 % scaling the Surface Pro 7+ panel (2736x1824) is only 912 px wide in portrait
(1824 / 2). The clock is centred, and the right side overflowed: keyboard layout, volume and
battery were cut off.

## How it works

While in portrait, levels are applied one after another, only as far as needed:

1. Tighter spacing: `.panel-button` horizontal padding 6 px natural / 4 px minimum instead of
   MacTahoe's 12 / 12 (`stylesheet.css`, class `surfacetabletkit-portrait` on `#panel`).
2. If it still does not fit: also hide the tray icons (`appindicator-*` status-area entries) and
   the keyboard-layout indicator.
3. If it still does not fit: also show the clock without the date (own label, `%H:%M`).

"Fits" is measured the way GNOME's panel allocates: the centre box is centred, left and right each
get half of the remaining width (`get_preferred_width` of the three boxes). It is re-evaluated on
rotation / monitor changes, when indicators are added or removed, and on every clock tick. In
landscape everything is taken back. If another extension shows a hidden icon again, it is hidden
again.

## Usage

```bash
./install.sh run panel-portrait          # = modules/panel-portrait/apply.sh
```

The extension is copied to `~/.local/share/gnome-shell/extensions/` (no runtime dependency on the
repository) and enabled. It takes effect after logging out and back in.

## When to re-run

After changing the extension in the repository. A GNOME major update needs a check: `metadata.json`
lists only Shell version 49.

## Undo

```bash
modules/panel-portrait/apply.sh --remove     # gone after logging out and in
```

## Limits

- The spacing values target the MacTahoe Shell theme.
- Only the primary monitor's orientation is considered.
