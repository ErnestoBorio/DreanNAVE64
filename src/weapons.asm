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

NUM_ENERGY_COLORS   = 8         ; 8-color Energy Palette sequence length

; ------------------------------------------------------------------------------
; Shared Energy Color Palette Sequence (8 vibrant colors)
; ------------------------------------------------------------------------------
g_energy_colors:
    !byte COLOR_CYAN, COLOR_PURPLE, COLOR_YELLOW, COLOR_GREEN
    !byte COLOR_LIGHT_GREEN, COLOR_LIGHT_BLUE, COLOR_WHITE, COLOR_ORANGE

; ------------------------------------------------------------------------------
; Player Missile RAM Variables
; ------------------------------------------------------------------------------
g_missile_x:        !word 0     ; 16-bit X coordinate in VIC-II raster space (0..320)
g_missile_y:        !byte 0     ; 8-bit Y coordinate in VIC-II raster space
g_missile_active:   !byte 0     ; 1 = In flight, 0 = Inactive, >1 = Hit spark countdown
g_spark_color:      !byte COLOR_WHITE ; Current hit spark energy color
g_fire_cooldown:    !byte 0     ; Cooldown counter between shots (frames)
g_energy_cycle_idx: !byte 0     ; Current index in Energy palette sequence (0..6)
g_fire_requested:   !byte 0     ; Latched fire trigger flag (1 = Pending shot)
s_shot_spawn_offset: !byte 0    ; Temporary randomized spawn X offset

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

    ; Position missile at ship nose with randomized offset: 8 + (rand & 15) -> 8..23 pixels
    jsr starfield_rand
    and #$0f                    ; 0..15
    clc
    adc #8                      ; 8..23 pixels forward (tightly emerging from ship)
    sta s_shot_spawn_offset

    ldx g_player_phase
    dex                         ; 1..5 -> 0..4

    ; Compute 16-bit X coordinate
    lda s_shot_spawn_offset
    clc
    adc shot_spawn_x_extra, x
    clc
    adc g_player_x + 0
    sta g_missile_x + 0
    lda g_player_x + 1
    adc #0
    sta g_missile_x + 1

    ; Compute 8-bit Y coordinate aligned to each phase's cannons/nose
    lda g_player_y
    clc
    adc shot_spawn_y_offset, x
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
    ; 1. Advance Energy palette index each frame (0..7)
    inc g_energy_cycle_idx
    lda g_energy_cycle_idx
    and #$07
    sta g_energy_cycle_idx

    ; 2. Decrement fire cooldown timer
    lda g_fire_cooldown
    beq +
    dec g_fire_cooldown
+

    ; 3. Move existing active missile rightward or update hit spark countdown
    lda g_missile_active
    beq @check_fire_latch
    cmp #1
    bne @update_hit_spark

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
    beq @check_fire_latch

@update_hit_spark:
    dec g_missile_active
    lda g_missile_active
    cmp #1
    beq @despawn_missile

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
    ; Check if missile or hit spark is active
    lda g_missile_active
    bne @render_active

    ; Inactive: disable Sprite 1 ($D015 Bit 1 = 0), clear MSB, clear Scaling
    sei
    lda VIC_SPR_ENABLE
    and #$fd
    sta VIC_SPR_ENABLE
    lda VIC_SPR_MSB
    and #$fd
    sta VIC_SPR_MSB
    lda VIC_SPR_EXP_X
    and #$fd
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    and #$fd
    sta VIC_SPR_EXP_Y
    cli
    rts

@render_active:
    ; 1. Enable Sprite 1 in VIC-II ($D015 Bit 1 = 1)
    sei
    lda VIC_SPR_ENABLE
    ora #$02
    sta VIC_SPR_ENABLE
    cli

    ; Check if in hit spark mode (g_missile_active > 1)
    lda g_missile_active
    cmp #1
    beq @render_missile

    ; Hit Spark: Block 211 (SPRITE_PTR_HIT_SPARK), Random Energy Color, Never Scaled
    sei
    lda VIC_SPR_EXP_X
    and #$fd
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    and #$fd
    sta VIC_SPR_EXP_Y
    cli

    lda #SPRITE_PTR_HIT_SPARK
    sta SPRITE_PTRS + 1
    lda g_spark_color
    sta VIC_SPR1_COLOR
    bne @write_coords

@render_missile:
    ; 2. Select Sprite 1 Pointer based on player phase (1..5 -> 0..4)
    ldx g_player_phase
    dex
    lda player_phase_shot_sprite, x
    sta SPRITE_PTRS + 1

    ; 3. Configure Hardware Scaling (X/Y Expansion) for Sprite 1
    lda player_phase_scaled, x
    beq @unscaled_shot

    sei
    lda VIC_SPR_EXP_X
    ora #$02
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    ora #$02
    sta VIC_SPR_EXP_Y
    cli
    jmp @color_shot

@unscaled_shot:
    sei
    lda VIC_SPR_EXP_X
    and #$fd
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    and #$fd
    sta VIC_SPR_EXP_Y
    cli

@color_shot:
    ; 4. Set Sprite 1 color from current Energy Palette cycling index
    ldx g_energy_cycle_idx
    lda g_energy_colors, x
    sta VIC_SPR1_COLOR

@write_coords:
    ; 5. Write Sprite 1 X low byte ($D002) and Y byte ($D003)
    lda g_missile_x + 0
    sta VIC_SPR1_X
    lda g_missile_y
    sta VIC_SPR1_Y

    ; 6. Set or clear Bit 1 of VIC_SPR_MSB ($D010) based on 16-bit missile X
    sei
    lda VIC_SPR_MSB
    ldy g_missile_x + 1
    beq +
    ora #$02
    bne ++
+   and #$fd
++  sta VIC_SPR_MSB
    cli
    rts

; ------------------------------------------------------------------------------
; Shot Spawn Coordinate Offset Tables by Phase (Phases 1..5 -> Index 0..4)
; ------------------------------------------------------------------------------
shot_spawn_y_offset:
    !byte 3, 4, 1, 8, 2

shot_spawn_x_extra:
    !byte 0, 0, 0, 20, 20
