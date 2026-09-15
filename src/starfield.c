#include "starfield.h"
#include "c64_hardware.h"
#include "charset_data.h"

#define CHARSET_RAM ((volatile uint8_t*)0x2800)

static int8_t g_xscroll = 7;
static uint8_t g_scroll_speed = 4; // High-speed arcade scrolling: 4 pixels per frame (200px/sec)
static uint16_t g_lfsr16 = 0xACE1;

// Power-of-two 64-entry weighted table matching exact user frequency rules:
// - Chars 126 & 127 (0x7E, 0x7F): Most frequent (16 entries each = 32 entries / 50%)
// - Chars 123..125 (0x7B, 0x7C, 0x7D): Medium-high frequency (6 entries each = 18 entries / 28.1%)
// - Chars 117..119 (0x75, 0x76, 0x77) & 122 (0x7A): Medium-low frequency (3 entries each = 12 entries / 18.75%)
// - Chars 120 & 121 (0x78, 0x79): Lowest frequency (1 entry each = 2 entries / 3.125%)
static const uint8_t g_star_weighted_table[64] = {
    // 126 & 127 (Tier 1 - Most frequent)
    0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E, 0x7E,
    0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F,

    // 123, 124, 125 (Tier 2 - Medium-high frequency)
    0x7B, 0x7B, 0x7B, 0x7B, 0x7B, 0x7B,
    0x7C, 0x7C, 0x7C, 0x7C, 0x7C, 0x7C,
    0x7D, 0x7D, 0x7D, 0x7D, 0x7D, 0x7D,

    // 117, 118, 119, 122 (Tier 3 - Medium-low frequency, equal weights)
    0x75, 0x75, 0x75,
    0x76, 0x76, 0x76,
    0x77, 0x77, 0x77,
    0x7A, 0x7A, 0x7A,

    // 120, 121 (Tier 4 - Lowest frequency)
    0x78,
    0x79
};

static uint8_t get_next_star(uint8_t row) {
    // 16-bit Galois LFSR pseudo-random generator (65,535 state period)
    uint16_t lsb = g_lfsr16 & 1;
    g_lfsr16 >>= 1;
    if (lsb) g_lfsr16 ^= 0xB400u;

    // Inject row-index spatial variance to prevent cross-row correlation patterns
    uint16_t val = g_lfsr16 ^ ((uint16_t)row * 0x45 + 0x17);

    // Spawning density: ~3.1% chance of spawning a star cell
    if ((val & 0x1F) == 0) {
        // Power-of-two bitmask (& 0x3F) for 100% uniform, unbiased table selection
        uint8_t table_idx = (uint8_t)((val >> 5) & 0x3F);
        return g_star_weighted_table[table_idx];
    }
    return 0x20; // Space (blank background)
}

void starfield_init(void) {
    // 1. Copy 2048-byte custom charset into RAM at 0x2800
    for (uint16_t i = 0; i < CHARSET_SIZE; i++) {
        CHARSET_RAM[i] = g_custom_charset[i];
    }

    // 2. Configure VIC-II Memory Setup ($D018): Screen RAM @ 0x0400, Charset RAM @ 0x2800
    VIC_MEM_SETUP = 0x1A;

    // 3. Initialize fine scroll position (7) & enable 38-column window mode ($D016)
    g_xscroll = 7;
    g_scroll_speed = 4; // 4 pixels per frame (200px/sec)
    VIC_CTRL2 = (VIC_CTRL2 & ~0x0F) | ((uint8_t)g_xscroll & 0x07);

    // 4. Clear Screen RAM and populate initial non-repeating starfield distribution
    g_lfsr16 = 0xACE1;
    for (uint8_t row = 0; row < 25; row++) {
        uint16_t row_offset = row * 40;
        for (uint8_t col = 0; col < 40; col++) {
            COLOR_RAM[row_offset + col] = COLOR_WHITE;
            SCREEN_RAM[row_offset + col] = get_next_star(row);
        }
    }
}

void starfield_set_speed(uint8_t speed_pixels_per_frame) {
    g_scroll_speed = speed_pixels_per_frame;
}

void starfield_update(void) {
    // 1. Check if the upcoming scroll step will underflow below 0
    if (g_xscroll < (int8_t)g_scroll_speed) {
        // Shift SCREEN_RAM 1 column left BEFORE fine scroll wraps around 8
        volatile uint8_t* p_dst = SCREEN_RAM;
        volatile uint8_t* p_src = SCREEN_RAM + 1;

        for (uint8_t row = 0; row < 25; row++) {
            for (uint8_t col = 0; col < 39; col++) {
                *p_dst++ = *p_src++;
            }
            *p_dst++ = get_next_star(row);
            p_src++; // Skip col 39 of previous row to start col 0 of next row
        }

        g_xscroll += 8;
    }

    // 2. Advance fine scroll position by g_scroll_speed
    g_xscroll -= (int8_t)g_scroll_speed;

    // 3. Write VIC_CTRL2 ($D016) immediately in VBLANK (100% synchronized with SCREEN_RAM shift)
    VIC_CTRL2 = (VIC_CTRL2 & ~0x0F) | ((uint8_t)g_xscroll & 0x07);
}
