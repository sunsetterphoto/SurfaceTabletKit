# osk - on-screen keyboard (gjsosk) for a tablet

Three small patches to the gjsosk extension (Vishram1123/gjs-osk, installed by the `design`
module), each in its own sub-folder:

| Sub-folder | What it does |
|---|---|
| `glass/` | real glass blur behind the keyboard panel (via blur-my-shell) |
| `labels/` | PC labels for Ctrl/Alt/AltGr instead of macOS glyphs; Tux as Super, A-with-padlock as Caps Lock |
| `autoshow/` | the keyboard opens automatically only when no hardware keyboard is attached |

All three edit `~/.local/share/gnome-shell/extensions/gjsosk@vishram1123.com/extension.js` and are
idempotent. They find their insertion points by unique anchor strings and refuse to patch
("Anchor not unique") when a gjsosk update changed them - then the patch has to be checked by
hand. Before the first change the original is saved as `extension.js.orig-v<version>`.

## Usage

```bash
./install.sh run osk     # = glass/apply.sh && labels/apply.sh && autoshow/apply.sh
```

Then log out and back in (GNOME loads extension code only at login on Wayland) and run
`./verify.sh`, which checks that all three patches are present and that the custom layout
(`layout-landscape=10`) is selected.

## When to re-run

After **every gjsosk update** (the update replaces `extension.js`), in this order: `glass`,
`labels`, `autoshow` - `./install.sh run osk` does exactly that. Then log out and in.

## glass - blur behind the keyboard

gjsosk draws its keyboard panel (`this.box`, name `osk-gjs`) with a plain background colour from
dconf (`background-*-dark`). When that colour is translucent there is **no blur** behind it:
wallpaper and dock show through sharply (checked with a screenshot at `background-a-dark=0`).

blur-my-shell (v74) does blur on-screen keyboards, but recognises them only by the CSS class
`bms-keyboard-surface`, which it sets itself only on GNOME's built-in keyboard
(`Main.layoutManager.keyboardBox`). gjsosk adds its `Keyboard` (a GNOME `Dialog`) to
`Main.uiGroup`; blur-my-shell watches that group and also searches the children of new elements
for blur targets.

Patch: one line in `Keyboard._init`, right after `this.box.clear_actions();`:

```js
this.box.add_style_class_name('bms-keyboard-surface');
```

Related settings (from the `design` module): gjsosk background `rgba(28, 28, 32, 0.75)`, font
18 px, 12 px distance to the screen edge; blur-my-shell `popup/osk-corner-radius=28`; the 28 px
panel radius (`#osk-gjs`) and the translucent keys come from `css/mactahoe-shell-overrides.css`.

Undo: `modules/osk/glass/apply.sh --restore` copies `extension.js.orig-v<version>` back - this also
drops the other two patches, since they share that original.

## labels - PC modifier labels, Tux, Caps Lock icon

With `show-icons=true` gjsosk (v53) draws icons instead of text for Ctrl, Alt, AltGr, Caps Lock and
Super: Ctrl becomes the chevron `⌃`, both Alt keys the macOS option sign `⌥`. On a PC layout that
means nothing. The keycode tables also call both Alt keys just "Alt", although the right one
(code 100) is AltGr on layouts like `de` and switches gjsosk to the third level (@ € { } [ ] \ | ~).
`show-icons=false` does not help: then Backspace, Tab, Enter and Shift become English text too, and
both Alt keys still have the same label.

Patch: two lines in `doAddKey`, before the unique comment `// [insert handwriting 8]`:

1. `ctrl` and `alt` are removed from the icon list.
2. The layers of these keys get fixed texts: codes 29/97 Ctrl, 56 Alt, 100 AltGr - on every layer,
   because `updateKeyLabels()` re-reads the label from `layers` on every mode change. With German
   as the first input source the labels are `Strg` and `Alt Gr`, otherwise `Ctrl` and `AltGr`.
   Arrows, Space, Backspace, Tab, Enter and Shift keep their icons.

Icons: `ui/icons/hicolor/scalable/actions/super.svg` / `super-dark.svg` are replaced by a Tux and
`capslock.svg` / `capslock-dark.svg` by a framed A with a padlock (`labels/icons/`, own drawings in
the style of the gjsosk icons, viewBox 24). Originals are kept as `*.svg.orig-v<version>`. The icon
files take effect at the next rebuild of the keyboard, without logging out.

Super is a latching key in gjsosk: Tux + key works directly; Tux alone (overview) needs two taps,
latch first, then release.

Undo: `modules/osk/labels/apply.sh --remove` removes only these two lines and restores the original
icons; the glass patch stays.

### Layout

The custom layout (gjsosk `custom-layout`, index 10, in `modules/design/config/gjsosk.conf`) follows
the Surface Type Cover without Fn: Caps Lock (width 1.5) in front of A, an ISO `<>` key, and a
bottom row Ctrl 1.5 - Super 1 - Alt 1.5 - Space 5.5 - AltGr 1.5 - Esc 1 - left, up/down,
right. Esc sits at the bottom right because the function row (where the Surface has Esc) is left
out on purpose.

## autoshow - auto-open only without a hardware keyboard

Default gjsosk behaviour with `enable-tap-gesture=1` ("touch only"): tapping a text field with a
finger opens the keyboard, even with the Type Cover attached. With a cover there is no need for it
to open; without one the automatic opening is essential.

Patch: a helper function before `export default class GjsOskExtension` that returns true when a
physical Clutter device of type `KEYBOARD_DEVICE` with "keyboard" (and not "virtual") in its name
exists. The two places that decide about automatic opening
(`this.lastInputMethod = ...` in the tap handler and `let lastInputMethod = ...` in
`maybeHandleEvent`) are guarded with it.

Measured on a Surface Pro 7+: with the cover attached "Microsoft Surface Type Cover Keyboard"
appears; without it only "Video Bus" and "gpio-keys" remain, which do not match. USB and Bluetooth
keyboards count as hardware keyboards too. The top-bar button and the swipe gesture work as
before, so the keyboard can still be toggled with a cover attached.

Undo: `modules/osk/autoshow/apply.sh --remove` takes back only this patch (tested on a copy: the
file is restored byte for byte).

## License

gjsosk (gjs-osk) is GPL-3.0 (`licenses/gjs-osk.LICENSE`); these scripts patch the installed copy.
