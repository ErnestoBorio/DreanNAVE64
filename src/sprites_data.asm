; ==============================================================================
; SPRITES_DATA.ASM - Complete 16 Hardware Sprite Definitions
; ==============================================================================
; Total: 16 Sprites x 64 bytes = 1,024 bytes ($0400)
; Each sprite consists of 63 data bytes (21 rows x 3 bytes) + 1 padding byte.
; ==============================================================================

; ------------------------------------------------------------------------------
; Sprite Block Pointer Indices (Assuming Base $2000 / Block 128)
; ------------------------------------------------------------------------------
SPRITE_PTR_PLAYER_SHIP_1   = 128  ; Sprite 1: Player Ship Stage 1 (Multicolor)
SPRITE_PTR_PLAYER_SHIP_2   = 129  ; Sprite 2: Player Ship Stage 2 (Multicolor)
SPRITE_PTR_PLAYER_SHIP_3   = 130  ; Sprite 3: Player Ship Stage 3 (Multicolor)
SPRITE_PTR_ENEMY_1         = 131  ; Sprite 4: Enemy Ship 1 (Multicolor)
SPRITE_PTR_ENEMY_2         = 132  ; Sprite 5: Enemy Ship 2 (Multicolor)
SPRITE_PTR_ENEMY_3         = 133  ; Sprite 6: Enemy Ship 3 (Multicolor)
SPRITE_PTR_ENEMY_4         = 134  ; Sprite 7: Enemy Ship 4 (Multicolor)
SPRITE_PTR_ENEMY_5         = 135  ; Sprite 8: Enemy Ship 5 (Multicolor)
SPRITE_PTR_ENEMY_6         = 136  ; Sprite 9: Enemy Ship 6 (Multicolor)
SPRITE_PTR_ENEMY_7         = 137  ; Sprite 10: Enemy Ship 7 (Multicolor)
SPRITE_PTR_ENEMY_8         = 138  ; Sprite 11: Enemy Ship 8 (Multicolor)
SPRITE_PTR_PLAYER_SHOT_1   = 139  ; Sprite 12: Player Shot Level 1 (Monochrome Hi-Res)
SPRITE_PTR_PLAYER_SHOT_2   = 140  ; Sprite 13: Player Shot Level 2 (Monochrome Hi-Res Dual)
SPRITE_PTR_PLAYER_SHOT_3   = 141  ; Sprite 14: Player Shot Level 3 (Monochrome Hi-Res Triple)
SPRITE_PTR_ENEMY_SHOT_1    = 142  ; Sprite 15: Enemy Shot 1 (Monochrome Hi-Res Single)
SPRITE_PTR_ENEMY_SHOT_2    = 143  ; Sprite 16: Enemy Shot 2 (Monochrome Hi-Res Spread)

; Default alias for primary player ship
SPRITE_PTR_PLAYER_SHIP     = 128

; ------------------------------------------------------------------------------
; Sprite 1: Player Ship Stage 1 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_player_ship_1:
    !byte $30, $00, $00
    !byte $dc, $00, $00
    !byte $57, $00, $00
    !byte $d9, $c0, $00
    !byte $1a, $70, $00
    !byte $d9, $c0, $00
    !byte $57, $00, $00
    !byte $dc, $00, $00
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
    !byte $14, $75, $40
    !byte $55, $5c, $40
    !byte $d7, $67, $10
    !byte $03, $69, $c7
    !byte $d7, $67, $10
    !byte $55, $5c, $40
    !byte $14, $75, $40
    !byte $03, $f5, $5c
    !byte $05, $4d, $00
    !byte $35, $00, $00
    !byte $14, $00, $00
    !byte $14, $00, $00
    !byte $10, $00, $00
    !byte $1d, $5c, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 3: Player Ship Stage 3 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_player_ship_3:
    !byte $00, $75, $70
    !byte $1c, $40, $00
    !byte $57, $50, $00
    !byte $57, $53, $57
    !byte $1c, $55, $c0
    !byte $00, $d5, $30
    !byte $00, $0f, $d0
    !byte $50, $d1, $d4
    !byte $d4, $55, $71
    !byte $55, $dd, $9c
    !byte $dd, $0d, $a7
    !byte $55, $dd, $9c
    !byte $d4, $55, $71
    !byte $50, $d1, $d4
    !byte $00, $0f, $d0
    !byte $00, $d5, $30
    !byte $1c, $55, $c0
    !byte $57, $53, $57
    !byte $57, $50, $00
    !byte $1c, $40, $00
    !byte $00, $75, $70
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 4: Enemy Ship 1 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_1:
    !byte $00, $33, $00
    !byte $00, $dd, $c0
    !byte $0d, $54, $00
    !byte $00, $34, $70
    !byte $03, $59, $c0
    !byte $d5, $a9, $00
    !byte $03, $59, $c0
    !byte $00, $34, $70
    !byte $0d, $54, $00
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
; Sprite 6: Enemy Ship 3 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_3:
    !byte $00, $00, $10
    !byte $00, $f5, $dc
    !byte $00, $00, $10
    !byte $00, $00, $50
    !byte $00, $00, $50
    !byte $00, $01, $7c
    !byte $00, $05, $d7
    !byte $00, $d7, $7c
    !byte $01, $ae, $50
    !byte $d6, $aa, $bc
    !byte $01, $ae, $50
    !byte $00, $d7, $7c
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
; Sprite 7: Enemy Ship 4 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_4:
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
; Sprite 8: Enemy Ship 5 (Multicolor)
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
    !byte $01, $aa, $57
    !byte $03, $69, $70
    !byte $d5, $55, $c0
    !byte $00, $15, $70
    !byte $00, $37, $00
    !byte $00, $04, $00
    !byte $30, $d5, $c3
    !byte $05, $55, $54
    !byte $0d, $55, $5c
    !byte $03, $55, $70
    !byte $00, $3f, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 9: Enemy Ship 6 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_6:
    !byte $0d, $04, $30
    !byte $03, $8e, $08
    !byte $00, $61, $04
    !byte $d4, $12, $38
    !byte $0a, $21, $24
    !byte $01, $ba, $20
    !byte $00, $e7, $90
    !byte $80, $99, $00
    !byte $2b, $b6, $b0
    !byte $dd, $95, $6b
    !byte $dd, $b6, $b0
    !byte $2b, $99, $00
    !byte $80, $e7, $80
    !byte $00, $3a, $90
    !byte $01, $a2, $20
    !byte $0a, $11, $20
    !byte $d4, $22, $18
    !byte $00, $61, $34
    !byte $03, $8e, $08
    !byte $0d, $04, $04
    !byte $00, $00, $30
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Sprite 10: Enemy Ship 7 (Multicolor)
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
; Sprite 11: Enemy Ship 8 (Multicolor)
; ------------------------------------------------------------------------------
g_sprite_enemy_8:
    !byte $00, $00, $00
    !byte $00, $00, $04
    !byte $04, $00, $07
    !byte $34, $00, $35
    !byte $17, $00, $d0
    !byte $01, $c1, $70
    !byte $00, $f5, $5c
    !byte $0f, $56, $97
    !byte $35, $d6, $55
    !byte $17, $55, $55
    !byte $15, $dd, $55
    !byte $17, $55, $55
    !byte $35, $d6, $55
    !byte $0f, $56, $97
    !byte $00, $f5, $5c
    !byte $01, $c1, $70
    !byte $17, $00, $d0
    !byte $34, $00, $35
    !byte $04, $00, $07
    !byte $00, $00, $04
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
    !byte $38, $00, $00
    !byte $74, $00, $00
    !byte $fa, $00, $00
    !byte $fe, $00, $00
    !byte $be, $00, $00
    !byte $5c, $00, $00
    !byte $38, $00, $00
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
    !byte $00, $1c, $00
    !byte $00, $3a, $00
    !byte $00, $7d, $00
    !byte $00, $7f, $00
    !byte $00, $5f, $00
    !byte $00, $2e, $00
    !byte $38, $1c, $00
    !byte $74, $00, $00
    !byte $fa, $00, $00
    !byte $fe, $00, $00
    !byte $be, $00, $00
    !byte $5c, $00, $00
    !byte $38, $1c, $00
    !byte $00, $3a, $00
    !byte $00, $7d, $00
    !byte $00, $7f, $00
    !byte $00, $5f, $00
    !byte $00, $2e, $00
    !byte $00, $1c, $00
    !byte $00, $00, $00
    !byte $00, $00, $00
    !byte $00                  ; 64th padding byte

; ------------------------------------------------------------------------------
; Table of pointers to all 16 sprite blocks (low/high bytes)
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
