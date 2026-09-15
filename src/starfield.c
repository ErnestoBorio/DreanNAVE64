#include "starfield.h"
#include "c64_hardware.h"
#include "charset_data.h"

#define CHARSET_RAM ((volatile uint8_t*)0x2800)

static uint8_t g_scroll_timer = 0;
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

    // 3. Clear Screen RAM and populate initial non-repeating starfield distribution
    g_lfsr16 = 0xACE1;
    for (uint8_t row = 0; row < 25; row++) {
        uint16_t row_offset = row * 40;
        for (uint8_t col = 0; col < 40; col++) {
            COLOR_RAM[row_offset + col] = COLOR_WHITE;
            SCREEN_RAM[row_offset + col] = get_next_star(row);
        }
    }
}

void starfield_update(void) {
    g_scroll_timer++;

    // Scroll stars left every 3 frames for smooth readable movement
    if (g_scroll_timer < 3) return;
    g_scroll_timer = 0;

    // Shift character row data leftwards across playfield (lines 0 to 24)
    for (uint8_t row = 0; row < 25; row++) {
        uint16_t row_offset = row * 40;

        for (uint8_t col = 0; col < 39; col++) {
            SCREEN_RAM[row_offset + col] = SCREEN_RAM[row_offset + col + 1];
        }

        // Spawn incoming star or blank cell at column 39 based on 16-bit PRNG & weighted frequencies
        SCREEN_RAM[row_offset + 39] = get_next_star(row);
    }
}
