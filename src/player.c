#include "player.h"
#include "c64_hardware.h"
#include "sprites_data.h"

Player g_player;

#define SPRITE_RAM_ADDR ((volatile uint8_t*)0x0E00)
#define PLAYER_SPRITE_BLOCK 56

void player_init(void) {
    g_player.x = 60;
    g_player.y = 120;
    g_player.power_level = 0;
    g_player.alive = true;

    // Copy official Sprite 1 (Player ship multicolor sprite bytes) into VIC-II sprite block RAM (0x0E00)
    for (uint8_t i = 0; i < 64; i++) {
        SPRITE_RAM_ADDR[i] = g_sprite_player_ship[i];
    }

    // Set Sprite 0 pointer to block 56 (0x0E00 / 64 = 56)
    SPRITE_PTRS[0] = PLAYER_SPRITE_BLOCK;

    // Enable Sprite 0
    VIC_SPR_ENABLE |= 0x01;

    // Enable Multicolor Mode for Sprite 0
    VIC_SPR_MULTICOLOR |= 0x01;

    // Configure Sprite Colors for Multicolor Mode
    VIC_SPR0_COLOR = COLOR_WHITE;       // %10 = White (Main ship highlight)
    VIC_SPR_MC0 = COLOR_MEDIUM_GRAY;    // %01 = Medium Gray (Outline / Details)
    VIC_SPR_MC1 = COLOR_LIGHT_BLUE;     // %11 = Light Blue (Cockpit / Accent)

    // Disable Y-expansion for tiny ship
    VIC_SPR_EXP_Y &= ~0x01;
}

void player_update(const InputState* input) {
    if (!g_player.alive || !input) return;

    uint8_t speed = 2;

    if (input->up) {
        if (g_player.y > SPRITE_MIN_Y + speed) {
            g_player.y -= speed;
        } else {
            g_player.y = SPRITE_MIN_Y;
        }
    }
    if (input->down) {
        if (g_player.y + speed < SPRITE_MAX_Y) {
            g_player.y += speed;
        } else {
            g_player.y = SPRITE_MAX_Y;
        }
    }
    if (input->left) {
        if (g_player.x > SPRITE_MIN_X + speed) {
            g_player.x -= speed;
        } else {
            g_player.x = SPRITE_MIN_X;
        }
    }
    if (input->right) {
        if (g_player.x + speed < SPRITE_MAX_X) {
            g_player.x += speed;
        } else {
            g_player.x = SPRITE_MAX_X;
        }
    }
}

void player_render(void) {
    VIC_SPR0_X = (uint8_t)(g_player.x & 0xFF);
    VIC_SPR0_Y = g_player.y;

    if (g_player.x > 255) {
        VIC_SPR_MSB |= 0x01;
    } else {
        VIC_SPR_MSB &= ~0x01;
    }
}
