#include "uinput.h"
#include <stddef.h>

struct libevdev_uinput *uinput_initialize() {
    // Create a evdev first to describe the features
    struct libevdev *evdev = libevdev_new();
    libevdev_set_name(evdev, "Simulated Right Button");
    libevdev_enable_event_type(evdev, EV_KEY);
    // BTN_LEFT (== BTN_MOUSE) must be present: systemd's input_id builtin
    // only tags a device carrying absolute axes as ID_INPUT_MOUSE
    // ("absolute mouse") when BTN_MOUSE is set and BTN_STYLUS /
    // BTN_TOOL_FINGER are not. Without that tag libinput would classify
    // this device as a touchscreen and drop it.
    libevdev_enable_event_code(evdev, EV_KEY, BTN_LEFT, NULL);
    libevdev_enable_event_code(evdev, EV_KEY, BTN_RIGHT, NULL);
    libevdev_enable_event_code(evdev, EV_KEY, BTN_MIDDLE, NULL);
    // Absolute axes, so that the click can carry the position of the finger.
    // Upstream sends a bare BTN_RIGHT; under Wayland touch does not move the
    // pointer, so the menu would open wherever the pointer was left behind.
    // Reporting an absolute position warps the pointer onto the finger first.
    struct input_absinfo absinfo = {
        .value = 0,
        .minimum = 0,
        .maximum = UINPUT_ABS_MAX,
        .fuzz = 0,
        .flat = 0,
        .resolution = 0,
    };
    libevdev_enable_event_type(evdev, EV_ABS);
    libevdev_enable_event_code(evdev, EV_ABS, ABS_X, &absinfo);
    libevdev_enable_event_code(evdev, EV_ABS, ABS_Y, &absinfo);
    // Initialize uinput device from the evdev descriptor
    struct libevdev_uinput *uinput = NULL;
    if (libevdev_uinput_create_from_device(evdev,
            LIBEVDEV_UINPUT_OPEN_MANAGED, &uinput) != 0) {
        uinput = NULL;
    }
    // We don't need the fake evdev anymore.
    libevdev_free(evdev);
    return uinput;
}

void uinput_send_right_click(struct libevdev_uinput *uinput, int x, int y) {
    // Move first, click second -- in one report each, so the compositor has
    // the new pointer position before it routes the button press.
    libevdev_uinput_write_event(uinput, EV_ABS, ABS_X, x);
    libevdev_uinput_write_event(uinput, EV_ABS, ABS_Y, y);
    libevdev_uinput_write_event(uinput, EV_SYN, SYN_REPORT, 0);
    libevdev_uinput_write_event(uinput, EV_KEY, BTN_RIGHT, 1);
    libevdev_uinput_write_event(uinput, EV_SYN, SYN_REPORT, 0);
    libevdev_uinput_write_event(uinput, EV_KEY, BTN_RIGHT, 0);
    libevdev_uinput_write_event(uinput, EV_SYN, SYN_REPORT, 0);
}
