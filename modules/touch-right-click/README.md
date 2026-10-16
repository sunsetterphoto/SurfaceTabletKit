# touch-right-click - long press on the touchscreen = right click

Builds and installs a patched
[evdev-right-click-emulation](https://github.com/PeterCxy/evdev-right-click-emulation)
(`evdev-rce`) as a system service. It reads the touchscreen directly at the **evdev level** - below
libinput and the compositor - and injects a real right click through `uinput`, at the finger's
position. It therefore works in every app under Wayland (GNOME Shell, GTK, Firefox, Electron).

Usage: hold a finger still for one second, **then lift** - the context menu opens under the finger.

## Why

GNOME/Wayland has **no system-wide "long press = right click"**. Neither mutter nor libinput
implement it; each app has to do it itself, and there are three independent implementations in
three layers:

| Layer | Implementation | Consequence |
|---|---|---|
| GTK | `Gtk.GestureLongPress`, `gtk-long-press-time` = 500 ms | only where a widget wires it up |
| GNOME Shell | its own JavaScript, for individual elements only | dock yes, top bar mostly no |
| mutter / libinput | nothing | no system-wide gesture, no setting |

On a tablet GNOME only "supports" the pen's side button, `Shift+F10` or a keyboard's menu key.

Rejected: the extension "Right-click For Touch Screen" (X11 only; Wayland does not allow
synthesising input through AT-SPI) and `org.gnome.desktop.a11y.mouse secondary-click-enabled`
(applies only to pointer devices).

## Three own patches

Upstream state: commit `350939b` (2019). There is no Fedora package. The first two problems are
fixed in **no** published variant: the forks `pfpacket/...` and `bareboat-necessities/...` also
still send a bare `BTN_RIGHT` without axes. The patched sources are in `src/`, the complete
difference to upstream is `wayland-position-and-release.patch`.

### 1. Position - without it the tool is useless under Wayland

Upstream sends `BTN_RIGHT` without coordinates. Under Wayland touch does not move the pointer, so
the menu opens at the **old cursor position** (upstream issue #9, open).

The virtual uinput device is therefore an **absolute pointer**:

- `ABS_X`/`ABS_Y` (0..32767) plus `BTN_LEFT`/`BTN_MIDDLE` in addition to `BTN_RIGHT`.
  **`BTN_LEFT` (== `BTN_MOUSE`) is mandatory:** systemd's `input_id` builtin tags a device with
  absolute axes as `ID_INPUT_MOUSE` ("absolute mouse") only when `BTN_MOUSE` is set and
  `BTN_STYLUS`/`BTN_TOOL_FINGER` are not. Without that tag libinput classifies the device as a
  touchscreen and drops it.
- `input.c` remembers each source device's coordinate range and maps the finger position to
  0..32767.

Verified with `libinput debug-events`: an injection at 8192/4096 of 32767 gives
`POINTER_MOTION_ABSOLUTE 25.00/12.50` plus `BTN_RIGHT pressed/released`. The device carries
`ID_INPUT_MOUSE=1` and shows as `Capabilities: pointer` in libinput.

### 2. Click on release, not while the finger is down

Symptom: the click worked in the dock and in Files, but **never on the desktop** - although the log
showed eight clicks sent with a drift of 3-13 units (threshold 100). The click was sent and did not
arrive.

Root cause, from gtk4-ding (`app/desktopManager.js`):

```js
async onReleaseButton(X, Y, x, y, button, ...) {
    if (button === 3)                 // the menu opens only on release
        await this.desktopMenuManager.showDesktopMenu(x, y, grid);
}
onLongPressButton(_X, _Y, _x, _y, button, ...) {
    if (button === 3)                 // a touch delivers button 0
        this.mainApp.activate_action('displayShellBackgroundMenu', null);
}
```

1. **On the empty desktop there is no native touch gesture.** `onLongPressButton` requires button
   3; touch delivers 0. Only a real right click can open the menu there.
2. **A click injected while the finger is still down is a second, concurrent input sequence.**
   ding's `GestureClick` is set to `set_exclusive(true)` on one point (`app/desktopGrid.js:1416 ff.`)
   and was occupied by the running touch sequence - the pointer sequence was discarded.

So the click is sent only when the finger is lifted (`CLICK_ON_RELEASE=1`). Then no touch sequence
is open anymore, and the finger is no longer on the menu that is about to appear. The drift is
checked a second time on release: moving on after the long press was recognised means dragging,
not clicking. `CLICK_ON_RELEASE=0` restores the upstream behaviour (click right after the hold
time).

### 3. Self-healing and logging

- Exits cleanly on `-ENODEV` instead of spinning in an error loop when an input device disappears;
  `Restart=always` then re-reads the devices. This happened twice in real use and recovered both
  times.
- Every long press is logged to the journal with position and drift, which separates "no menu
  appeared" from "no click sent":

```
right click sent at 26360/31547 of 32767 (raw 7723,6932)
long press recognized at 2448,4366 (drift 5/0), waiting for lift
long press discarded: drift 50/1021 exceeds fuzz 100
```

## Device configuration

The touchscreen name and the units per mm come from the device profile (`devices/*.conf`:
`TOUCH_DEVICE_WHITELIST`, `TOUCH_UNITS_PER_MM`) or from the environment. Without them the module
stops and explains how to measure. The allowed drift (`LONG_CLICK_FUZZ`) is computed as about
**2.7 mm** in device units (`TOUCH_UNITS_PER_MM * 27 / 10`).

### Surface Pro 7+ (measured)

The touch stack runs through iptsd (`iptsd@dev-hidraw1.service`, iptsd 3.1.0), which creates
virtual input devices. Without a filter evdev-rce would find five matching devices:

| Device | Whitelisted |
|---|---|
| IPTSD Virtual Touchscreen 045E:0C1A (259x171 mm, 17 contacts, x 0..9600, y 0..7200) | **yes** |
| Intel Touch Host Controller (293x165 mm, 1 contact) | no |
| Microsoft Surface Type Cover Touchpad | no |
| IPTSD Virtual Stylus / Intel Touch Host Controller Stylus | no |

Measured (`libinput debug-events`, 240 s, 51 touches): finger events come **only** from the IPTSD
Virtual Touchscreen. The raw HID node (Intel Touch Host Controller) delivered not a single
`TOUCH_DOWN` and occasionally disappears briefly - leaving it out also avoids needless service
restarts. Touchpad and stylus are excluded on purpose: a finger resting on the touchpad would
otherwise trigger a right click after one second, and the pen already has its side button.

Profile values: `TOUCH_DEVICE_WHITELIST="IPTSD Virtual Touchscreen 045E:0C1A"`,
`TOUCH_UNITS_PER_MM=37` -> `LONG_CLICK_FUZZ=99` (~2.7 mm). The hold drift measured 3-13 units, so
the tolerance was never the problem.

### Other devices (e.g. Surface Go 2)

Measure first:

```bash
sudo libinput list-devices      # device with "Capabilities: touch": name and size in mm
sudo libinput debug-events      # check that finger events really come from that device
sudo evtest                     # ABS_MT_POSITION_X range / width in mm = units per mm
TOUCH_DEVICE_WHITELIST="<name>" TOUCH_UNITS_PER_MM=<n> modules/touch-right-click/apply.sh
```

Then add both values to `devices/<device>.conf`.

## Usage

```bash
./install.sh run touch-right-click      # = modules/touch-right-click/apply.sh
```

Builds `src/` in a temp directory (installs `gcc make libevdev-devel` if missing) and installs:

- `/usr/local/bin/evdev-rce`
- `/etc/systemd/system/evdev-rce.service` (root, sandboxed: only `/dev/uinput` and input devices,
  no network; `StartLimitIntervalSec=0` because at boot it may restart several times until iptsd
  has created the touchscreen)
- `/etc/sysconfig/evdev-rce` from `evdev-rce.sysconfig.in`. An existing, different file is
  **never overwritten**; the new version is written next to it as `evdev-rce.new`.

```bash
systemctl status evdev-rce
sudo systemctl restart evdev-rce          # after editing /etc/sysconfig/evdev-rce
sudo journalctl -u evdev-rce -f -o cat    # watch long presses live
```

## Deliberate decisions (do not "fix")

- **`LONG_CLICK_INTERVAL=1000` is longer than GTK's 500 ms on purpose.** Where an app has its own
  long-press gesture, its menu comes first; lifting then gives exactly one menu. Shorter values
  make both collide.
- **`LONG_CLICK_FUZZ` is in device units, not pixels.**
- **Firefox' `ui.click_hold_context_menus` is not set:** with the service Firefox gets a real
  `BTN_RIGHT`, the pref is unnecessary.
- **`apply.sh` uses `restart`, not `enable --now`:** `--now` does not restart a running service, so a
  freshly built binary would silently not be used.

## Side effect: no touch mode in mutter

The virtual absolute pointer counts as a pointer device. Without a cover there is no tablet-mode
switch on the Surface Pro 7+, so mutter uses `touch_mode = !has_pointer` (`meta-seat-impl.c`) - and
with this device present, mutter never enters touch mode when the cover is detached.

- mutter does not auto-rotate by itself; rotation is handled by the `screen-rotate` module.
- A possible effect on GNOME's built-in on-screen keyboard does not matter: gjsosk switches it off
  anyway (`screen-keyboard-enabled=false`, confirmed on the system) - see the `osk` module.

## Known limits

- An open context menu could not be closed by tapping next to it with a finger (only with a
  touchpad click). Not resolved: mutter's `popup_grab_release` (`src/wayland/meta-wayland-popup.c`)
  is also called on `CLUTTER_TOUCH_END` according to `meta-wayland-input.c:238`, so a tap should
  suffice. Whether click-on-release changed this was not checked.
- gjsosk and the dock collide at the bottom edge: gjsosk registers a bottom edge swipe on the whole
  stage in the capture phase (`global.stage.add_action_full('osk', Clutter.EventPhase.CAPTURE, ...)`,
  `extension.js:709`; edge from `default-snap=7` -> `St.Side.BOTTOM`), and the dock is at the bottom.
  A long press on a dock icon that drifts slightly upwards counts as a swipe and opens the keyboard.
  `disable-edge-swipe=true` would avoid it but costs the swipe gesture - left unchanged on purpose.
- If a menu does not appear, check the journal: `right click sent` means the service did its part.

## When to re-run

After changing `src/` or the device values. Not affected by kernel or GNOME updates. The service
re-reads the devices on every restart.

## Undo

```bash
sudo systemctl disable --now evdev-rce.service
sudo rm /etc/systemd/system/evdev-rce.service /etc/sysconfig/evdev-rce /usr/local/bin/evdev-rce
sudo systemctl daemon-reload
```

## License

evdev-right-click-emulation is licensed under the **WTFPL v2** (`src/LICENSE`, also
`licenses/evdev-right-click-emulation.LICENSE`) - not MIT. `src/UPSTREAM` records the upstream
commit; the kit's changes are `wayland-position-and-release.patch`. Contributing patches 1 and 2
upstream would be worthwhile, as they are missing in upstream and all known forks.
