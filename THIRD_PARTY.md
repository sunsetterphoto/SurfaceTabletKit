# Third-party components

SurfaceTabletKit's own code (scripts, patches, the panel-portrait extension, touch-anchor,
the measurement tool, the Plymouth artwork, the gjsosk Tux and Caps-Lock icons, the
EasyEffects preset) is licensed under the GNU GPL v3.0, see [LICENSE](LICENSE).

The repository also ships third-party software so the kit works offline. Each item keeps its
own license; the full license texts are in [licenses/](licenses/).

| Component | Version | License | In this repo | Upstream |
|---|---|---|---|---|
| MacTahoe GTK/Shell theme (Dark) | commit `1e45e19` (2026-09-28), built with `./install.sh -c dark -o normal -l -b` | MIT | `vendor/themes-MacTahoe-Dark.tar.gz`, `vendor/gtk-4.0-MacTahoe-libadwaita.tar.gz` (installed output; the Shell CSS contains the kit's override block, re-applied idempotently by `modules/design/css/apply-shell-overrides.sh`) | https://github.com/vinceliuice/MacTahoe-gtk-theme |
| Colloid icon theme (Colloid, Colloid-Dark) | commit `ceac660` (2026-08-29), default `./install.sh` | GPL-3.0 | `vendor/icons-Colloid-Dark.tar.gz` (installed SVGs) | https://github.com/vinceliuice/Colloid-icon-theme |
| WhiteSur cursors | commit `e190baf` (2025-04-05) | GPL-3.0 | `vendor/WhiteSur-cursors-e190baf-source.tar.gz` (complete upstream source) | https://github.com/vinceliuice/WhiteSur-cursors |
| WhiteSur GTK theme (login screen only) | latest, downloaded by `modules/gdm-theme` | MIT | not included | https://github.com/vinceliuice/WhiteSur-gtk-theme |
| Dash to Dock | 110 | GPL-2.0 | `vendor/extensions.tar.gz` | https://github.com/micheleg/dash-to-dock |
| Blur my Shell | 75 | GPL-3.0 | `vendor/extensions.tar.gz` | https://github.com/aunetx/blur-my-shell |
| Just Perfection | 37 | GPL-3.0 | `vendor/extensions.tar.gz` | https://gitlab.gnome.org/jrahmatzadeh/just-perfection |
| User Themes (gnome-shell-extensions) | 80 | GPL-2.0 | `vendor/extensions.tar.gz` | https://gitlab.gnome.org/GNOME/gnome-shell-extensions |
| Rounded Window Corners Reborn | 18 | GPL-3.0 | `vendor/extensions.tar.gz` | https://github.com/flexagoon/rounded-window-corners |
| Compiz alike Magic Lamp effect | 25 | GPL-3.0 | `vendor/extensions.tar.gz` | https://github.com/hermes83/compiz-alike-magic-lamp-effect |
| Desktop Icons NG (gtk4-ding) | 100.22 | GPL-3.0 | `vendor/extensions.tar.gz` | https://gitlab.com/smedius/desktop-icons-ng |
| GJS OSK | 53 | GPL-3.0 | `vendor/extensions.tar.gz` (unpatched; the kit patches it at install) | https://github.com/Vishram1123/gjs-osk |
| AppIndicator and KStatusNotifierItem Support | 66 | GPL-2.0 | `vendor/extensions.tar.gz` | https://github.com/ubuntu/gnome-shell-extension-appindicator |
| Caffeine | 61 | GPL-2.0 | `vendor/extensions.tar.gz` | https://github.com/eonpatapon/gnome-shell-extension-caffeine |
| HealthPanel | current | GPL-3.0 | `vendor/extensions.tar.gz` (optional module) | https://github.com/sunsetterphoto/HealthPanel |
| Space Bar | latest for the running GNOME | none declared upstream | **not included** - downloaded from extensions.gnome.org at install time | https://github.com/christopher-l/space-bar |
| Screen Rotate | Fedora RPM `gnome-shell-extension-screen-autorotate` | GPL-3.0 | only a patch (`modules/screen-rotate/sensorProxy.patch`) | https://github.com/shyzus/gnome-shell-extension-screen-autorotate |
| gnome-rounded-blur | commit `a4db9e5` (2026-10-13) | GPL-3.0 | `modules/rounded-blur/upstream/` (source) + build fix patch | https://github.com/kancko/gnome-rounded-blur |
| evdev-right-click-emulation | commit `350939b` (2019-03-13) | WTFPL v2 | `modules/touch-right-click/src/` (patched source) | https://github.com/PeterCxy/evdev-right-click-emulation |
| int3472, ov5693, ov7251, surface_gpe kernel drivers | from linux-surface kernel 6.19.8-3 with linux-surface PR #2252 | GPL-2.0 | `modules/sp7p-kernel/` (patched source) | https://github.com/linux-surface/linux-surface |

Installed at runtime from Fedora / Flathub (not included): linux-surface kernel packages,
EasyEffects, Inter font, libcamera, mutter-devel and other build dependencies.
