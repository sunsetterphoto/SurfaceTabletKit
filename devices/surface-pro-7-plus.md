# Surface Pro 7+ - measured facts

Values the kit relies on, measured on a Surface Pro 7+ with Fedora 43, GNOME 49 and the
linux-surface kernel 6.19.8-3. Profile: [`surface-pro-7-plus.conf`](surface-pro-7-plus.conf).

## Display
- 12.3", 2736x1824, connector `eDP-1`. Scale **200 %** (`<scale>2</scale>` in
  `~/.config/monitors.xml`). In portrait the top bar is 1824/2 = 912 px wide.
- Changing the scale via `org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig` (method 2) takes
  effect immediately but does **not** write `monitors.xml`; set it in Settings -> Displays.

## Touch and pen
- Touch goes through IPTS: `ithc` (Intel Touch Host Controller) + `iptsd`, which creates the
  virtual devices "IPTSD Virtual Touchscreen 045E:0C1A" (0..9600 x 0..7200, ~37 units/mm) and
  "IPTSD Virtual Stylus". Finger events come only from the virtual touchscreen; the raw
  "Intel Touch Host Controller" node delivers none.
- **On every resume `ithc` re-probes the controller, `iptsd` moves from `hidraw0` to `hidraw1`
  and the virtual touchscreen is re-created.** For ~0.15 s no touch device exists. Without
  `touch-anchor` this breaks touch in running GTK apps and crashes them when a window is
  dragged by touch.
- The type cover provides a `SW_TABLET_MODE` switch device that never reports "tablet"; when the
  cover is detached all its input devices disappear instead.

## Sensors and rotation
- Accelerometer via the Intel Sensor Hub (`hid-sensor-hub`, `accel_3d`), served by
  `iio-sensor-proxy`. It sends orientation changes only to D-Bus senders that claimed the
  accelerometer - see `modules/screen-rotate`.
- mutter rotates by itself only in touch mode. With the cover detached there is no tablet
  switch, so `touch_mode = !has_pointer`; any virtual pointer (e.g. evdev-rce's) prevents touch
  mode. The kit therefore relies on the screen-rotate extension.

## Cameras (module `sp7p-kernel`)
- IPU6 with OV5693 (front), OV8865 (rear) and OV7251 (IR). With the patched int3472/ov5693/ov7251
  from linux-surface PR #2252 front (~29 fps) and rear (30 fps, no autofocus with the libcamera
  software ISP) work through libcamera and PipeWire. The IR sensor streams only unreliably and
  is hidden from PipeWire.

## Lid and power
- Wake on lid open needs `surface_gpe` with a Surface Pro 7+ entry (GPE 0x4B); the stock module
  exits with "no compatible Microsoft Surface device found".
- Sleep is s2idle. **Hibernate is impossible while Secure Boot is on** (kernel lockdown
  `integrity`: `/sys/power/disk` is `[disabled]`, `CanHibernate` = `na`).
- Power profiles via `tuned-ppd`; on battery tuned selects `balanced-battery`.

## Audio
- Realtek ALC274, one internal speaker pin (`0x90170110`) feeding both channels; no separate
  woofer channel to unlock. Strong speaker resonance between 3.5 and 6.5 kHz (about +12..+15 dB
  measured with a reference microphone; the built-in microphone shows ~10 dB more), nothing
  usable below ~115 Hz. The preset "SurfacePro7+ v3" in `modules/audio` corrects this.
- The built-in microphone clips on room noise at the default gain (Internal Mic Boost 3,
  Capture 63); `tools/measure-speakers.py` lowers it during a measurement and restores it.
