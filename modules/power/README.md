# power - power profile and sleep

Measures first and changes only what is wrong. Three checks:

1. TLP enabled next to tuned-ppd -> TLP is disabled.
2. Power profile permanently on "performance" -> set to "balanced".
3. A hibernate setup in `/etc/systemd/sleep.conf` that cannot work -> those lines are commented out.

## Usage

```bash
./install.sh run power       # = modules/power/apply.sh
```

Idempotent; reports for each of the three points whether anything had to be done, and prints the
active profile and tuned profile at the end.

## 1. TLP next to tuned-ppd

Fedora uses `tuned-ppd` as the implementation of the PowerProfiles interface that GNOME shows in
quick settings. On the Surface Pro 7+ `tlp.service` was `enabled` but `inactive`, without a
single journal entry in the boot - tuned-ppd did the work. Two power managers side by side are a
known source of conflicts, and an "enabled but dead" service may still start at a later boot. So
TLP is disabled (`systemctl disable --now tlp`). The **package stays installed**: if you
deliberately want TLP, you have to mask tuned-ppd and lose GNOME's profile switch.

## 2. Power profile

Measured before on the Surface Pro 7+:

```
PowerProfiles ActiveProfile   : performance
tuned-adm active              : throughput-performance
scaling_governor              : performance
energy_performance_preference : performance
```

On a passively cooled tablet on battery this costs runtime and produces heat without everyday
benefit. tuned-ppd's mapping is in `/etc/tuned/ppd.conf` and has its own `balanced-battery`
profile for battery operation. After:

```
PowerProfiles ActiveProfile   : balanced
tuned-adm active              : balanced-battery   (automatic on battery)
scaling_governor              : powersave
energy_performance_preference : balance_power
```

The profile can be switched at any time in GNOME's quick settings, e.g. to "Performance" for
exports or rendering.

## 3. Hibernate that cannot work

`sleep.conf` had `AllowHibernation=yes`, `AllowSuspendThenHibernate=yes` and
`HibernateDelaySec=30min`, and the kernel command line had `resume=` and `resume_offset=`. That
looked like a working hibernate chain, but it cannot work under Secure Boot:

```
mokutil --sb-state               : SecureBoot enabled
/sys/kernel/security/lockdown    : none [integrity] confidentiality
dmesg                            : "Kernel is locked down from EFI Secure Boot mode"
/sys/power/state                 : freeze mem          <- no "disk"
/sys/power/disk                  : [disabled]
loginctl CanHibernate            : na
loginctl CanSuspendThenHibernate : na
```

Kernel lockdown forbids hibernation because the memory image would be written to disk unverified.
Independently of that, logind had `HandleLidSwitch=suspend`, so it would never have called
`suspend-then-hibernate` anyway.

The module asks logind (`CanHibernate`). Only if the answer is not `yes` and `sleep.conf` contains
`AllowHibernation`, `AllowSuspendThenHibernate` or `HibernateDelaySec`, those lines are commented
out (backup `/etc/systemd/sleep.conf.bak-<date>`). Where hibernate works, `sleep.conf` is left
alone.

If hibernate is really needed: disable Secure Boot in UEFI. That conflicts with the MOK-signed
modules of `sp7p-kernel` and stores the memory image unprotected - deliberately not done here.

Practical consequence: closing the lid means s2idle (Modern Standby), so the device keeps drawing
power. To lose nothing overnight, shut down.

## When to re-run

After installing or re-enabling TLP, or if the profile was left on "performance". Not needed after
normal updates.

## Undo

```bash
sudo systemctl enable --now tlp                        # TLP back (conflicts with tuned-ppd)
sudo cp /etc/systemd/sleep.conf.bak-<date> /etc/systemd/sleep.conf
powerprofilesctl set performance                       # or use quick settings
```
