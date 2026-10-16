# rounded-blur - rounded corners for blurred menus (gnome-rounded-blur)

Builds [gnome-rounded-blur](https://github.com/kancko/gnome-rounded-blur) (`gi://Blur`) against the
installed mutter and installs it to `/usr`. blur-my-shell needs it to round the corners of
**dynamic** blur: top-bar menus, quick settings, calendar, notifications and OSD.

## Why

blur-my-shell v74 also blurs popups, by default dynamically. GNOME Shell's own blur effect cannot
do rounded corners, so behind every rounded menu there was a **square blur rectangle** whose
corners stuck out visibly. Cross-check: with `blur-my-shell/popup/blur=false` the corners were
clean.

blur-my-shell rounds dynamic blur only when the external library gnome-rounded-blur is present. It
is a copy of GNOME Shell's `ShellBlurEffect` with a corner mask in the GI namespace `Blur`. Whether
blur-my-shell found it:

```bash
dconf read /org/gnome/shell/extensions/blur-my-shell/rounded-blur-found   # true
```

It is built locally because the Copr `ublue-os/packages` provides the package only for Fedora 44;
the kit targets Fedora 43 with GNOME 49 / mutter 49 (`libmutter-17`).

## What `apply.sh` does

- installs `meson gcc gobject-introspection-devel` and `mutter-devel` in **exactly** the installed
  mutter version (it stops if the versions differ)
- builds `upstream/` (pinned upstream commit `a4db9e5`) in a temp directory
- `meson-detect-libmutter.patch` fixes two upstream problems:
  1. the detection picked `libmutter-test-17` instead of `libmutter-17`, so Clutter and Cogl were
     missing as dependencies, and it built anyway;
  2. `mutter_req '>= 50.0'` is hard-coded; the script sets it to the installed major version.
- installs through a staging directory and records every installed file in
  `/var/lib/surfacetabletkit/rounded-blur/installed-files.txt` (uninstall removes exactly these)
- writes the mutter version it was built against to
  `/var/lib/surfacetabletkit/rounded-blur/built-against.txt`

## Usage

```bash
./install.sh run rounded-blur            # = modules/rounded-blur/apply.sh
```

Takes effect after logging out and back in (GNOME Shell loads `gi://Blur` only at startup).

## When to re-run: after every mutter update

The library is built against the ABI of `libmutter-clutter-17`. After a mutter update:

1. `modules/rounded-blur/apply.sh` (it installs the matching `mutter-devel`)
2. log out and back in

`./verify.sh` reports it when `built-against.txt` no longer matches `rpm -q mutter`.

## Undo

```bash
modules/rounded-blur/apply.sh --uninstall
dconf write /org/gnome/shell/extensions/blur-my-shell/popup/blur false   # otherwise the square corners return
```

Then log out and in. The build dependencies (`mutter-devel`, `meson`, ...) stay installed; remove
them with `dnf` if not needed.

## License

gnome-rounded-blur is GPL-3.0 (`upstream/LICENSE`). `upstream/` is the unmodified upstream source;
the kit's changes are in `meson-detect-libmutter.patch` and the `sed` in `apply.sh`.
