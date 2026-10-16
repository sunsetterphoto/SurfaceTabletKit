/*
 * touch-anchor: creates a virtual touchscreen that never sends a single event.
 *
 * Why (measured on a Surface Pro 7+): on every resume ithc re-probes the touch controller
 * and iptsd re-creates its virtual touchscreen. For ~0.15 s no touch device exists, so
 * mutter withdraws WL_SEAT_CAPABILITY_TOUCH (meta-wayland-seat.c,
 * lookup_device_capabilities) and GTK drops its "Wayland Touch Logical Pointer" device and
 * creates a new one. Gestures that still hold the old device then ignore every touch
 * (gtkgesture.c: "wrong device") or crash when a window is dragged (seat == NULL in
 * _gdk_wayland_seat_get_last_implicit_grab_serial). As long as this device exists, the
 * touch capability never goes away.
 */
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <libevdev/libevdev.h>
#include <libevdev/libevdev-uinput.h>

static volatile sig_atomic_t stop;
static void on_signal(int sig) { (void)sig; stop = 1; }

int main(void)
{
    struct libevdev *dev = libevdev_new();
    struct libevdev_uinput *uidev = NULL;
    struct input_absinfo x  = { .minimum = 0, .maximum = 9600, .resolution = 37 };
    struct input_absinfo y  = { .minimum = 0, .maximum = 7200, .resolution = 42 };
    struct input_absinfo sl = { .minimum = 0, .maximum = 1 };
    struct input_absinfo id = { .minimum = 0, .maximum = 65535 };
    int rc;

    libevdev_set_name(dev, "SurfaceTabletKit Touch Anchor");
    libevdev_set_id_bustype(dev, BUS_VIRTUAL);
    libevdev_enable_property(dev, INPUT_PROP_DIRECT);
    libevdev_enable_event_code(dev, EV_KEY, BTN_TOUCH, NULL);
    libevdev_enable_event_code(dev, EV_ABS, ABS_X, &x);
    libevdev_enable_event_code(dev, EV_ABS, ABS_Y, &y);
    libevdev_enable_event_code(dev, EV_ABS, ABS_MT_SLOT, &sl);
    libevdev_enable_event_code(dev, EV_ABS, ABS_MT_POSITION_X, &x);
    libevdev_enable_event_code(dev, EV_ABS, ABS_MT_POSITION_Y, &y);
    libevdev_enable_event_code(dev, EV_ABS, ABS_MT_TRACKING_ID, &id);

    rc = libevdev_uinput_create_from_device(dev, LIBEVDEV_UINPUT_OPEN_MANAGED, &uidev);
    if (rc < 0) {
        fprintf(stderr, "uinput: %s\n", strerror(-rc));
        return 1;
    }
    printf("touch-anchor active: %s\n", libevdev_uinput_get_devnode(uidev));
    fflush(stdout);

    signal(SIGTERM, on_signal);
    signal(SIGINT, on_signal);
    while (!stop)
        pause();

    libevdev_uinput_destroy(uidev);
    libevdev_free(dev);
    return 0;
}
