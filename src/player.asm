; ==============================================================================
; PLAYER.ASM - Player Ship Entity & Render Subsystem
; ==============================================================================
; Manages the player ship coordinates (X: 16-bit, Y: 8-bit), 8-way directional
; movement, VIC-II Hardware Sprite 0 configuration, and color setup.
; ==============================================================================

PLAYER_SPRITE_BLOCK = 128     ; Block 128 ($2000 / 64 = 128)

; ------------------------------------------------------------------------------
; Player Entity Data RAM Variables
; ------------------------------------------------------------------------------
g_player_x:         !word 60  ; 16-bit X-coordinate (0..320)
g_player_y:         !byte 120 ; 8-bit Y-coordinate (50..240)
g_player_alive:     !byte 1   ; 1 = Alive, 0 = Dead
g_player_power:     !byte 0   ; Power-up level (0..3)

; ==============================================================================
; Subroutine: player_init
; Purpose: Copies player ship sprite data into VIC-II RAM ($2000) and initializes
;          Sprite 0 hardware registers (Multicolor, colors, pointers).
; ==============================================================================
player_init:
    ; 1. Reset player coordinates & state
    lda #60
    sta g_player_x
    lda #0
    sta g_player_x + 1
    lda #120
    sta g_player_y
    lda #1
    sta g_player_alive
    lda #0
    sta g_player_power

    ; 2. Copy 64 bytes of g_sprite_player_ship into VIC-II Sprite RAM ($2000)
    ldx #0
@copy_loop:
    lda g_sprite_player_ship, x
    sta $2000, x
    inx
    cpx #64
    bne @copy_loop

    ; 3. Set Sprite 0 pointer at $07F8 to block 128 ($2000 / 64 = 128)
    lda #PLAYER_SPRITE_BLOCK
    sta SPRITE_PTRS + 0

    ; 4. Enable Sprite 0 in VIC-II Enable Register ($D015)
    lda VIC_SPR_ENABLE
    ora #$01
    sta VIC_SPR_ENABLE

    ; 5. Enable Multicolor mode for Sprite 0 in VIC-II ($D01C)
    lda VIC_SPR_MULTICOLOR
    ora #$01
    sta VIC_SPR_MULTICOLOR

    ; 6. Configure Sprite Colors for Multicolor Mode:
    ; %10 (Individual Color) = Cyan
    ; %01 (Shared MC0 Color) = White
    ; %11 (Shared MC1 Color) = Dark Gray
    lda #COLOR_CYAN
    sta VIC_SPR0_COLOR
    lda #COLOR_WHITE
    sta VIC_SPR_MC0
    lda #COLOR_DARK_GRAY
    sta VIC_SPR_MC1

    ; 7. Disable Y-expansion for Sprite 0 ($D017)
    lda VIC_SPR_EXP_Y
    and #$fe
    sta VIC_SPR_EXP_Y
    rts

; ==============================================================================
; Subroutine: player_update
; Purpose: Applies directional input vectors to player coordinates and enforces
;          playfield screen boundaries (SPRITE_MIN_X..SPRITE_MAX_X, MIN_Y..MAX_Y).
; ==============================================================================
player_update:
    lda g_player_alive
    bne +
    rts                         ; If player is dead, return immediately
+
    ; Movement speed = 2 pixels per frame
    ; --- Check Move Up ---
    lda g_input_up
    beq @check_down
    lda g_player_y
    sec
    sbc #2
    cmp #SPRITE_MIN_Y
    bcs +
    lda #SPRITE_MIN_Y           ; Clamp to top border
+   sta g_player_y

@check_down:
    ; --- Check Move Down ---
    lda g_input_down
    beq @check_left
    lda g_player_y
    clc
    adc #2
    cmp #SPRITE_MAX_Y
    bcc +
    lda #SPRITE_MAX_Y           ; Clamp to bottom border
+   sta g_player_y

@check_left:
    ; --- Check Move Left ---
    lda g_input_left
    beq @check_right
    lda g_player_x
    sec
    sbc #2
    sta g_player_x
    lda g_player_x + 1
    sbc #0
    sta g_player_x + 1

    ; Clamp to left screen boundary (SPRITE_MIN_X = 24)
    lda g_player_x + 1
    bne @check_right            ; If MSB > 0, X > 255, so definitely > 24
    lda g_player_x
    cmp #SPRITE_MIN_X
    bcs @check_right
    lda #SPRITE_MIN_X
    sta g_player_x
    lda #0
    sta g_player_x + 1

@check_right:
    ; --- Check Move Right ---
    lda g_input_right
    beq @update_done
    lda g_player_x
    clc
    adc #2
    sta g_player_x
    lda g_player_x + 1
    adc #0
    sta g_player_x + 1

    ; Clamp to right screen boundary (SPRITE_MAX_X = 320 -> MSB=1, LSB=64)
    lda g_player_x + 1
    cmp #1
    bcc @update_done            ; If MSB == 0, X < 256, so definitely < 320
    lda g_player_x
    cmp #64                     ; 320 - 256 = 64
    bcc @update_done
    lda #64
    sta g_player_x
    lda #1
    sta g_player_x + 1

@update_done:
    rts

; ==============================================================================
; Subroutine: player_render
; Purpose: Writes player X/Y coordinates and MSB bit 0 to VIC-II hardware registers.
; ==============================================================================
player_render:
    ; Write Sprite 0 X-coordinate low byte to $D000
    lda g_player_x
    sta VIC_SPR0_X

    ; Write Sprite 0 Y-coordinate byte to $D001
    lda g_player_y
    sta VIC_SPR0_Y

    ; Set or Clear Bit 0 of VIC_SPR_MSB ($D010) based on g_player_x high byte
    lda g_player_x + 1
    beq @clear_msb
    lda VIC_SPR_MSB
    ora #$01                    ; Set MSB Bit 0 (X >= 256)
    sta VIC_SPR_MSB
    rts

@clear_msb:
    lda VIC_SPR_MSB
    and #$fe                    ; Clear MSB Bit 0 (X < 256)
    sta VIC_SPR_MSB
    rts
