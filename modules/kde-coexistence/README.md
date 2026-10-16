# kde-coexistence - keep KDE Plasma from changing GNOME

Only for systems that have KDE Plasma installed next to GNOME (the script exits immediately if
`plasma-workspace` is not installed). It applies two protections:

1. Plasma's kded module **gtkconfig** is switched off, so a Plasma login no longer writes Plasma's
   theme into GNOME's gsettings.
2. **xwaylandvideobridge** is limited to Plasma, so it no longer puts an invisible full-screen
   window over the GNOME session.

## 1. kded gtkconfig

At every Plasma login gtkconfig writes Plasma's GTK theme, icons, cursor and fonts into GNOME's
gsettings, which overwrites the `design` module's settings. The module sets
`[Module-gtkconfig] autoload=false` in `~/.config/kded5rc` and tells the running kded6 to stop
autoloading it. Note: kded6 reads `kded5rc` (measured), not `kded6rc`.

## 2. xwaylandvideobridge

### Symptom

In the GNOME Wayland session one workspace (whichever one the bridge window landed on) behaved as
if a fullscreen app were running on it:

- top bar hidden
- Dash to Dock hidden (its intellihide treats the workspace as occupied)
- desktop icons still *visible* but not clickable - clicks went to an invisible window stacked
  above the gtk4-ding desktop layer
- every other workspace looked normal

Nothing showed up in the overview, because the bridge window is transparent and `NoDisplay=true`.

### Root cause

`xwaylandvideobridge` is a Plasma helper that re-exports Wayland windows to X11 apps (Discord,
Zoom, Teams screen sharing). It maps an X11 window the size of the whole screen. Its autostart
file ships **without** an `OnlyShowIn` key and **with** `X-GNOME-Autostart-enabled=true`:

```
/etc/xdg/autostart/org.kde.xwaylandvideobridge.desktop
  X-GNOME-Autostart-enabled=true
  NoDisplay=true
  (no OnlyShowIn)
```

so gnome-session starts it. Confirmed with `systemctl --user list-units | grep xwayland`:

```
app-gnome-org.kde.xwaylandvideobridge-<pid>.scope   Application launched by gnome-session-service
```

and the window itself with `xwininfo -root -children` (package `xwininfo`), on a Surface Pro 7+:

```
0xc00004 "<localised window title>"  2736x1824+0+0
```

That is the full panel resolution at the origin - the invisible overlay.

### Fix

A user autostart file with the **exact same basename** shadows the system one, and
`OnlyShowIn=KDE;` keeps the bridge running under Plasma, where it belongs:

```
~/.config/autostart/org.kde.xwaylandvideobridge.desktop
```

Here shadowing is the point, so the file name must match exactly. When run inside GNOME, the
script also kills the running bridge.

## Usage

```bash
./install.sh run kde-coexistence     # = modules/kde-coexistence/apply.sh
```

Log out and back in afterwards.

## Verify

```bash
# pgrep -x cannot match this: the name has 21 chars and the kernel truncates comm to 15.
pgrep -f '^/usr/bin/xwaylandvideobridge$'   # no output inside a GNOME session
xwininfo -root -children | grep 2736        # no full-screen window (use your panel width)
```

## When to re-run

After reinstalling Plasma, or if a Plasma update brings the problems back. `./verify.sh` is
useful after a Plasma session.

## Undo

```bash
kwriteconfig6 --file kded5rc --group Module-gtkconfig --key autoload true
rm ~/.config/autostart/org.kde.xwaylandvideobridge.desktop
```

## Alternative

If the bridge is not needed in Plasma either, `sudo dnf remove xwaylandvideobridge` works too;
nothing else depends on it (`rpm -q --whatrequires` comes back empty).
