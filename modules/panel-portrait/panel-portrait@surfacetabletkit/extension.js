// SurfaceTabletKit: top bar in portrait orientation.
// At 200 % a 2736x1824 panel is only 912 px wide in portrait. While the primary monitor
// is in portrait, room is made in steps, and only as far as needed:
//   level 1: tighter spacing (class .surfacetabletkit-portrait on #panel, stylesheet.css)
//   level 2: also hide tray icons (appindicator-*) and the keyboard-layout indicator
//   level 3: also show the clock without the date
// "Fits" is measured the way GNOME's panel allocates: the centre box is centred, left and
// right each get half of the remaining width. Landscape is left unchanged.
import GLib from 'gi://GLib';
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const HIDE_KEYS = ['keyboard'];
const HIDE_PREFIX = 'appindicator-';

export default class PanelPortrait extends Extension {
    enable() {
        this._hidden = new Map();   // container -> notify::visible handler
        this._syncing = false;
        this._idleId = 0;

        const dateMenu = Main.panel.statusArea.dateMenu;
        this._clockDisplay = dateMenu._clockDisplay;
        this._wallClock = dateMenu._clock;
        this._time = new St.Label({style_class: 'clock', visible: false, y_align: Clutter.ActorAlign.CENTER});
        this._clockDisplay.get_parent().insert_child_above(this._time, this._clockDisplay);

        this._signals = [
            [this._wallClock, this._wallClock.connect('notify::clock', () => this._queueSync())],
            [Main.layoutManager, Main.layoutManager.connect('monitors-changed', () => this._queueSync())],
        ];
        for (const box of [Main.panel._leftBox, Main.panel._centerBox, Main.panel._rightBox]) {
            this._signals.push([box, box.connect('child-added', () => this._queueSync())]);
            this._signals.push([box, box.connect('child-removed', () => this._queueSync())]);
        }
        this._sync();
    }

    disable() {
        if (this._idleId)
            GLib.source_remove(this._idleId);
        this._idleId = 0;
        for (const [obj, id] of this._signals)
            obj.disconnect(id);
        this._signals = null;
        this._apply(0);
        this._time.destroy();
        this._time = this._clockDisplay = this._wallClock = null;
        this._hidden = null;
    }

    _queueSync() {
        if (this._idleId || this._syncing)
            return;
        this._idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._idleId = 0;
            this._sync();
            return GLib.SOURCE_REMOVE;
        });
    }

    _isPortrait() {
        const m = Main.layoutManager.primaryMonitor;
        return !!m && m.height > m.width;
    }

    _fits() {
        const m = Main.layoutManager.primaryMonitor;
        const node = Main.panel.get_theme_node();
        const avail = m.width - node.get_horizontal_padding();
        const nat = box => box.get_preferred_width(-1)[1];
        const side = (avail - nat(Main.panel._centerBox)) / 2;
        return nat(Main.panel._leftBox) <= side && nat(Main.panel._rightBox) <= side;
    }

    _sync() {
        this._syncing = true;
        try {
            if (!this._isPortrait()) {
                this._apply(0);
                return;
            }
            // start at the mildest level and go only as far as needed
            for (const level of [1, 2, 3]) {
                this._apply(level);
                if (this._fits())
                    break;
            }
        } finally {
            this._syncing = false;
        }
    }

    _targets() {
        return Object.entries(Main.panel.statusArea)
            .filter(([key, ind]) => ind && (HIDE_KEYS.includes(key) || key.startsWith(HIDE_PREFIX)))
            .map(([, ind]) => ind.container);
    }

    _apply(level) {
        // level 1: spacing
        if (level >= 1)
            Main.panel.add_style_class_name('surfacetabletkit-portrait');
        else
            Main.panel.remove_style_class_name('surfacetabletkit-portrait');

        // level 2: tray icons and keyboard layout
        if (level >= 2) {
            for (const c of this._targets()) {
                if (this._hidden.has(c))
                    continue;
                // other extensions show their icons again by themselves -> hide again
                const id = c.connect('notify::visible', () => { if (c.visible) c.hide(); });
                this._hidden.set(c, id);
                c.hide();
            }
        } else {
            for (const [c, id] of this._hidden) {
                c.disconnect(id);
                c.show();
            }
            this._hidden.clear();
        }

        // level 3: clock without date
        if (level >= 3) {
            this._time.text = GLib.DateTime.new_now_local().format('%H:%M');
            this._clockDisplay.hide();
            this._time.show();
        } else {
            this._time.hide();
            this._clockDisplay.show();
        }
    }
}
