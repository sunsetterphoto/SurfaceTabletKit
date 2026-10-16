# sp7p-kernel - cameras and wake on lid open (Surface Pro 7+ only)

Out-of-tree kernel modules for the **Surface Pro 7+**, built for the running linux-surface kernel
and signed with a Machine Owner Key (MOK) generated on the device:

| Part | Modules | Result |
|---|---|---|
| `cameras` | `intel_skl_int3472_discrete`, `intel_skl_int3472_common` (power rails), `ov5693` (front), `ov7251` (IR) | front and rear camera work through libcamera / PipeWire |
| `gpe` | `surface_gpe` with a Surface Pro 7+ DMI entry | the device wakes up when the lid (Type Cover) is opened |

The script refuses to run on any other device (DMI product name must be `Surface Pro 7+`) and on a
kernel that is not a linux-surface kernel.

## Usage

```bash
./install.sh run sp7p-kernel                  # = modules/sp7p-kernel/apply.sh all
modules/sp7p-kernel/apply.sh cameras|gpe|all [--force]
```

1. Installs the build dependencies (`gcc make elfutils-libelf-devel xz openssl mokutil` and
   `kernel-surface-devel` for the running kernel).
2. Creates the signing key if needed and checks its enrollment (see "Signing key" below). On the
   first run under Secure Boot it starts the enrollment and stops: reboot, enroll the key, run the
   module again.
3. Builds each driver in a temp copy (the repository stays free of build artefacts), signs it,
   compresses it with `xz --check=crc32` (the kernel's xz decoder supports only CRC32) and installs
   it over the stock module in `/lib/modules/$(uname -r)/...`. The stock module is kept once as
   `<module>.ko.xz.orig`.
4. Runs `depmod -a`. **Reboot** afterwards to load the new drivers cleanly, then run `./verify.sh`.

`./verify.sh` shows whether the patched modules are active: their signer must be
`SurfaceTabletKit module signing key` (or `Int3472 Camera Fix`, the name of an earlier key), and
`cam -l` must list at least 2 cameras.

### Kernel version check and automatic skip

- The driver sources were verified on kernel **6.19.8-3.surface.fc43.x86_64**. On any other kernel
  the script refuses unless `--force` is given. Before forcing, check whether linux-surface already
  ships the fixes.
- `cameras` is skipped automatically when the **stock** `ov5693` already contains the
  `binned_y_offset` parameter, i.e. linux-surface PR #2252 is merged into that kernel.
- `gpe` is skipped automatically when the stock `surface_gpe` already contains
  `"Surface Pro 7+"`.

### When to re-run

After **every kernel update**: a new kernel brings its own unpatched modules. Run the module again
for the new kernel, reboot, `./verify.sh`. Once both automatic skips apply, the module is no longer
needed.

## Signing key (lib/mok.sh)

- Every device gets its **own** key pair. It is generated locally with `openssl` (RSA 2048,
  SHA-256, CN `SurfaceTabletKit module signing key`) and stays root-only in
  `/var/lib/surfacetabletkit/mok` (`MOK.priv`, `MOK.der`). It is never part of the repository.
- Under Secure Boot the public half must be enrolled once: `mokutil --import` asks for a one-time
  password; on the next boot the blue MokManager screen asks to confirm it
  (Enroll MOK -> Continue -> Yes -> password -> Reboot). With Secure Boot off, signatures are not
  enforced, but the modules are signed anyway.
- An existing, already enrolled key can be used instead:
  `MOK_KEY=/path/MOK.priv MOK_CRT=/path/MOK.der modules/sp7p-kernel/apply.sh all`
- The kernel does not check X.509 validity dates for module signing keys (the checks were removed
  upstream in 2013; in 6.19 `crypto/asymmetric_keys/x509_public_key.c` only prints them). The key
  is created with a 100-year lifetime anyway.

## Cameras

### Origin

The camera changes come from **linux-surface PR #2252** by dmanresa-saes (branch
`surface-pro7plus-cameras`, commit `e4b4d24`), verified by its author on a Surface Pro 7+ with
exactly `6.19.8-surface-3`. The sources here are vanilla v6.19.8 + linux-surface
`0013-cameras.patch` + the PR commits:

- `int3472/upstream/discrete.c`, `int3472/upstream/int3472.h` - vanilla
- `int3472/0001-int3472-surface-pr2252.patch` - the difference
- `int3472/upstream/linux-surface-pr2252-0013-cameras.patch` - the complete patch set for reference
- `ipu6-sensors/upstream/*.c` - vanilla; `ipu6-sensors/*-surface-pr2252.patch` - the difference

`ipu_bridge` and `intel_ipu6_isys` deliberately stay the stock modules.

### int3472 - power rails

| Sensor | ACPI GPIO type | Upstream | With the patch |
|---|---|---|---|
| OV7251 IR (INT347E) | 0x0B power-enable | regulator `avdd`, but ov7251 asks for `vdda` -> dummy regulator, sensor unpowered, probe fails with `-121` | `vdda` |
| OV8865 rear (INT347A) | 0x08 (vendor specific) | `pwr1`, which no driver consumes; with only the 0x0B rail (`avdd`) powered the first I2C write fails with `-121` | power-enable `dvdd` (module parameter `ov8865_pwr1_con_id`) |
| OV5693 / OV8865 | 0x0D | privacy LED | stays privacy LED |

**Header length (important).** The patch set uses the supply name `dovdd`, which needs 6 bytes
including the terminating NUL. The stock `include/linux/platform_data/x86/int3472.h` defines
`GPIO_SUPPLY_NAME_LENGTH 5`. Built against the stock header, probing fails with
`supply-name 'dovdd' length too long` -> INT3472:00/:01 probe `-E2BIG` -> **front and rear camera
are not created at all**. This happened once after a kernel update when the header had been edited
in place in `/usr/src/kernels/...` and the fresh kernel-devel brought the 5 back. Therefore
`apply.sh` now generates a **local copy** of the header with length 6 (`sed` 5 -> 6, and it aborts
if the replacement did not take) and builds against it via `NOSTDINC_FLAGS` in
`int3472/Makefile`. kernel-devel itself is never modified.

Live reload works for INT3472:00/:01, but **not** for the IR device INT3472:02
(`INT3472 seems to have no dependents` - the ACPI `_DEP` is consumed after the first probe), so a
reboot is needed.

### ov5693 (front) and ov7251 (IR)

| Module | What the patch does |
|---|---|
| `ov5693` | The binned mode 1296x972 streams on IPU6 (before: "Frame sync error" / FIFO overflow). Sets `MIPI_CTRL00 (0x4800) = 0x2d` at stream start - **without it not a single frame arrives**. Parameter `binned_y_offset` (default 2 = BGGR, matches libcamera's SoftISP; 3 = PSYS/GRBG). |
| `ov7251` | Drives the IR illuminator through the sensor's strobe output (`0x3005=0x08`, `0x3b81=0xff`), only while streaming. Without it the IR camera sees only black. Parameter `ir_led` (-1 = auto, on for INT347E). |

The module also installs `libcamera` and `pipewire-plugin-libcamera`.

### Measured on 6.19.8-3 (libcamera 0.5.2)

- Front (OV5693): `cam -c <front> --capture=60` -> 60 frames, ~29 fps, correctly oriented, natural
  colours.
- Rear (OV8865): 30 fps. **No autofocus** - libcamera's SoftISP has no AF, the focus is fixed.
- The libcamera tuning files of the companion repository (`surface-ipu6-cameras/config/tuning`) are
  written for a newer libcamera: 0.5.2 aborts with `Algorithm 'Adjust' not found`. A reduced ov8865
  file for 0.5.2 (only `blackLevel: 1024`) only made the image darker, so **no tuning file is
  installed**; the default `uncalibrated.yaml` gives neutral colours here.

### IR sensor (OV7251) is hidden from PipeWire

The IR camera is **not usable as a camera**: libcamera offers only raw Y10 640x480 for it, the image
is rotated by 90 degrees (mounting position), and stream starts are unreliable (IPU6 D-PHY errors,
`csi2-5 error: DPHY fatal error / SOT sync error`). Opening it also lights the IR illuminator.
libcamera nevertheless reports it as a third camera "ov7251".

`ipu6-sensors/wireplumber/50-surface-hide-ir-camera.conf` is installed to
`/etc/wireplumber/wireplumber.conf.d/` and disables that device. It matches
`api.libcamera.path ~ ".*CAM3$"` (the ACPI path of INT347E, `\_SB_.PC00.I2C3.CAM3`); matching on
`device.product.name` does not work because that property is set only after the rules ran (tested).
The sensor stays bound, which does no harm.

## Wake on lid open (surface_gpe)

### Problem

Closing the lid suspends correctly (s2idle, Modern Standby), but opening it did **not** wake the
device. The Type Cover keyboard backlight turned on, so the Surface Aggregator Module saw the lid
event, but the system stayed in s2idle until the power button was pressed.

### Root cause

```
$ dmesg | grep surface_gpe
surface_gpe: no compatible Microsoft Surface device found, exiting
```

`surface_gpe` registers the ACPI General Purpose Event that wakes the system from s2idle on lid
open. It matches supported models with a hard-coded DMI table that includes Pro 4/5/6/7/8/9 but
**not the Pro 7+** (product name `Surface Pro 7+`, SKU `Surface_Pro_7+_1960`). Without a DMI match
the module exits early and no GPE is registered.

### Fix

`surface-gpe-sp7p/0001-surface-gpe-add-surface-pro-7-plus.patch` adds a DMI entry for
`Surface Pro 7+` with GPE **0x4B** (`lid_device_props_l4B`), the value the Pro 8 uses - both are
Tiger Lake. The patch also adapts `surface_gpe_remove` to the `void` return type of current
kernels.

Measured on the Surface Pro 7+: lid open -> `PM: suspend exit` 7 ms later, and
`/sys/firmware/acpi/interrupts/gpe4B` counted up (0 -> 2 over a lid and a power-button cycle) -
the patched module serves the wake path. If wake still fails on another firmware, the Pro 7 value
`0x4D` (`lid_device_props_l4D`) is the alternative; decode the DSDT (`iasl -d dsdt.dat`) to find the
lid's `_GPE` reference.

Check:

```bash
lsmod | grep surface_gpe
sudo dmesg | grep surface_gpe        # must NOT say "no compatible ... exiting"
cat /sys/firmware/acpi/interrupts/gpe4B
```

## Undo

```bash
# for each module that has a .orig next to it, e.g.:
d=/lib/modules/$(uname -r)/kernel/drivers/platform/surface
sudo cp $d/surface_gpe.ko.xz.orig $d/surface_gpe.ko.xz
# (likewise in drivers/platform/x86/intel/int3472 and drivers/media/i2c)
sudo depmod -a
sudo rm /etc/wireplumber/wireplumber.conf.d/50-surface-hide-ir-camera.conf
```

Reboot afterwards. Installing a new kernel also brings back the stock modules. To remove the
enrolled key: `sudo mokutil --delete /var/lib/surfacetabletkit/mok/MOK.der` (confirmed in
MokManager at the next boot).

## License

All kernel sources in this module (`int3472/`, `ipu6-sensors/`, `surface-gpe-sp7p/`) are
GPL-2.0, like the Linux kernel (`licenses/GPL-2.0.txt`). The camera changes originate from
linux-surface PR #2252 by dmanresa-saes.
