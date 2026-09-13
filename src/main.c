#include "c64_hardware.h"
#include "input.h"
#include "player.h"
#include "enemies.h"
#include "collisions.h"
#include "hud.h"

int main(void) {
    // Phase 0: Initialize VIC-II screen & clear state
    VIC_BORDER_COLOR = COLOR_BLACK;
    VIC_BG_COLOR0 = COLOR_BLACK;

    // Clear Screen RAM (0x0400) and Color RAM (0xD800)
    for (uint16_t i = 0; i < 1000; i++) {
        SCREEN_RAM[i] = 0x20; // Space
        COLOR_RAM[i] = COLOR_WHITE;
    }

    // Initialize placeholder modules
    input_init();
    player_init();
    enemies_init();
    collisions_init();
    hud_init();

    // Stable main frame loop (Phase 0 Skeleton)
    while (1) {
        // Wait for raster line to maintain stable loop
        while (VIC_RASTER != 0xF8);
        while (VIC_RASTER == 0xF8);

        input_update(0);
        player_update(0);
        enemies_update();
        collisions_check();
        hud_update();
    }

    return 0;
}
