#ifndef PLAYER_H
#define PLAYER_H

#include <stdint.h>
#include <stdbool.h>
#include "input.h"

typedef struct {
    uint16_t x;
    uint8_t y;
    uint8_t power_level;
    bool alive;
} Player;

extern Player g_player;

void player_init(void);
void player_update(const InputState* input);
void player_render(void);

#endif // PLAYER_H
