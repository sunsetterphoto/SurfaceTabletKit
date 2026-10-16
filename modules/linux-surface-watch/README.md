# linux-surface-watch - is linux-surface ready for the next Fedora? (optional)

A daily systemd user timer that checks whether linux-surface already publishes a repository for
the **next** Fedora release (`https://pkg.surfacelinux.com/fedora/f<next>/`). Upgrading Fedora
before that silently drops the Surface kernel: the repository uses `f$releasever` with
`skip_if_unavailable=1`, so dnf just skips it.

## How it works

- `check.sh` requests the repository directory of Fedora `$(rpm -E %fedora) + 1`.
- Every run appends one line (time, HTTP code, URL) to
  `~/.local/state/surfacetabletkit/linux-surface-watch.log`.
- On **HTTP 200**: a critical desktop notification (`notify-send`), a marker file
  `~/.local/state/surfacetabletkit/fedora-<next>-available`, and the timer **disables itself**.
- Otherwise it exits quietly.

Installed files (copies, nothing points into the repository):

- `~/.local/libexec/surfacetabletkit/linux-surface-watch` (copy of `check.sh`)
- `~/.config/systemd/user/linux-surface-watch.service` (oneshot)
- `~/.config/systemd/user/linux-surface-watch.timer` (`OnCalendar=daily`, `Persistent=true`,
  `RandomizedDelaySec=1h`)

## Usage

```bash
./install.sh run linux-surface-watch     # = modules/linux-surface-watch/apply.sh
modules/linux-surface-watch/apply.sh --remove
```

`apply.sh` enables the timer and runs one check immediately.

```bash
systemctl --user list-timers linux-surface-watch.timer
systemctl --user start linux-surface-watch.service     # check now
tail ~/.local/state/surfacetabletkit/linux-surface-watch.log
```

## When the repository is online

After upgrading Fedora, re-run the modules that depend on the kernel or on updated system
packages, then check with `./verify.sh`:

- `sp7p-kernel` (Surface Pro 7+): the new kernel brings its own unpatched modules
- `rounded-blur`: built against the installed mutter
- `screen-rotate`: patched copy of the extension RPM
- `gdm-theme` (if used): a `gnome-shell` update restores the stock login screen

```bash
./install.sh run sp7p-kernel rounded-blur screen-rotate
./verify.sh
```

Also watch out: `libwacom-surface` may conflict with the new release's `libwacom` (see
linux-surface issue #2102); if so, upgrade with `--exclude=libwacom-surface`.

After the upgrade, re-run this module to watch for the following release.

## Undo

```bash
modules/linux-surface-watch/apply.sh --remove
```
