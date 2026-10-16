# flatpak-theming - Flatpak apps in the MacTahoe look

Lets Flatpak apps read the GTK themes, and gives the Spotify Flatpak the MacTahoe window frame
(traffic-light buttons) instead of the frame its embedded browser engine draws on Wayland.

## 1. Global Flatpak override

`~/.local/share/flatpak/overrides/global` gets read-only access to the themes:

```
[Context]
filesystems=xdg-config/gtk-3.0:ro;xdg-config/gtk-4.0:ro;xdg-data/themes:ro;~/.themes:ro;
```

Deliberately **without** `[Environment] GTK_THEME=...`: GTK3 Flatpaks pick up the theme through
the Settings portal, including later theme changes. A hard-wired `GTK_THEME` (for example from an
earlier WhiteSur setup) is removed by the script. `xdg-data/themes` alone is not enough because
MacTahoe lives in `~/.themes`; Flatpaks without home access (e.g. virt-manager) otherwise fall
back to light Adwaita.

The old `GTK_THEME` line is removed by editing the file, not with `--unset-env`, because that would
permanently write an empty `GTK_THEME=`.

## 2. Spotify: MacTahoe frame instead of the fallback frame

Spotify (Flatpak) runs natively on Wayland, where its embedded CEF draws a blue fallback frame.
Forced to X11, mutter draws the MacTahoe frame. Both parts are needed:

- `~/.var/app/com.spotify.Client/config/spotify-flags.conf` contains `--ozone-platform=x11`
- `flatpak override --user --nosocket=fallback-x11 --socket=x11 com.spotify.Client`
  (`--socket=x11` alone is not enough: `fallback-x11` suppresses X11 under Wayland, and Spotify
  then exits silently with exit code 1)

This part runs only if the Spotify Flatpak is installed.

## Usage

```bash
./install.sh run flatpak-theming      # = modules/flatpak-theming/apply.sh
```

Idempotent. Restart the Flatpak apps afterwards.

## When to re-run

After installing Spotify (part 2 is skipped while it is missing).

## Undo

- Global: delete `~/.local/share/flatpak/overrides/global`, or copy back the
  `global.bak-<date>` the script created next to it.
- Spotify: delete `spotify-flags.conf` and run
  `flatpak override --user --reset com.spotify.Client`.
