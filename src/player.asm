; ==============================================================================
; PLAYER.ASM - Player Ship Entity & Hardware Sprite Subsystem (Phase 2)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
;
; Manages the player ship state, 8-way directional motion, screen boundary
; clamping, and VIC-II Hardware Sprite 0 configuration in multicolor mode.
; ==============================================================================

PLAYER_SPRITE_BLOCK = 128       ; Base sprite block in VIC-II RAM ($2000 / 64 = 128)
PLAYER_SPEED        = 3         ; Player movement speed (pixels per frame at 50 Hz PAL)

; ------------------------------------------------------------------------------
; Player Entity Data RAM Variables
; ------------------------------------------------------------------------------
g_player_x:         !word 60    ; 16-bit X coordinate in VIC-II raster space (24..320)
g_player_y:         !byte 120   ; 8-bit Y coordinate in VIC-II raster space (50..240)
g_player_alive:     !byte 1     ; Player life state (1 = Alive, 0 = Destroyed)
g_player_power:     !byte 0     ; Power-up stage (0 = Ship 1, 1 = Ship 2, 2 = Ship 3)

; ==============================================================================
; Subroutine: player_init
; Purpose: Initializes player state, copies sprite data to VIC-II RAM ($2000),
;          and configures VIC-II Hardware Sprite 0 registers.
; ==============================================================================
player_init:
    ; 1. Initialize player state variables
    lda #0
    sta g_player_x + 1
    sta g_player_power
    lda #60
    sta g_player_x + 0
    lda #120
    sta g_player_y
    lda #1
    sta g_player_alive

    ; 2. Set Sprite 0 pointer at $07F8 to point to Player Ship Stage 1 (Block 128)
    ;    (Sprite data is assembled directly at VIC-II Sprite RAM $2000 - $23FF)
    lda #PLAYER_SPRITE_BLOCK
    sta SPRITE_PTRS + 0

    ; 4. Enable Hardware Sprite 0 in VIC-II ($D015)
    lda VIC_SPR_ENABLE
    ora #$01
    sta VIC_SPR_ENABLE

    ; 5. Enable Multicolor mode for Sprite 0 ($D01C)
    lda VIC_SPR_MULTICOLOR
    ora #$01
    sta VIC_SPR_MULTICOLOR

    ; 6. Disable X and Y expansion for Sprite 0 ($D017, $D01D)
    lda VIC_SPR_EXP_X
    and #$fe
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    and #$fe
    sta VIC_SPR_EXP_Y

    ; 7. Set Sprite 0 priority in front of background ($D01B)
    lda VIC_SPR_PRIORITY
    and #$fe
    sta VIC_SPR_PRIORITY

    ; 8. Configure VIC-II Sprite Colors:
    ;    %10 (Individual Color) = Cyan ($03)
    ;    %01 (Shared MC0 Color) = White ($01)
    ;    %11 (Shared MC1 Color) = Medium Gray ($0C)
    lda #COLOR_CYAN
    sta VIC_SPR0_COLOR
    lda #COLOR_WHITE
    sta VIC_SPR_MC0
    lda #COLOR_MEDIUM_GRAY
    sta VIC_SPR_MC1

    rts

; ==============================================================================
; Subroutine: player_update
; Purpose: Applies 8-way directional input vectors to player coordinates
;          and enforces strict playfield screen boundaries.
; ==============================================================================
player_update:
    ; If player is dead, skip motion processing
    lda g_player_alive
    bne +
    rts
+
    ; Movement speed: PLAYER_SPEED pixels per frame (smooth 50 Hz arcade motion)

    ; --------------------------------------------------------------------------
    ; Check Move Up (Y decrements towards top border: SPRITE_MIN_Y = 50)
    ; --------------------------------------------------------------------------
    lda g_input_up
    beq @check_down
    lda g_player_y
    sec
    sbc #PLAYER_SPEED
    cmp #SPRITE_MIN_Y
    bcs +
    lda #SPRITE_MIN_Y           ; Clamp to top visible border
+   sta g_player_y

@check_down:
    ; --------------------------------------------------------------------------
    ; Check Move Down (Y increments towards bottom border: SPRITE_MAX_Y = 240)
    ; --------------------------------------------------------------------------
    lda g_input_down
    beq @check_left
    lda g_player_y
    clc
    adc #PLAYER_SPEED
    cmp #SPRITE_MAX_Y
    bcc +
    lda #SPRITE_MAX_Y           ; Clamp to bottom visible border
+   sta g_player_y

@check_left:
    ; --------------------------------------------------------------------------
    ; Check Move Left (16-bit X decrements towards left border: SPRITE_MIN_X = 24)
    ; --------------------------------------------------------------------------
    lda g_input_left
    beq @check_right
    lda g_player_x + 0
    sec
    sbc #PLAYER_SPEED
    sta g_player_x + 0
    lda g_player_x + 1
    sbc #0
    sta g_player_x + 1

    ; Clamp to left boundary: if MSB == 0 and LSB < 24, clamp to 24
    lda g_player_x + 1
    bne @check_right            ; If MSB > 0, X >= 256 (safe)
    lda g_player_x + 0
    cmp #SPRITE_MIN_X
    bcs @check_right
    lda #SPRITE_MIN_X
    sta g_player_x + 0
    lda #0
    sta g_player_x + 1

@check_right:
    ; --------------------------------------------------------------------------
    ; Check Move Right (16-bit X increments towards right border: SPRITE_MAX_X = 320)
    ; 320 = $0140 (MSB = 1, LSB = 64)
    ; --------------------------------------------------------------------------
    lda g_input_right
    beq @update_done
    lda g_player_x + 0
    clc
    adc #PLAYER_SPEED
    sta g_player_x + 0
    lda g_player_x + 1
    adc #0
    sta g_player_x + 1

    ; Clamp to right boundary: if MSB >= 1 and LSB >= 64, clamp to (1, 64)
    lda g_player_x + 1
    cmp #1
    bcc @update_done            ; If MSB == 0, X < 256 (safe)
    lda g_player_x + 0
    cmp #64                     ; 320 - 256 = 64
    bcc @update_done
    lda #64
    sta g_player_x + 0
    lda #1
    sta g_player_x + 1

@update_done:
    rts

; ==============================================================================
; Subroutine: player_render
; Purpose: Updates Sprite 0 hardware registers (X, Y, MSB, Pointer).
; ==============================================================================
player_render:
    ; 1. Check player life state
    lda g_player_alive
    bne @render_active

    ; Player destroyed: disable Hardware Sprite 0
    sei
    lda VIC_SPR_ENABLE
    and #$fe
    sta VIC_SPR_ENABLE
    cli
    rts

@render_active:
    ; Ensure Hardware Sprite 0 is enabled
    sei
    lda VIC_SPR_ENABLE
    ora #$01
    sta VIC_SPR_ENABLE
    cli

    ; 2. Select Sprite 0 Pointer based on current power level:
    ;    Stage 1: Block 128
    ;    Stage 2: Block 129
    ;    Stage 3: Block 130
    lda #PLAYER_SPRITE_BLOCK
    clc
    adc g_player_power
    sta SPRITE_PTRS + 0

    ; 3. Write X coordinate low byte to VIC-II Sprite 0 X Register ($D000)
    lda g_player_x + 0
    sta VIC_SPR0_X

    ; 4. Write Y coordinate byte to VIC-II Sprite 0 Y Register ($D001)
    lda g_player_y
    sta VIC_SPR0_Y

    ; 5. Set or clear Bit 0 of VIC_SPR_MSB ($D010) based on 16-bit X MSB
    lda g_player_x + 1
    beq @clear_msb

    ; Set Bit 0 (X >= 256)
    sei
    lda VIC_SPR_MSB
    ora #$01
    sta VIC_SPR_MSB
    cli
    rts

@clear_msb:
    ; Clear Bit 0 (X < 256)
    sei
    lda VIC_SPR_MSB
    and #$fe
    sta VIC_SPR_MSB
    cli
    rts

