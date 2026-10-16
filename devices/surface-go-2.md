# Surface Go 2 - what to measure

The profile [`surface-go-2.conf`](surface-go-2.conf) is prepared but not yet measured on a real
device. Fill in the values below, then the device-specific modules can run. Please contribute
the measured values back (pull request) so the next owner does not have to measure again.

| Value | How to measure | Used by |
|---|---|---|
| `DMI_PRODUCT_NAME` | `cat /sys/class/dmi/id/product_name` (expected "Surface Go 2", taken from the upstream kernel board file) | device detection |
| `RECOMMENDED_SCALE` | panel resolution from `~/.config/monitors.xml` or Settings -> Displays; choose a scale with the user | documentation |
| `TOUCH_DEVICE_WHITELIST` | `sudo libinput list-devices` -> device with "Capabilities: touch"; confirm with `sudo libinput debug-events` that finger events come from it | `touch-right-click` |
| `TOUCH_UNITS_PER_MM` | `sudo evtest` on that device: `ABS_MT_POSITION_X` maximum divided by the width in mm from `libinput list-devices` | `touch-right-click` |
| `NEEDS_TOUCH_ANCHOR` | run `tools/touch-log.sh`, suspend and resume once: if the touchscreen shows DEVICE_REMOVED/ADDED right after "PM: suspend exit", set `yes` and add `touch-anchor` to `RECOMMENDED_MODULES` | `touch-anchor`, `verify.sh` |
| `AUDIO_PRESET` | quit EasyEffects, run `tools/measure-speakers.py`, build a preset from the Surface Pro 7+ template (see `modules/audio/README.md`), check it with `--processed` | `audio` |

Notes:
- The Surface Go 2 uses different camera hardware than the Surface Pro 7+; the `sp7p-kernel`
  module refuses to run on it.
- The GPU is much weaker than the Surface Pro 7+'s. The most expensive part of the look is the
  dynamic blur behind every window (`blur-my-shell` applications, `enable-all=true`). If the
  desktop feels slow, measure first, then switch that to a whitelist.
- gjsosk's keyboard is placed on the built-in panel automatically (`design` step `dconf`).
