#ifndef STARFIELD_H
#define STARFIELD_H

#include <stdint.h>

void starfield_init(void);
void starfield_set_speed(uint8_t speed_pixels_per_frame);
void starfield_update(void);

#endif // STARFIELD_H

