; ==============================================================================
; SPRITES_DATA.ASM - Complete 20 Hardware Sprite Definitions
; ==============================================================================
; Total: 20 Sprites x 64 bytes = 1,280 bytes ($0500)
; Each sprite consists of 63 data bytes (21 rows x 3 bytes) + 1 padding byte.
; Sprites 1..17 are imported from the master sprite sheet.
; Sprites 18..20 provide the 3-frame monochrome explosion sequence.
; ==============================================================================

; ------------------------------------------------------------------------------
; Sprite Block Pointer Indices (Assuming Base $3000 / Block 192)
; ------------------------------------------------------------------------------
SPRITE_PTR_PLAYER_SHIP_1   = 192  ; Sprite 1: Player Ship Stage 1 (Multicolor)
SPRITE_PTR_PLAYER_SHIP_2   = 193  ; Sprite 2: Player Ship Stage 2 (Multicolor)
SPRITE_PTR_PLAYER_SHIP_3   = 194  ; Sprite 3: Player Ship Stage 3 (Multicolor)
SPRITE_PTR_ENEMY_1         = 195  ; Sprite 4: Enemy Ship 1 (Multicolor)
SPRITE_PTR_ENEMY_2         = 196  ; Sprite 5: Enemy Ship 2 (Multicolor)
SPRITE_PTR_ENEMY_3         = 197  ; Sprite 6: Enemy Ship 3 - Interceptor (Multicolor)
SPRITE_PTR_ENEMY_4         = 198  ; Sprite 7: Enemy Ship 4 - Scorpion (Multicolor)
SPRITE_PTR_ENEMY_5         = 199  ; Sprite 8: Enemy Ship 5 - Batplane (Multicolor)
SPRITE_PTR_ENEMY_6         = 200  ; Sprite 9: Enemy Ship 6 - Spider (Multicolor)
SPRITE_PTR_ENEMY_7         = 201  ; Sprite 10: Enemy Ship 7 - The Eye (Multicolor)
SPRITE_PTR_ENEMY_8         = 202  ; Sprite 11: Enemy Ship 8 - Death (Multicolor)
SPRITE_PTR_PLAYER_SHOT_1   = 203  ; Sprite 12: Player Shot Level 1 (Monochrome Hi-Res)
SPRITE_PTR_PLAYER_SHOT_2   = 204  ; Sprite 13: Player Shot Level 2 (Monochrome Hi-Res Dual)
SPRITE_PTR_PLAYER_SHOT_3   = 205  ; Sprite 14: Player Shot Level 3 (Monochrome Hi-Res Triple)
SPRITE_PTR_ENEMY_SHOT_1    = 206  ; Sprite 15: Enemy Shot 1 (Monochrome Hi-Res Single)
SPRITE_PTR_ENEMY_SHOT_2    = 207  ; Sprite 16: Enemy Shot 2 (Monochrome Hi-Res Spread)
SPRITE_PTR_HIT_SPARK       = 208  ; Sprite 17: Hit Spark (Monochrome Hi-Res)
SPRITE_PTR_EXPLOSION_1     = 209  ; Sprite 18: Explosion Frame 1 (Monochrome Hi-Res)
SPRITE_PTR_EXPLOSION_2     = 210  ; Sprite 19: Explosion Frame 2 (Monochrome Hi-Res)
SPRITE_PTR_EXPLOSION_3     = 211  ; Sprite 20: Explosion Frame 3 (Monochrome Hi-Res)

; Default alias for primary player ship
SPRITE_PTR_PLAYER_SHIP     = 192

; ------------------------------------------------------------------------------
; Sprite 1: Player Ship Stage 1 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_player_ship_1:
    !byte $30, $00, $00
    !byte $d0, $00, $00
    !byte $54, $00, $00
    !byte $d9, $00, $00
    !byte $1a, $70, $00
    !byte $d9, $00, $00
    !byte $54, $00, $00
    !byte $d0, $00, $00
    !byte $30, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 2: Player Ship Stage 2 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_player_ship_2:
    !byte $1d, $5c, $00
    !byte $10, $00, $00
    !byte $14, $00, $00
    !byte $14, $00, $00
    !byte $15, $00, $00
    !byte $35, $4d, $00
    !byte $03, $f5, $5c
    !byte $d4, $75, $40
    !byte $55, $5c, $40
    !byte $d7, $67, $10
    !byte $03, $69, $d7
    !byte $d7, $67, $10
    !byte $55, $5c, $40
    !byte $d4, $75, $40
    !byte $03, $f5, $5c
    !byte $35, $4d, $00
    !byte $15, $00, $00
    !byte $14, $00, $00
    !byte $14, $00, $00
    !byte $10, $00, $00
    !byte $1d, $5c, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 3: Player Ship Stage 3 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_player_ship_3:
    !byte $00, $75, $c0
    !byte $1c, $40, $00
    !byte $57, $50, $00
    !byte $57, $53, $5c
    !byte $1c, $55, $c0
    !byte $00, $d5, $30
    !byte $00, $0f, $d0
    !byte $50, $d1, $d4
    !byte $d4, $55, $70
    !byte $55, $dd, $9c
    !byte $dd, $0d, $a5
    !byte $55, $dd, $9c
    !byte $d4, $55, $70
    !byte $50, $d1, $d4
    !byte $00, $0f, $d0
    !byte $00, $d5, $30
    !byte $1c, $55, $c0
    !byte $57, $53, $5c
    !byte $57, $50, $00
    !byte $1c, $40, $00
    !byte $00, $75, $c0
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 4: Enemy Ship 1 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_1:
    !byte $00, $33, $00
    !byte $00, $dd, $c0
    !byte $0d, $57, $00
    !byte $00, $37, $70
    !byte $03, $59, $c0
    !byte $d5, $a9, $00
    !byte $03, $59, $c0
    !byte $00, $37, $70
    !byte $0d, $57, $00
    !byte $00, $dd, $c0
    !byte $00, $33, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 5: Enemy Ship 2 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_2:
    !byte $00, $00, $10
    !byte $00, $f5, $dc
    !byte $00, $00, $10
    !byte $00, $00, $50
    !byte $00, $00, $50
    !byte $00, $01, $7c
    !byte $00, $05, $d7
    !byte $00, $55, $7c
    !byte $01, $69, $50
    !byte $d5, $aa, $70
    !byte $01, $69, $50
    !byte $00, $55, $7c
    !byte $00, $05, $d7
    !byte $00, $01, $7c
    !byte $00, $00, $50
    !byte $00, $00, $50
    !byte $00, $00, $10
    !byte $00, $f5, $dc
    !byte $00, $00, $10
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 6: Enemy Ship 3 - Scorpion (Multicolor)
; Sprite 6: Enemy Ship 3 - Interceptor (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_3:
    !byte $00, $dd, $57
    !byte $00, $00, $10
    !byte $00, $00, $10
    !byte $00, $00, $d0
    !byte $03, $75, $7c
    !byte $00, $03, $50
    !byte $00, $01, $50
    !byte $00, $0d, $70
    !byte $00, $f6, $50
    !byte $0f, $5a, $9c
    !byte $f5, $7a, $94
    !byte $0f, $5a, $9c
    !byte $00, $f6, $50
    !byte $00, $0d, $70
    !byte $00, $01, $50
    !byte $00, $03, $50
    !byte $03, $75, $7c
    !byte $00, $00, $d0
    !byte $00, $00, $10
    !byte $00, $00, $10
    !byte $00, $dd, $57
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 7: Enemy Ship 4 - Interceptor (Multicolor)
; Sprite 7: Enemy Ship 4 - Scorpion (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_4:
    !byte $00, $03, $70
    !byte $00, $0d, $5c
    !byte $00, $0d, $57
    !byte $d7, $01, $5c
    !byte $05, $00, $40
    !byte $d7, $40, $40
    !byte $00, $73, $70
    !byte $00, $11, $c0
    !byte $00, $15, $00
    !byte $0d, $d9, $c0
    !byte $36, $6a, $5f
    !byte $0d, $d9, $c0
    !byte $00, $15, $00
    !byte $00, $11, $c0
    !byte $00, $73, $70
    !byte $d7, $40, $40
    !byte $05, $00, $40
    !byte $d7, $01, $5c
    !byte $00, $0d, $57
    !byte $00, $0d, $5c
    !byte $00, $03, $70
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 8: Enemy Ship 5 - Batplane (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_5:
    !byte $00, $3f, $00
    !byte $03, $55, $70
    !byte $0d, $55, $5c
    !byte $05, $55, $54
    !byte $30, $d5, $c3
    !byte $00, $04, $00
    !byte $00, $37, $00
    !byte $00, $d5, $70
    !byte $d5, $55, $c0
    !byte $03, $69, $70
    !byte $0d, $aa, $57
    !byte $03, $69, $70
    !byte $d5, $55, $c0
    !byte $00, $d5, $70
    !byte $00, $37, $00
    !byte $00, $04, $00
    !byte $30, $d5, $c3
    !byte $05, $55, $54
    !byte $0d, $55, $5c
    !byte $03, $55, $70
    !byte $00, $3f, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 9: Enemy Ship 6 - Spider (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_6:
    !byte $00, $00, $00
    !byte $0d, $04, $30
    !byte $03, $8e, $08
    !byte $00, $61, $04
    !byte $d4, $22, $18
    !byte $0a, $11, $20
    !byte $01, $22, $20
    !byte $00, $ba, $90
    !byte $80, $e7, $80
    !byte $28, $99, $c0
    !byte $dd, $b6, $ee
    !byte $28, $99, $c0
    !byte $80, $e7, $80
    !byte $00, $ba, $90
    !byte $01, $22, $20
    !byte $0a, $11, $20
    !byte $d4, $22, $18
    !byte $00, $61, $04
    !byte $03, $8e, $08
    !byte $0d, $04, $30
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 10: Enemy Ship 7 - The Eye (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_7:
    !byte $00, $3c, $00
    !byte $03, $3c, $c0
    !byte $03, $55, $c0
    !byte $3d, $55, $7c
    !byte $05, $55, $50
    !byte $05, $69, $50
    !byte $d5, $aa, $57
    !byte $16, $aa, $94
    !byte $16, $82, $94
    !byte $d6, $82, $97
    !byte $d6, $82, $97
    !byte $16, $82, $94
    !byte $16, $aa, $94
    !byte $d5, $aa, $57
    !byte $05, $69, $50
    !byte $05, $55, $50
    !byte $3d, $55, $7c
    !byte $03, $55, $c0
    !byte $03, $3c, $c0
    !byte $00, $3c, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 11: Enemy Ship 8 - Death (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_8:
    !byte $00, $00, $10
    !byte $10, $00, $1c
    !byte $d0, $00, $d4
    !byte $5c, $03, $40
    !byte $07, $05, $00
    !byte $03, $d5, $70
    !byte $01, $5a, $5c
    !byte $d7, $59, $5c
    !byte $5d, $55, $54
    !byte $57, $75, $54
    !byte $5d, $55, $54
    !byte $d7, $59, $5c
    !byte $01, $5a, $5c
    !byte $03, $d5, $70
    !byte $07, $05, $00
    !byte $5c, $03, $40
    !byte $d0, $00, $d4
    !byte $10, $00, $1c
    !byte $00, $00, $10
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 12: Player Shot Level 1 (Monochrome Hi-Res)
; ------------------------------------------------------------------------------
g_sprite_player_shot_1:
    !byte $00, $9e, $fe
    !byte $97, $7f, $bf
    !byte $00, $57, $fe
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 13: Player Shot Level 2 (Monochrome Hi-Res Dual)
; ------------------------------------------------------------------------------
g_sprite_player_shot_2:
    !byte $00, $9e, $fe
    !byte $97, $7f, $bb
    !byte $00, $57, $fe
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $86, $fe
    !byte $47, $7d, $ef
    !byte $00, $53, $fe
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 14: Player Shot Level 3 (Monochrome Hi-Res Triple)
; ------------------------------------------------------------------------------
g_sprite_player_shot_3:
    !byte $02, $de, $00
    !byte $9b, $f7, $00
    !byte $02, $7e, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $05, $be
    !byte $09, $bf, $ef
    !byte $00, $0b, $be
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $02, $5e, $00
    !byte $9b, $fb, $00
    !byte $01, $76, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 15: Enemy Shot 1 (Monochrome Hi-Res Single)
; ------------------------------------------------------------------------------
g_sprite_enemy_shot_1:
    !byte $70, $00, $00
    !byte $f8, $00, $00
    !byte $f8, $00, $00
    !byte $f8, $00, $00
    !byte $70, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 16: Enemy Shot 2 (Monochrome Hi-Res Spread)
; ------------------------------------------------------------------------------
g_sprite_enemy_shot_2:
    !byte $00, $38, $00
    !byte $00, $7c, $00
    !byte $00, $7c, $00
    !byte $00, $7c, $00
    !byte $00, $38, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $70, $00, $00
    !byte $f8, $00, $00
    !byte $f8, $00, $00
    !byte $f8, $00, $00
    !byte $70, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $38, $00
    !byte $00, $7c, $00
    !byte $00, $7c, $00
    !byte $00, $7c, $00
    !byte $00, $38, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 17: Hit Spark (Monochrome Hi-Res)
; ------------------------------------------------------------------------------
g_sprite_hit_spark:
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $08, $00
    !byte $01, $09, $00
    !byte $00, $9a, $00
    !byte $00, $de, $20
    !byte $0e, $7f, $c0
    !byte $07, $ff, $80
    !byte $01, $fe, $00
    !byte $00, $ff, $e0
    !byte $0f, $ff, $80
    !byte $01, $fe, $00
    !byte $03, $ff, $00
    !byte $07, $ff, $80
    !byte $0c, $fe, $c0
    !byte $00, $ba, $20
    !byte $01, $31, $00
    !byte $00, $10, $00
    !byte $00, $10, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 18: Explosion Frame 1 (Monochrome Hi-Res)
; ------------------------------------------------------------------------------
g_sprite_explosion_1:
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $18, $00
    !byte $00, $7e, $00
    !byte $01, $bd, $80
    !byte $03, $ff, $c0
    !byte $07, $ff, $e0
    !byte $0f, $ff, $f0
    !byte $1f, $ff, $f8
    !byte $3f, $ff, $fc
    !byte $1f, $ff, $f8
    !byte $0f, $ff, $f0
    !byte $07, $ff, $e0
    !byte $03, $ff, $c0
    !byte $01, $bd, $80
    !byte $00, $7e, $00
    !byte $00, $18, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 19: Explosion Frame 2 (Monochrome Hi-Res)
; ------------------------------------------------------------------------------
g_sprite_explosion_2:
    !byte $00, $18, $00
    !byte $08, $7e, $10
    !byte $04, $ff, $20
    !byte $31, $ff, $8c
    !byte $17, $ff, $e8
    !byte $0f, $ff, $f0
    !byte $3f, $ff, $fc
    !byte $77, $ff, $ee
    !byte $fc, $ff, $3f
    !byte $79, $ff, $9e
    !byte $fd, $ff, $bf
    !byte $79, $ff, $9e
    !byte $fc, $ff, $3f
    !byte $77, $ff, $ee
    !byte $3f, $ff, $fc
    !byte $0f, $ff, $f0
    !byte $17, $ff, $e8
    !byte $31, $ff, $8c
    !byte $04, $ff, $20
    !byte $08, $7e, $10
    !byte $00, $18, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 20: Explosion Frame 3 (Monochrome Hi-Res)
; ------------------------------------------------------------------------------
g_sprite_explosion_3:
    !byte $48, $18, $12
    !byte $30, $3c, $0c
    !byte $84, $c3, $21
    !byte $03, $00, $c0
    !byte $64, $00, $26
    !byte $38, $7e, $1c
    !byte $01, $c3, $80
    !byte $93, $00, $c9
    !byte $66, $00, $66
    !byte $0c, $00, $30
    !byte $f0, $00, $0f
    !byte $0c, $00, $30
    !byte $66, $00, $66
    !byte $93, $00, $c9
    !byte $01, $c3, $80
    !byte $38, $7e, $1c
    !byte $64, $00, $26
    !byte $03, $00, $c0
    !byte $84, $c3, $21
    !byte $30, $3c, $0c
    !byte $48, $18, $12
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Table of pointers to all 20 sprite blocks (low/high bytes)
; ------------------------------------------------------------------------------
g_all_sprites_lo:
    !byte <g_sprite_player_ship_1
    !byte <g_sprite_player_ship_2
    !byte <g_sprite_player_ship_3
    !byte <g_sprite_enemy_1
    !byte <g_sprite_enemy_2
    !byte <g_sprite_enemy_3
    !byte <g_sprite_enemy_4
    !byte <g_sprite_enemy_5
    !byte <g_sprite_enemy_6
    !byte <g_sprite_enemy_7
    !byte <g_sprite_enemy_8
    !byte <g_sprite_player_shot_1
    !byte <g_sprite_player_shot_2
    !byte <g_sprite_player_shot_3
    !byte <g_sprite_enemy_shot_1
    !byte <g_sprite_enemy_shot_2
    !byte <g_sprite_hit_spark
    !byte <g_sprite_explosion_1
    !byte <g_sprite_explosion_2
    !byte <g_sprite_explosion_3

g_all_sprites_hi:
    !byte >g_sprite_player_ship_1
    !byte >g_sprite_player_ship_2
    !byte >g_sprite_player_ship_3
    !byte >g_sprite_enemy_1
    !byte >g_sprite_enemy_2
    !byte >g_sprite_enemy_3
    !byte >g_sprite_enemy_4
    !byte >g_sprite_enemy_5
    !byte >g_sprite_enemy_6
    !byte >g_sprite_enemy_7
    !byte >g_sprite_enemy_8
    !byte >g_sprite_player_shot_1
    !byte >g_sprite_player_shot_2
    !byte >g_sprite_player_shot_3
    !byte >g_sprite_enemy_shot_1
    !byte >g_sprite_enemy_shot_2
    !byte >g_sprite_hit_spark
    !byte >g_sprite_explosion_1
    !byte >g_sprite_explosion_2
    !byte >g_sprite_explosion_3
