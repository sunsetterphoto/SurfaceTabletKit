# touch-anchor - touch keeps working in GTK apps after suspend

A tiny system service that creates a virtual touchscreen ("SurfaceTabletKit Touch Anchor") via
uinput which never sends a single event. As long as it exists, mutter never withdraws the Wayland
touch capability, so GTK apps keep their touch device across suspend.

Needed on devices that remove and re-create their touch devices on resume. That is the case on
the Surface Pro 7+ (`NEEDS_TOUCH_ANCHOR=yes` in `devices/surface-pro-7-plus.conf`); on other
devices check it with `tools/touch-log.sh` across a suspend.

## Symptom

After resuming from suspend, running GTK4 apps (Ptyxis terminal, Files, gtk4-ding desktop icons)
no longer react to touch: dragging windows, tabs and buttons are ignored. Top bar, dock and
on-screen keyboard (all GNOME Shell) keep working. Trying to drag such a window by touch crashes
the app (SIGSEGV). Freshly started apps work - until the next suspend.

## Root cause (measured + source code)

1. **On resume all touch devices are removed and re-created.** ithc re-registers the touch
   controller (`0001:045E:0C1A.000N` with a new number), iptsd moves from `hidraw0` to `hidraw1`
   and re-creates "IPTSD Virtual Touchscreen". In a recording: DEVICE_REMOVED at .125/.130 s,
   DEVICE_ADDED at .258/.276 s - about **0.15 s without any touch device**.
2. mutter computes the seat capabilities from all physical devices (`meta-wayland-seat.c`,
   `lookup_device_capabilities`). Without a touch device it withdraws
   `WL_SEAT_CAPABILITY_TOUCH`.
3. GTK 4.20.4 (`gdkseat-wayland.c`, capabilities handler) then releases its device "Wayland Touch
   Logical Pointer" (`gdk_seat_device_removed` -> seat = NULL) and creates a new one when the
   capability returns.
4. A `GtkGesture` remembers the device of its first point (`gtkgesture.c`, `priv->device`) and
   forgets it only when all points have ended. While it still holds a point it discards new touches
   as coming from the "wrong device" (`gtkgesture.c:467`: touch ignored). Motion events with the
   same touch sequence pass without a device check and call `gdk_toplevel_begin_move` with the old
   device -> crash.
   Confirmed with a core dump with debug symbols (nautilus):
   `_gdk_wayland_seat_get_last_implicit_grab_serial (seat=0x0)`, device "Wayland Touch Logical
   Pointer", `seat = 0x0`, `associated = 0x0`. Identical for Ptyxis twice, each time after a
   suspend.
5. **Not** the cause: a touch left open when going to sleep. In the recording every TOUCH_DOWN
   before the suspend had its TOUCH_UP.

## Fix

`touch-anchor.c` creates a virtual direct-input touchscreen (multitouch axes, range 0..9600 x
0..7200 like the iptsd device) that never sends events. A touch device therefore always exists,
mutter never withdraws the capability and GTK keeps its device. Open gesture points then heal by
themselves as before the suspend (same device, same sequence). No change to GTK or mutter.
`touch-right-click` ignores the anchor (it only grabs whitelisted devices).

The service runs before the display manager (`Before=display-manager.service`) so GTK apps have the
same touch device from the start, and it is sandboxed (only `/dev/uinput`, no network, strict
filesystem protection, empty capability set).

## Usage

```bash
./install.sh run touch-anchor          # = modules/touch-anchor/apply.sh
```

Builds `touch-anchor.c` (installs `gcc libevdev-devel pkgconf-pkg-config` if missing), installs
`/usr/local/bin/touch-anchor` and `/etc/systemd/system/touch-anchor.service`, enables and restarts
the service. Apps that already went through a suspend before the service was active must be
restarted once (or log out and in).

Test: suspend, resume, drag a GTK window by touch.

## When to re-run

Only after changing `touch-anchor.c`. Not affected by kernel, mutter or GTK updates.

## Undo

```bash
modules/touch-anchor/apply.sh --remove
```
