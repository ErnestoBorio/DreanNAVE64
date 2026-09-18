; ==============================================================================
; WEAPONS.ASM - Player Weapons & Missile Subsystem (Phase 3)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
;
; Manages:
; - Latched single-shot fire requests (zero dropped taps, no unwanted auto-fire)
; - Ultra-high speed 50 pixels/frame rightward missile movement
; - Right playfield border recycling (X >= 320) with overflow protection
; - 7-color per-frame Energy palette sequence cycling
; - VIC-II Hardware Sprite 1 configuration in hi-res monochrome mode
; ==============================================================================

NUM_ENERGY_COLORS   = 7         ; 7-color Energy Palette sequence length

; ------------------------------------------------------------------------------
; Energy Color Palette Sequence
; (Cyan, Purple/Pink, Yellow, Green, Light Green, Light Blue, Light Gray)
; ------------------------------------------------------------------------------
g_energy_colors:
    !byte COLOR_CYAN            ; Color 0: Cyan (3)
    !byte COLOR_PURPLE          ; Color 1: Purple/Pink (4)
    !byte COLOR_YELLOW          ; Color 2: Yellow (7)
    !byte COLOR_GREEN           ; Color 3: Dark Green (5)
    !byte COLOR_LIGHT_GREEN     ; Color 4: Light Green (13)
    !byte COLOR_LIGHT_BLUE      ; Color 5: Light Blue (14)
    !byte COLOR_LIGHT_GRAY      ; Color 6: Light Gray (15)

; ------------------------------------------------------------------------------
; Player Missile RAM Variables
; ------------------------------------------------------------------------------
g_missile_x:        !word 0     ; 16-bit X coordinate in VIC-II raster space (0..320)
g_missile_y:        !byte 0     ; 8-bit Y coordinate in VIC-II raster space
g_missile_active:   !byte 0     ; 1 = In flight, 0 = Inactive
g_fire_cooldown:    !byte 0     ; Cooldown counter between shots (frames)
g_energy_cycle_idx: !byte 0     ; Current index in Energy palette sequence (0..6)
g_fire_requested:   !byte 0     ; Latched fire trigger flag (1 = Pending shot)

; ==============================================================================
; Subroutine: weapons_init
; Purpose: Resets missile state, palette cycling index, and disables Sprite 1.
; ==============================================================================
weapons_init:
    ; 1. Reset all missile state variables
    lda #0
    sta g_missile_x + 0
    sta g_missile_x + 1
    sta g_missile_y
    sta g_missile_active
    sta g_fire_cooldown
    sta g_energy_cycle_idx
    sta g_fire_requested

    ; 2. Disable Hardware Sprite 1 initially ($D015 Bit 1 = 0)
    lda VIC_SPR_ENABLE
    and #$fd
    sta VIC_SPR_ENABLE

    ; 3. Ensure Sprite 1 is in Hi-Res Monochrome mode ($D01C Bit 1 = 0)
    lda VIC_SPR_MULTICOLOR
    and #$fd
    sta VIC_SPR_MULTICOLOR

    ; 4. Disable X/Y expansion for Sprite 1 ($D017, $D01D Bit 1 = 0)
    lda VIC_SPR_EXP_X
    and #$fd
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    and #$fd
    sta VIC_SPR_EXP_Y

    ; 5. Set Sprite 1 priority in front of background ($D01B Bit 1 = 0)
    lda VIC_SPR_PRIORITY
    and #$fd
    sta VIC_SPR_PRIORITY

    rts

; ==============================================================================
; Subroutine: weapons_fire
; Purpose: Spawns a new player missile aligned with ship nose if slot is free.
; ==============================================================================
weapons_fire:
    ; Check if cooldown is active or player is dead
    lda g_fire_cooldown
    bne @fire_exit
    lda g_player_alive
    beq @fire_exit

    ; Check if missile slot is already active (single missile in flight)
    lda g_missile_active
    bne @fire_exit

    ; Activate missile
    lda #1
    sta g_missile_active

    ; Position missile at ship nose: X = player_x + 22, Y = player_y + 3
    lda g_player_x + 0
    clc
    adc #22
    sta g_missile_x + 0
    lda g_player_x + 1
    adc #0
    sta g_missile_x + 1

    lda g_player_y
    clc
    adc #3
    sta g_missile_y

    ; Set fire cooldown = 6 frames (~8.3 shots per second max rate)
    lda #6
    sta g_fire_cooldown

    ; Consume latched fire request
    lda #0
    sta g_fire_requested

@fire_exit:
    rts

; ==============================================================================
; Subroutine: weapons_update
; Purpose: Cycles Energy color palette, advances active missile by 50 px/frame,
;          recycles missile when X >= 320, and processes latched fire requests.
; ==============================================================================
weapons_update:
    ; 1. Advance Energy palette index each frame (0..6)
    inc g_energy_cycle_idx
    lda g_energy_cycle_idx
    cmp #NUM_ENERGY_COLORS
    bcc +
    lda #0
    sta g_energy_cycle_idx
+

    ; 2. Decrement fire cooldown timer
    lda g_fire_cooldown
    beq +
    dec g_fire_cooldown
+

    ; 3. Move existing active missile rightward before checking new triggers
    lda g_missile_active
    beq @check_fire_latch

    ; Add 50 pixels to 16-bit missile X coordinate
    lda g_missile_x + 0
    clc
    adc #50
    sta g_missile_x + 0
    lda g_missile_x + 1
    adc #0
    sta g_missile_x + 1

    ; Check if missile reached or exited right playfield border (X >= 320)
    ; 320 = $0140 (MSB = 1, LSB = 64)
    lda g_missile_x + 1
    beq @check_fire_latch       ; If MSB == 0, X < 256 (in playfield)
    cmp #1
    bne @despawn_missile        ; If MSB > 1, X >= 512 -> Despawn immediately!

    ; MSB == 1: check if LSB >= 64 (X >= 320)
    lda g_missile_x + 0
    cmp #64
    bcc @check_fire_latch       ; LSB < 64 -> X < 320 (in playfield)

@despawn_missile:
    ; Despawn missile when reaching right border
    lda #0
    sta g_missile_active

@check_fire_latch:
    ; 4. Latch new single-shot keydown event (strictly single-shot: 1 shot per tap, NO auto-fire)
    ; Acknowledge/clear VIC-II hardware collision latches
    bit VIC_SPR_COLL_SPR
    bit VIC_SPR_COLL_BG

    lda g_input_fire_pressed
    beq @check_pending
    lda #1
    sta g_fire_requested

    ; 5. Execute latched fire request if available
@check_pending:
    lda g_fire_requested
    beq @update_done
    jsr weapons_fire

@update_done:
    rts

; ==============================================================================
; Subroutine: weapons_render
; Purpose: Configures Sprite 1 registers (pointer, active Energy color, X/Y, MSB).
; ==============================================================================
weapons_render:
    ; Check if missile is active
    lda g_missile_active
    bne @render_active

    ; Missile inactive: disable Sprite 1 ($D015 Bit 1 = 0) and clear Sprite 1 MSB ($D010 Bit 1 = 0)
    sei
    lda VIC_SPR_ENABLE
    and #$fd
    sta VIC_SPR_ENABLE
    lda VIC_SPR_MSB
    and #$fd
    sta VIC_SPR_MSB
    cli
    rts

@render_active:
    ; 1. Enable Sprite 1 in VIC-II ($D015 Bit 1 = 1)
    sei
    lda VIC_SPR_ENABLE
    ora #$02
    sta VIC_SPR_ENABLE
    cli

    ; 2. Select Sprite 1 Pointer based on player power stage:
    ;    Stage 1: Block 139 (SPRITE_PTR_PLAYER_SHOT_1)
    ;    Stage 2: Block 140 (SPRITE_PTR_PLAYER_SHOT_2)
    ;    Stage 3: Block 141 (SPRITE_PTR_PLAYER_SHOT_3)
    lda #SPRITE_PTR_PLAYER_SHOT_1
    clc
    adc g_player_power
    sta SPRITE_PTRS + 1

    ; 3. Set Sprite 1 color from current Energy Palette cycling index
    ldx g_energy_cycle_idx
    lda g_energy_colors, x
    sta VIC_SPR1_COLOR

    ; 4. Write Sprite 1 X low byte ($D002) and Y byte ($D003)
    lda g_missile_x + 0
    sta VIC_SPR1_X
    lda g_missile_y
    sta VIC_SPR1_Y

    ; 5. Set or clear Bit 1 of VIC_SPR_MSB ($D010) based on 16-bit missile X
    lda g_missile_x + 1
    beq @clear_msb1

    ; Set Bit 1 (X >= 256)
    sei
    lda VIC_SPR_MSB
    ora #$02
    sta VIC_SPR_MSB
    cli
    rts

@clear_msb1:
    ; Clear Bit 1 (X < 256)
    sei
    lda VIC_SPR_MSB
    and #$fd
    sta VIC_SPR_MSB
    cli
    rts
