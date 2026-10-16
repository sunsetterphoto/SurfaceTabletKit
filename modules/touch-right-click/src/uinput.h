#ifndef UINPUT_H
#define UINPUT_H
#include <libevdev/libevdev-uinput.h>

// Coordinate space the virtual absolute pointer reports in.
#define UINPUT_ABS_MAX 32767

struct libevdev_uinput *uinput_initialize();
void uinput_send_right_click(struct libevdev_uinput *uinput, int x, int y);
#endif
