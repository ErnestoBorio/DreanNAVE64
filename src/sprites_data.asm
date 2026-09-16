; ==============================================================================
; SPRITES_DATA.ASM - Monochrome & Multicolor Hardware Sprite Definitions
; ==============================================================================
; Each VIC-II hardware sprite definition consists of 63 bitmap data bytes
; arranged as 21 rows of 3 bytes (24 pixels width x 21 pixels height), plus
; 1 padding byte to fill a 64-byte aligned VIC-II sprite memory block.
; ==============================================================================

; ------------------------------------------------------------------------------
; g_sprite_player_ship (Multicolor Player Ship, 64 bytes)
; ------------------------------------------------------------------------------
g_sprite_player_ship:
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
; g_sprite_player_shot_1 (Hi-Res Monochrome Player Missile, 64 bytes)
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

