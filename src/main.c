#include "c64_hardware.h"
#include "input.h"
#include "player.h"
#include "starfield.h"
#include "enemies.h"
#include "collisions.h"
#include "hud.h"

// 50 Hz PAL Frame Synchronization Helper
static void wait_vsync(void) {
    // 1. Wait until raster leaves bottom VBLANK region (< 240) if currently in VBLANK
    while (VIC_RASTER >= 240);
    // 2. Wait until raster reaches line 240 (beginning of VBLANK)
    while (VIC_RASTER < 240);
}

int main(void) {
    // Set screen border and background to high-contrast black
    VIC_BORDER_COLOR = COLOR_BLACK;
    VIC_BG_COLOR0 = COLOR_BLACK;

    // Initialize subsystems
    input_init();
    starfield_init();
    player_init();
    enemies_init();
    collisions_init();
    hud_init();

    InputState input;

    // Main 50 Hz Game Loop
    while (1) {
        wait_vsync();

        // 1. Read Input (Joystick 2, R-D-F-G, U-H-J-K)
        input_update(&input);

        // 2. Update Game Entities & World Motion
        player_update(&input);
        starfield_update();
        enemies_update();
        collisions_check();
        hud_update();

        // 3. Render Graphics & Hardware Sprites
        player_render();
        enemies_render();
        hud_render();
    }

    return 0;
}
