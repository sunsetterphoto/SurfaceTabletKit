# plymouth - boot splash

A Plymouth theme (`surfacetabletkit`): a white Tux silhouette on black with a bitten apple cut out
of its belly, and a thin macOS-style progress bar underneath that appears only while booting, not
on shutdown. The logo takes 30 % of the screen height; all artwork is scaled by one factor so the
bar's round ends stay round on any screen.

The drawing `surfacetabletkit/tux.svg` is an original work - neither Larry Ewing's Tux nor an
Apple asset.

## Files

- `surfacetabletkit/tux.svg` - source of the logo; `tux.png` is rendered from it (640 px high)
- `surfacetabletkit/bar-*.png` - progress bar parts
- `surfacetabletkit/surfacetabletkit.plymouth`, `surfacetabletkit.script` - the theme

## Usage

```bash
./install.sh run plymouth              # = modules/plymouth/apply.sh
modules/plymouth/apply.sh --restore    # back to the previous theme
```

The script installs `plymouth-plugin-script` and `plymouth-scripts` if missing, copies the theme to
`/usr/share/plymouth/themes/surfacetabletkit`, activates it with `plymouth-set-default-theme -R`
(which rebuilds the initramfs of the running kernel) and lists the theme files found in the
initramfs as a check. On the first run it records the previously active theme in
`/var/lib/surfacetabletkit/plymouth-previous-theme` for `--restore`.

Plymouth shows a splash only with `rhgb` on the kernel command line; the script warns if it is
missing.

After editing the logo, re-render and re-install:

```bash
rsvg-convert -h 640 modules/plymouth/surfacetabletkit/tux.svg -o modules/plymouth/surfacetabletkit/tux.png
modules/plymouth/apply.sh
```

## When to re-run

Not needed after kernel updates: dracut includes the active theme in new initramfs images
automatically. Re-run only after changing the theme files.

## Undo

```bash
modules/plymouth/apply.sh --restore
```

Restores the recorded theme (default `bgrt` if none was recorded), rebuilds the initramfs and
removes the theme directory.
