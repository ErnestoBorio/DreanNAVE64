#include "player.h"
#include "c64_hardware.h"

Player g_player;

#define SPRITE_RAM_ADDR ((volatile uint8_t*)0x0E00)
#define PLAYER_SPRITE_BLOCK 56

// Placeholder 8x8 tiny ship sprite pattern (facing right)
static const uint8_t g_tiny_ship_sprite[64] = {
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0xC0, 0x00, 0x00, // Top wing:   ##
    0xF0, 0x00, 0x00, // Cockpit:   ####
    0xFC, 0x00, 0x00, // Main body: ######
    0xFF, 0x00, 0x00, // Nose tip:  ########
    0xFC, 0x00, 0x00, // Main body: ######
    0xF0, 0x00, 0x00, // Cockpit:   ####
    0xC0, 0x00, 0x00, // Bottom wing:##
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    0x00
};

void player_init(void) {
    g_player.x = 60;
    g_player.y = 120;
    g_player.power_level = 0;
    g_player.alive = true;

    // Load sprite pattern into VIC-II sprite block RAM (0x0E00)
    for (uint8_t i = 0; i < 64; i++) {
        SPRITE_RAM_ADDR[i] = g_tiny_ship_sprite[i];
    }

    // Set Sprite 0 pointer to block 56 (0x0E00 / 64 = 56)
    SPRITE_PTRS[0] = PLAYER_SPRITE_BLOCK;

    // Enable Sprite 0 and set color to White
    VIC_SPR_ENABLE |= 0x01;
    VIC_SPR0_COLOR = COLOR_WHITE;

    // Disable Y-expansion for tiny 8x8 ship
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
