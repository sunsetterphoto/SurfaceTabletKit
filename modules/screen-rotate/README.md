# screen-rotate - reliable auto-rotation (own D-Bus connection for the accelerometer)

Copies the system extension `screen-rotate@shyzus.github.io` (RPM
`gnome-shell-extension-screen-autorotate`) to `~/.local/share/gnome-shell/extensions/`, where it
takes precedence over `/usr/share`, and patches `sensorProxy.js` to use its own system-bus
connection. After that mutter can no longer drop the extension's accelerometer claim.

## Symptom

After suspend or screen blanking the screen no longer rotated to portrait, although the sensor
reported the new orientation (`monitor-sensor`: `left-up`, the display stayed at transform 0).
Toggling "Auto Rotate" off and on fixed it immediately.

## Root cause (source code + measurement)

- iio-sensor-proxy 3.8 keeps claims (`ClaimAccelerometer`) **per D-Bus sender** and sends
  `PropertiesChanged` only to senders that claimed (`send_dbus_event_for_client`,
  `g_dbus_connection_emit_signal` with a destination bus name).
- The extension used `Gio.BusType.SYSTEM`, i.e. the **shared** system-bus connection of the
  gnome-shell process - the same one mutter's `MetaOrientationManager` uses.
- mutter 49.8 releases the sensor (`ReleaseAccelerometer`) whenever it does not manage rotation
  itself or the screen goes into power-save (`meta-monitor-manager.c`: `inhibit_tracking` on
  power-save and with `panel_orientation_managed = false`). That released the extension's claim as
  well; the extension still believed it was claimed and never received another update.
- A/B test outside the shell with the same sequence (claim + release over a shared connection, as
  mutter does): original **0** updates despite 3 orientation changes; patched **6** updates, the
  rotate callback fired 4 times.

## Patch

`sensorProxy.patch`: its own `Gio.DBusConnection` to the system bus, name watching and the proxy on
that connection; the connection is closed when the extension is disabled. Nothing else changed.

## Why mutter does not rotate by itself here

mutter rotates in tablet use only in touch mode. Without a cover there is no tablet-mode switch,
so `touch_mode = !has_pointer` applies (`meta-seat-impl.c`). The virtual pointer of the
`touch-right-click` module ("Simulated Right Button") is a pointer device, so mutter never enters
touch mode. Other virtual pointer devices have the same effect (an unused `ydotool.service` was
disabled for that reason). Rotation is therefore handled by this extension alone.

## Usage

```bash
./install.sh run screen-rotate           # = modules/screen-rotate/apply.sh
```

Installs `gnome-shell-extension-screen-autorotate` and `patch` if missing, patches a copy, records
the base RPM version in `~/.local/state/surfacetabletkit/screen-rotate-built-from.txt` and enables
the extension. Takes effect after logging out and back in.

For diagnosis, `tools/rotation-log.sh` logs accelerometer claims/releases, rotations, sensor
orientation, suspend and Type Cover events into one time-stamped file.

## When to re-run

After every RPM update of `gnome-shell-extension-screen-autorotate` (the user copy otherwise keeps
the old version). If the patch no longer applies, the script stops: the extension changed and
`sensorProxy.patch` has to be ported by hand.

## Undo

```bash
modules/screen-rotate/apply.sh --remove      # the unpatched system copy is used from the next login
```

## License

The extension is GPL-3.0 (`licenses/gnome-shell-extension-screen-autorotate.LICENSE.md`); only a
patch is part of this repository.
