#!/usr/bin/env python3
"""
Importer for raw C64 sprite byte definitions.
Parses 15 raw sprite blocks (63 bytes each, 21 lines of 3 bytes) and generates:
- src/sprites_data.h
- src/sprites_data.c
Each sprite is formatted as 64 bytes (63 data bytes + 1 padding byte 0x00 for VIC-II block alignment).
"""

import sys
import os

RAW_SPRITE_DATA = """
	 48,   0,   0
	220,   0,   0
	 87,   0,   0
	217, 192,   0
	 26, 112,   0
	217, 192,   0
	 87,   0,   0
	220,   0,   0
	 48,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0


	 29,  92,   0
	 16,   0,   0
	 20,   0,   0
	 20,   0,   0
	 21,   0,   0
	 53,  77,   0
	  3, 245,  92
	 20, 119,  64
	 85,  92,  64
	215, 103,  16
	  3, 105, 197
	215, 103,  16
	 85,  92,  64
	 20, 119,  64
	  3, 245,  92
	  5,  77,   0
	 53,   0,   0
	 20,   0,   0
	 20,   0,   0
	 16,   0,   0
	 29,  92,   0


	  0,  51,   0
	  0, 221, 192
	 13,  84,   0
	  0,  52, 112
	  3,  89, 192
	213, 169,   0
	  3,  89, 192
	  0,  52, 112
	 13,  84,   0
	  0, 221, 192
	  0,  51,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0


	  0,   3, 112
	  0,  13,  92
	  0,  13,  87
	215,   1,  92
	  5,   0,  64
	215,  64,  64
	  0, 115, 112
	  0,  17, 192
	  0,  21,   0
	 13, 217, 192
	 54, 106,  95
	 13, 217, 192
	  0,  21,   0
	  0,  17, 192
	  0, 115, 112
	215,  64,  64
	  5,   0,  64
	215,   1,  92
	  0,  13,  87
	  0,  13,  92
	  0,   3, 112


	  0,   0,  16
	  0, 245, 220
	  0,   0,  16
	  0,   0,  80
	  0,   0,  80
	  0,   1, 124
	  0,   5, 215
	  0, 215, 124
	  1, 174,  80
	214, 170, 188
	  1, 174,  80
	  0, 215, 124
	  0,   5, 215
	  0,   1, 124
	  0,   0,  80
	  0,   0,  80
	  0,   0,  16
	  0, 245, 220
	  0,   0,  16
	  0,   0,   0
	  0,   0,   0


	  0, 221,  87
	  0,   0,  16
	  0,   0,  16
	  0,   0, 208
	  3, 117, 124
	  0,   3,  80
	  0,   1,  80
	 53, 205, 112
	221, 118,  80
	  3,  90, 156
	  3,  90, 156
	221, 118,  80
	 53, 205, 112
	  0,   1,  80
	  0,   3,  80
	  3, 117, 124
	  0,   0, 208
	  0,   0,  16
	  0,   0,  16
	  0, 221,  87
	  0,   0,   0


	  0,  63,   0
	  3,  85, 112
	 13,  85,  92
	  5,  85,  84
	 48, 213, 195
	  0,   4,   0
	  0,  55,   0
	  0, 213, 112
	213,  85, 192
	  3, 105, 112
	  1, 170,  87
	  3, 105, 112
	213,  85, 192
	  0,  21, 112
	  0,  55,   0
	  0,   4,   0
	 48, 213, 195
	  5,  85,  84
	 13,  85,  92
	  3,  85, 112
	  0,  63,   0


	 13,   4,  48
	  3, 142,   8
	  0,  97,   4
	212,  18,  56
	 10,  33,  36
	  1, 186,  32
	  0, 231, 144
	128, 153,   0
	 43, 182, 176
	221, 149, 107
	221, 182, 176
	 43, 153,   0
	128, 231, 128
	  0,  58, 144
	  1, 162,  32
	 10,  17,  32
	212,  34,  24
	  0,  97,  52
	  3, 142,   8
	 13,   4,   4
	  0,   0,  48


	  0,  60,   0
	  3,  60, 192
	  3,  85, 192
	 61,  85, 124
	  5,  85,  80
	  5, 105,  80
	213, 170,  87
	 22, 170, 148
	 22, 130, 148
	214, 130, 151
	214, 130, 151
	 22, 130, 148
	 22, 170, 148
	213, 170,  87
	  5, 105,  80
	  5,  85,  80
	 61,  85, 124
	  3,  85, 192
	  3,  60, 192
	  0,  60,   0
	  0,   0,   0


	  0,   0,   0
	  0,   0,   4
	  4,   0,   7
	 52,   0,  53
	 23,   0, 208
	  1, 193, 112
	  0, 245,  92
	 15,  86, 151
	 53, 214,  85
	 23,  85,  85
	 21, 221,  85
	 23,  85,  85
	 53, 214,  85
	 15,  86, 151
	  0, 245,  92
	  1, 193, 112
	 23,   0, 208
	 52,   0,  53
	  4,   0,   7
	  0,   0,   4
	  0,   0,   0


	  0, 158, 254
	151, 127, 191
	  0,  87, 254
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0


	  0, 158, 254
	151, 127, 187
	  0,  87, 254
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0, 134, 254
	 71, 125, 239
	  0,  83, 254
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0


	  2, 222,   0
	155, 247,   0
	  2, 126,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   5, 190
	  9, 191, 239
	  0,  11, 190
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  2,  94,   0
	155, 251,   0
	  1, 118,   0
	  0,   0,   0


	 56,   0,   0
	116,   0,   0
	250,   0,   0
	254,   0,   0
	190,   0,   0
	 92,   0,   0
	 56,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0
	  0,   0,   0


	  0,  28,   0
	  0,  58,   0
	  0, 125,   0
	  0, 127,   0
	  0,  95,   0
	  0,  46,   0
	 56,  28,   0
	116,   0,   0
	250,   0,   0
	254,   0,   0
	190,   0,   0
	 92,   0,   0
	 56,  28,   0
	  0,  58,   0
	  0, 125,   0
	  0, 127,   0
	  0,  95,   0
	  0,  46,   0
	  0,  28,   0
	  0,   0,   0
	  0,   0,   0
"""

SPRITE_NAMES = [
    ("g_sprite_player_ship_1", "Sprite 1: Player Ship Stage 1 (Multicolor)", True),
    ("g_sprite_player_ship_2", "Sprite 2: Player Ship Stage 2 (Multicolor)", True),
    ("g_sprite_enemy_1", "Sprite 3: Enemy Ship 1 (Multicolor)", True),
    ("g_sprite_enemy_2", "Sprite 4: Enemy Ship 2 (Multicolor)", True),
    ("g_sprite_enemy_3", "Sprite 5: Enemy Ship 3 (Multicolor)", True),
    ("g_sprite_enemy_4", "Sprite 6: Enemy Ship 4 (Multicolor)", True),
    ("g_sprite_enemy_5", "Sprite 7: Enemy Ship 5 (Multicolor)", True),
    ("g_sprite_enemy_6", "Sprite 8: Enemy Ship 6 (Multicolor)", True),
    ("g_sprite_enemy_7", "Sprite 9: Enemy Ship 7 (Multicolor)", True),
    ("g_sprite_enemy_8", "Sprite 10: Enemy Ship 8 (Multicolor)", True),
    ("g_sprite_player_shot_1", "Sprite 11: Player Shot 1 (Monochrome Hi-Res)", False),
    ("g_sprite_player_shot_2", "Sprite 12: Player Shot 2 (Monochrome Hi-Res)", False),
    ("g_sprite_player_shot_3", "Sprite 13: Player Shot 3 (Monochrome Hi-Res)", False),
    ("g_sprite_enemy_shot_1", "Sprite 14: Enemy Shot 1 (Monochrome Hi-Res)", False),
    ("g_sprite_enemy_shot_2", "Sprite 15: Enemy Shot 2 (Monochrome Hi-Res)", False),
]

def parse_sprites():
    numbers = []
    for line in RAW_SPRITE_DATA.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split(',') if p.strip()]
        for p in parts:
            numbers.append(int(p))
    
    print(f"Total raw numbers parsed: {len(numbers)}")
    assert len(numbers) == 15 * 63, f"Expected 945 bytes (15 * 63), got {len(numbers)}"

    sprites = []
    for i in range(15):
        raw_63 = numbers[i*63 : (i+1)*63]
        padded_64 = raw_63 + [0] # 64-byte VIC-II aligned block
        sprites.append(padded_64)
    return sprites

def generate_c_files(sprites):
    # Generate src/sprites_data.h
    h_content = """#ifndef SPRITES_DATA_H
#define SPRITES_DATA_H

#include <stdint.h>

#define NUM_GAME_SPRITES 15

// Individual 64-byte VIC-II sprite blocks (63 data bytes + 1 padding byte)
"""
    for idx, (var_name, desc, is_mc) in enumerate(SPRITE_NAMES):
        h_content += f"// {desc}\n"
        h_content += f"extern const uint8_t {var_name}[64];\n\n"

    h_content += "// Alias for default stage 1 player ship\n#define g_sprite_player_ship g_sprite_player_ship_1\n\n"
    h_content += """// Table of all 15 sprite blocks indexed 0..14 (matching 1-based sprites 1..15)
extern const uint8_t* const g_all_game_sprites[NUM_GAME_SPRITES];

#endif // SPRITES_DATA_H
"""

    with open("src/sprites_data.h", "w") as f:
        f.write(h_content)
    print("Wrote src/sprites_data.h")

    # Generate src/sprites_data.c
    c_content = """#include "sprites_data.h"

"""
    for idx, (var_name, desc, is_mc) in enumerate(SPRITE_NAMES):
        c_content += f"// {desc}\n"
        c_content += f"const uint8_t {var_name}[64] = {{\n"
        data_64 = sprites[idx]
        for row in range(21):
            b0, b1, b2 = data_64[row*3 : row*3+3]
            c_content += f"    0x{b0:02X}, 0x{b1:02X}, 0x{b2:02X},\n"
        c_content += "    0x00 // Padding byte to fill 64-byte VIC-II block\n"
        c_content += "};\n\n"

    c_content += "const uint8_t* const g_all_game_sprites[NUM_GAME_SPRITES] = {\n"
    for var_name, desc, is_mc in SPRITE_NAMES:
        c_content += f"    {var_name},\n"
    c_content += "};\n"

    with open("src/sprites_data.c", "w") as f:
        f.write(c_content)
    print("Wrote src/sprites_data.c")

if __name__ == "__main__":
    sprites = parse_sprites()
    generate_c_files(sprites)

