#ifndef SPRITES_DATA_H
#define SPRITES_DATA_H

#include <stdint.h>

#define NUM_GAME_SPRITES 15

// Individual 64-byte VIC-II sprite blocks (63 data bytes + 1 padding byte)
// Sprite 1: Player Ship Stage 1 (Multicolor)
extern const uint8_t g_sprite_player_ship_1[64];

// Sprite 2: Player Ship Stage 2 (Multicolor)
extern const uint8_t g_sprite_player_ship_2[64];

// Sprite 3: Enemy Ship 1 (Multicolor)
extern const uint8_t g_sprite_enemy_1[64];

// Sprite 4: Enemy Ship 2 (Multicolor)
extern const uint8_t g_sprite_enemy_2[64];

// Sprite 5: Enemy Ship 3 (Multicolor)
extern const uint8_t g_sprite_enemy_3[64];

// Sprite 6: Enemy Ship 4 (Multicolor)
extern const uint8_t g_sprite_enemy_4[64];

// Sprite 7: Enemy Ship 5 (Multicolor)
extern const uint8_t g_sprite_enemy_5[64];

// Sprite 8: Enemy Ship 6 (Multicolor)
extern const uint8_t g_sprite_enemy_6[64];

// Sprite 9: Enemy Ship 7 (Multicolor)
extern const uint8_t g_sprite_enemy_7[64];

// Sprite 10: Enemy Ship 8 (Multicolor)
extern const uint8_t g_sprite_enemy_8[64];

// Sprite 11: Player Shot 1 (Monochrome Hi-Res)
extern const uint8_t g_sprite_player_shot_1[64];

// Sprite 12: Player Shot 2 (Monochrome Hi-Res)
extern const uint8_t g_sprite_player_shot_2[64];

// Sprite 13: Player Shot 3 (Monochrome Hi-Res)
extern const uint8_t g_sprite_player_shot_3[64];

// Sprite 14: Enemy Shot 1 (Monochrome Hi-Res)
extern const uint8_t g_sprite_enemy_shot_1[64];

// Sprite 15: Enemy Shot 2 (Monochrome Hi-Res)
extern const uint8_t g_sprite_enemy_shot_2[64];

// Alias for default stage 1 player ship
#define g_sprite_player_ship g_sprite_player_ship_1

// Table of all 15 sprite blocks indexed 0..14 (matching 1-based sprites 1..15)
extern const uint8_t* const g_all_game_sprites[NUM_GAME_SPRITES];

#endif // SPRITES_DATA_H
