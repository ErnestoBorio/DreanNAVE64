#include "starfield.h"
#include "c64_hardware.h"

static uint8_t g_scroll_timer = 0;

void starfield_init(void) {
    // Fill Screen RAM (0x0400) with spaces (0x20) and set Color RAM (0xD800) to white
    for (uint16_t i = 0; i < 1000; i++) {
        SCREEN_RAM[i] = 0x20;
        COLOR_RAM[i] = COLOR_WHITE;
    }

    // Seed initial star noise characters across the playfield (dots & stars)
    SCREEN_RAM[40 * 3 + 12] = 0x2E; // '.'
    SCREEN_RAM[40 * 6 + 28] = 0x2A; // '*'
    SCREEN_RAM[40 * 9 + 5]  = 0x2E;
    SCREEN_RAM[40 * 12 + 35] = 0x2A;
    SCREEN_RAM[40 * 15 + 18] = 0x2E;
    SCREEN_RAM[40 * 18 + 22] = 0x2A;
    SCREEN_RAM[40 * 21 + 8]  = 0x2E;
    SCREEN_RAM[40 * 23 + 31] = 0x2A;
}

void starfield_update(void) {
    g_scroll_timer++;

    // Scroll stars left every 3 frames for smooth readable movement
    if (g_scroll_timer < 3) return;
    g_scroll_timer = 0;

    // Shift character row data leftwards across playfield (lines 0 to 24)
    for (uint8_t row = 0; row < 25; row++) {
        uint16_t row_offset = row * 40;
        uint8_t leftmost_char = SCREEN_RAM[row_offset];

        for (uint8_t col = 0; col < 39; col++) {
            SCREEN_RAM[row_offset + col] = SCREEN_RAM[row_offset + col + 1];
        }
        
        SCREEN_RAM[row_offset + 39] = leftmost_char;
    }
}
