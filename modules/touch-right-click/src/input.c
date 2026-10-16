#include "input.h"
#include "uinput.h"
#include "rce.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/select.h>
#include <sys/timerfd.h>
#include <unistd.h>

// Coordinate space of one source touch device, needed to translate a
// touch position into the coordinate space of our virtual pointer.
struct axis_range_t {
    int x_min, x_max;
    int y_min, y_max;
};

struct input_state_t {
    int pressed_device_id;
    int pos_x, pos_y;
    int pressed_pos_x, pressed_pos_y;
    int fd_timer; // The timer used to execute right click on timeout
    struct libevdev_uinput *uinput;
    struct axis_range_t *ranges; // one entry per source device
    // A recognized long press waiting for the finger to be lifted.
    int pending;
    int pending_x, pending_y;   // position in source device coordinates
    int pending_device_id;
};

static void send_click_at(struct input_state_t *state,
        int dev_id, int pos_x, int pos_y);

void free_evdev(struct libevdev *evdev) {
    int fd = libevdev_get_fd(evdev);
    libevdev_free(evdev);
    close(fd);
}

// Read the coordinate space of a touch device. Multitouch axes win when
// present -- that is what a finger reports on; ABS_X/ABS_Y is the fallback
// for single-touch digitizer nodes.
static void read_axis_range(struct libevdev *evdev, struct axis_range_t *r) {
    const struct input_absinfo *ax =
        libevdev_get_abs_info(evdev, ABS_MT_POSITION_X);
    const struct input_absinfo *ay =
        libevdev_get_abs_info(evdev, ABS_MT_POSITION_Y);
    if (ax == NULL)
        ax = libevdev_get_abs_info(evdev, ABS_X);
    if (ay == NULL)
        ay = libevdev_get_abs_info(evdev, ABS_Y);
    r->x_min = ax != NULL ? ax->minimum : 0;
    r->x_max = ax != NULL ? ax->maximum : 0;
    r->y_min = ay != NULL ? ay->minimum : 0;
    r->y_max = ay != NULL ? ay->maximum : 0;
}

// Map a value from a source axis onto 0..UINPUT_ABS_MAX
static int scale_axis(int value, int min, int max) {
    if (max <= min)
        return 0;
    if (value < min)
        value = min;
    if (value > max)
        value = max;
    long long span = (long long) max - (long long) min;
    return (int) (((long long) (value - min) * UINPUT_ABS_MAX) / span);
}

// Build the fd set used by `select`
// return: nfds to be used in select()
int build_fd_set(fd_set *fds, int fd_timer,
        int num, struct libevdev **evdev) {
    FD_ZERO(fds);
    FD_SET(fd_timer, fds);
    int fd = -1, max_fd = fd_timer;
    for (unsigned int i = 0; i < num; i++) {
        fd = libevdev_get_fd(evdev[i]);
        FD_SET(fd, fds);
        if (fd > max_fd)
            max_fd = fd;
    }
    return max_fd + 1;
}

void arm_delayed_rclick(struct input_state_t *state, int dev_id) {
    state->pending = 0;
    // Record the position where the touch event began
    state->pressed_pos_x = state->pos_x;
    state->pressed_pos_y = state->pos_y;
    state->pressed_device_id = dev_id;
    // Start the timer; once timeout reached,
    // fire the right click event
    timerfd_settime(state->fd_timer, 0, &(struct itimerspec) {
        .it_value = LONG_CLICK_INTERVAL,
    }, NULL);
}

void unarm_delayed_rclick(struct input_state_t *state) {
    state->pressed_device_id = -1;
    // Force cancel the timer if finger released
    timerfd_settime(state->fd_timer, 0, &(struct itimerspec) {
        .it_value = {
            .tv_sec = 0,
            .tv_nsec = 0,
        },
    }, NULL);
}

void on_input_event(struct input_state_t *state,
        struct input_event *ev, int dev_id) {
    // If we are during a long-press event,
    // do not interruput with another device
    if (state->pressed_device_id != -1 && dev_id != state->pressed_device_id)
        return;

    if (ev->type == EV_ABS) {
        // Absolute position event
        // Record the current position
        if (ev->code == ABS_X || ev->code == ABS_MT_POSITION_X) {
            state->pos_x = ev->value;
        } else if (ev->code == ABS_Y || ev->code == ABS_MT_POSITION_Y) {
            state->pos_y = ev->value;
        }
    } else if (ev->type == EV_KEY && ev->code == BTN_TOUCH) {
        // Touch event
        if (ev->value == 1) {
            // Schedule a delayed right click event
            // so that if anything happens before the long-press timeout,
            // it can be canceled
            arm_delayed_rclick(state, dev_id);
        } else {
            // Finger released. Now -- with no touch sequence in flight --
            // is the moment to deliver a recognized long press.
            if (state->pending && state->pending_device_id == dev_id) {
                unsigned int dx = abs(state->pos_x - state->pending_x);
                unsigned int dy = abs(state->pos_y - state->pending_y);
                if (dx <= LONG_CLICK_FUZZ && dy <= LONG_CLICK_FUZZ) {
                    send_click_at(state, state->pending_device_id,
                        state->pending_x, state->pending_y);
                } else {
                    fprintf(stderr, "long press dropped on lift: drift %u/%u "
                        "exceeds fuzz %d\n", dx, dy, LONG_CLICK_FUZZ);
                }
            }
            state->pending = 0;
            unarm_delayed_rclick(state);
        }
    }
}

static void send_click_at(struct input_state_t *state,
        int dev_id, int pos_x, int pos_y) {
    struct axis_range_t *r = &state->ranges[dev_id];
    int sx = scale_axis(pos_x, r->x_min, r->x_max);
    int sy = scale_axis(pos_y, r->y_min, r->y_max);
    uinput_send_right_click(state->uinput, sx, sy);
    // Logged so that "no menu appeared" can be told apart from
    // "no click was ever sent" without a separate input recording.
    fprintf(stderr, "right click sent at %d/%d of %d (raw %d,%d)\n",
        sx, sy, UINPUT_ABS_MAX, pos_x, pos_y);
}

// Fire the click once the finger is off the glass, not while it is still
// down. A click injected mid-touch is a second, simultaneous input sequence,
// and GTK gestures configured for a single point (gtk4-ding's desktop grid
// uses set_exclusive(true) with one point) simply ignore it -- the desktop
// context menu never opened. Waiting for the lift also keeps the finger from
// sitting on top of the menu that is about to appear.
int CLICK_ON_RELEASE = 1;

void on_timer_expire(struct input_state_t *state) {
    unsigned int dx = abs(state->pos_x - state->pressed_pos_x);
    unsigned int dy = abs(state->pos_y - state->pressed_pos_y);
    // Only consider movement within a range to be "still"
    // i.e. if movement is within this value during timeout
    //      , then it is a long click
    if (state->pressed_device_id < 0) {
        // Stray timer wakeup with no finger down -- nothing to do.
    } else if (dx <= LONG_CLICK_FUZZ && dy <= LONG_CLICK_FUZZ) {
        if (CLICK_ON_RELEASE) {
            state->pending = 1;
            state->pending_x = state->pos_x;
            state->pending_y = state->pos_y;
            state->pending_device_id = state->pressed_device_id;
            fprintf(stderr, "long press recognized at %d,%d (drift %u/%u), "
                "waiting for lift\n", state->pos_x, state->pos_y, dx, dy);
        } else {
            send_click_at(state, state->pressed_device_id,
                state->pos_x, state->pos_y);
        }
    } else {
        fprintf(stderr, "long press discarded: drift %u/%u exceeds fuzz %d\n",
            dx, dy, LONG_CLICK_FUZZ);
    }
    // In Linux implementation of timerfd, the fd becomes always "readable"
    // after the timeout. So we have to unarm it after we receive the event.
    unarm_delayed_rclick(state);
}

void process_evdev_input(int num, struct libevdev **evdev) {
    struct axis_range_t *ranges = calloc(num, sizeof(struct axis_range_t));
    if (ranges == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(-1);
    }
    for (int i = 0; i < num; i++) {
        read_axis_range(evdev[i], &ranges[i]);
        printf("  %s: x %d..%d, y %d..%d\n", libevdev_get_name(evdev[i]),
            ranges[i].x_min, ranges[i].x_max,
            ranges[i].y_min, ranges[i].y_max);
    }
    fflush(stdout);

    // Initialize everything to -1
    struct input_state_t state = {
        .pressed_device_id = -1,
        .pos_x = -1, .pos_y = -1,
        .pressed_pos_x = -1, .pressed_pos_y = -1,
        .fd_timer = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK),
        .uinput = uinput_initialize(),
        .ranges = ranges,
        .pending = 0,
        .pending_x = -1, .pending_y = -1,
        .pending_device_id = -1,
    };

    // Check if uinput device was created
    if (state.uinput == NULL) {
        fprintf(stderr, "Failed to create uinput device\n");
        exit(-1);
        return;
    }

    // Initialize the set of fds
    fd_set fds;
    int nfds = build_fd_set(&fds, state.fd_timer, num, evdev);

    struct input_event ev;
    // Detect events from the fds
    while (select(nfds, &fds, NULL, NULL, NULL) > 0) {
        // The timer fd
        if (FD_ISSET(state.fd_timer, &fds))
            on_timer_expire(&state);

        for (unsigned int i = 0; i < num; i++) {
            // Can we read an event?
            if (!FD_ISSET(libevdev_get_fd(evdev[i]), &fds))
                continue;

            // Read all the available events
            int rc;
            while ((rc = libevdev_next_event(evdev[i],
                    LIBEVDEV_READ_FLAG_NORMAL, &ev)) == 0) {
                on_input_event(&state, &ev, i);
            }
            // A device that went away keeps its fd readable forever, which
            // would spin this loop at 100% CPU. Bail out instead and let
            // systemd restart us, so the device list is enumerated afresh.
            if (rc == -ENODEV) {
                fprintf(stderr, "Device %s disappeared, exiting to re-enumerate\n",
                    libevdev_get_name(evdev[i]));
                goto out;
            }
        }

        // Reset the fd_set for next iteration
        nfds = build_fd_set(&fds, state.fd_timer, num, evdev);
    }

out:
    // Cleanup
    close(state.fd_timer);
    libevdev_uinput_destroy(state.uinput);
    for (int i = 0; i < num; i++) {
        free_evdev(evdev[i]);
    }
    free(ranges);
}
