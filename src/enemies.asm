; ==============================================================================
; ENEMIES.ASM - 3-Lane Enemy Waves & Motion Subsystem (Phase 5)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
;
; Features:
; - 3 non-overlapping vertical lanes (Thirds of the screen):
;     Lane 0 (Top Third):    Y = 50..110  (Rows 1..8)
;     Lane 1 (Middle Third): Y = 115..175 (Rows 9..16)
;     Lane 2 (Bottom Third): Y = 180..240 (Rows 17..24)
; - Up to 3 simultaneous enemies per lane (9 active enemies total in pool).
; - Raster-multiplexed across Hardware Sprites 2, 3, 4:
;     At Line 0:   Sprites 2, 3, 4 render Lane 0 (Enemies 0..2)
;     At Line 112: Sprites 2, 3, 4 render Lane 1 (Enemies 3..5)
;     At Line 177: Sprites 2, 3, 4 render Lane 2 (Enemies 6..8)
; - Pre-loaded multicolor enemy ship sprites (Blocks 131..138).
; - Trajectories: Straight horizontal sweeps & lane-bounded sinusoidal waves.
; - Independent per-lane spawning timers.
; ==============================================================================

MAX_ENEMIES         = 9         ; 3 lanes x 3 enemies

; ------------------------------------------------------------------------------
; Enemy Pool State Variables (9 slots: 0..2 Lane 0, 3..5 Lane 1, 6..8 Lane 2)
; ------------------------------------------------------------------------------
g_enemy_active:     !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; 0 = Inactive, 1 = Active
g_enemy_x_lo:       !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; X low byte (0..255)
g_enemy_x_hi:       !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; X high bit (0 or 1)
g_enemy_y:          !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Current Y position
g_enemy_base_y:     !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Center baseline Y for wave
g_enemy_type:       !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Sprite block pointer (131..138)
g_enemy_color:      !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Individual sprite color
g_enemy_pattern:    !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; 0 = Straight, 1 = Sine wave
g_enemy_phase:      !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Sine angle index (0..31)
g_enemy_speed:      !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Pixels per frame (1 or 2)

; Per-lane wave spawn timers (Lanes 0, 1, 2)
g_lane_spawn_timer: !byte 25, 75, 125

; Enemy Reload Timers (9 slots: countdown frames between shot attempts)
g_enemy_reload_timer: !byte 60, 60, 60,  60, 60, 60,  60, 60, 60

; Enemy Slot-to-Lane Mapping (Slot 0..8 -> Lane 0, 1, or 2)
g_enemy_lane_table:   !byte 0, 0, 0,  1, 1, 1,  2, 2, 2

; ------------------------------------------------------------------------------
; Enemy Shot State Variables (3 slots: 1 bullet per lane)
; ------------------------------------------------------------------------------
MAX_ENEMY_SHOTS       = 3

g_enemy_shot_active:  !byte 0, 0, 0   ; 0 = Inactive, 1 = Active
g_enemy_shot_x_lo:    !byte 0, 0, 0   ; X low byte (0..255)
g_enemy_shot_x_hi:    !byte 0, 0, 0   ; X high bit (0 or 1)
g_enemy_shot_y:       !byte 0, 0, 0   ; Current Y position
g_enemy_shot_speed:   !byte 0, 0, 0   ; Horizontal speed (3 px/frame leftward)

NUM_ENEMY_SHOT_COLORS = 7

; ------------------------------------------------------------------------------
; Enemy Shot Energy Color Palette Sequence (Cycles each frame like player shot)
; ------------------------------------------------------------------------------
g_enemy_shot_colors:
    !byte COLOR_CYAN            ; Color 0: Cyan (3)
    !byte COLOR_PURPLE          ; Color 1: Purple/Pink (4)
    !byte COLOR_YELLOW          ; Color 2: Yellow (7)
    !byte COLOR_GREEN           ; Color 3: Dark Green (5)
    !byte COLOR_LIGHT_GREEN     ; Color 4: Light Green (13)
    !byte COLOR_LIGHT_BLUE      ; Color 5: Light Blue (14)
    !byte COLOR_LIGHT_GRAY      ; Color 6: Light Gray (15)

g_enemy_shot_cycle_idx: !byte 0 ; Current index in color sequence (0..6)

; Temporary rendering variables
s_render_lane_in:   !byte 0
s_render_base_idx:  !byte 0
s_msb_mask:         !byte 0
s_enable_mask:      !byte 0
s_reload_temp:      !byte 0

; ------------------------------------------------------------------------------
; 32-Entry Signed Sine Wave Lookup Table (Amplitude ±8 pixels, 1 full cycle)
; ------------------------------------------------------------------------------
g_enemy_sine_table:
    !byte   0,   2,   3,   4,   6,   7,   7,   8
    !byte   8,   8,   7,   7,   6,   4,   3,   2
    !byte   0,  -2,  -3,  -4,  -6,  -7,  -7,  -8
    !byte  -8,  -8,  -7,  -7,  -6,  -4,  -3,  -2

; ==============================================================================
; Subroutine: enemies_init
; Purpose: Resets all 9 enemy slots, 3 enemy shots, and configures VIC-II sprites.
; ==============================================================================
enemies_init:
    ldx #0
-   lda #0
    sta g_enemy_active, x
    sta g_enemy_x_lo, x
    sta g_enemy_x_hi, x
    sta g_enemy_y, x
    sta g_enemy_base_y, x
    sta g_enemy_pattern, x
    sta g_enemy_phase, x
    lda #60
    sta g_enemy_reload_timer, x
    inx
    cpx #MAX_ENEMIES
    bne -

    ; Reset 3 lane enemy shot slots
    ldx #0
-   lda #0
    sta g_enemy_shot_active, x
    sta g_enemy_shot_x_lo, x
    sta g_enemy_shot_x_hi, x
    sta g_enemy_shot_y, x
    sta g_enemy_shot_speed, x
    inx
    cpx #MAX_ENEMY_SHOTS
    bne -

    lda #0
    sta g_enemy_shot_cycle_idx

    ; Stagger initial spawn timers (spawns lanes 0, 1, 2 smoothly over time)
    lda #60             ; Lane 0: 1.2s
    sta g_lane_spawn_timer + 0
    lda #150            ; Lane 1: 3.0s
    sta g_lane_spawn_timer + 1
    lda #240            ; Lane 2: 4.8s
    sta g_lane_spawn_timer + 2

    ; Enable Multicolor mode for Sprites 2, 3, 4 (%00011100 = $1C)
    ; Ensure Sprite 5 is Monochrome Hi-Res (Bit 5 = 0, ~$20 = $DF)
    lda VIC_SPR_MULTICOLOR
    ora #$1c
    and #$df
    sta VIC_SPR_MULTICOLOR

    ; Disable X/Y expansion for Sprites 2, 3, 4, 5 (%00111100 = $3C, ~$3C = $C3)
    lda VIC_SPR_EXP_X
    and #$c3
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    and #$c3
    sta VIC_SPR_EXP_Y

    ; Set Sprite-to-Background Priority to Foreground for Sprites 2, 3, 4, 5
    lda VIC_SPR_PRIORITY
    and #$c3            ; 0 = Foreground
    sta VIC_SPR_PRIORITY

    ; Disable Sprites 2, 3, 4, 5 initially in VIC_SPR_ENABLE
    lda VIC_SPR_ENABLE
    and #$c3
    sta VIC_SPR_ENABLE
    rts

; ==============================================================================
; Subroutine: enemies_spawn_lane
; Purpose: Attempts to spawn a new enemy in the specified lane (0, 1, or 2 in X).
; ==============================================================================
enemies_spawn_lane:
    stx s_lane_index_temp
    ; Base index for lane: Lane 0 = 0, Lane 1 = 3, Lane 2 = 6
    txa
    asl
    clc
    adc s_lane_index_temp   ; 3 * lane
    sta s_lane_base_temp

    ; 1. Check lane congestion and minimum horizontal spacing
    ; Count active enemies in this lane and ensure no enemy is near the right edge (X >= 220)
    lda #0
    sta s_lane_active_count
    ldx #0
@check_lane_slots:
    txa
    clc
    adc s_lane_base_temp
    tay                     ; Y = actual slot index (base + X)
    lda g_enemy_active, y
    beq @next_check_slot

    ; Enemy is active in this lane: increment lane active count
    inc s_lane_active_count

    ; Check if this enemy is still close to right spawn edge (X >= 220)
    lda g_enemy_x_hi, y
    bne @lane_busy          ; X >= 256 -> busy!
    lda g_enemy_x_lo, y
    cmp #220
    bcs @lane_busy          ; X >= 220 -> busy!

@next_check_slot:
    inx
    cpx #3
    bne @check_lane_slots
    jmp @check_lane_density

@lane_busy:
    rts                     ; Right edge not clear yet, wait for next cycle

@check_lane_density:
    ; Max allowed enemies in this lane based on elapsed time:
    ; Phase 1 (T < 30s): Max 1 enemy per lane (plenty of breathing room)
    ; Phase 2 & 3 (T >= 30s): Max 2 enemies per lane
    lda g_game_time_total_sec + 1
    bne @allow_2_enemies
    lda g_game_time_total_sec + 0
    cmp #30
    bcs @allow_2_enemies

    ; Phase 1 (T < 30s): max 1 enemy per lane
    lda s_lane_active_count
    bne @lane_full_exit
    jmp @find_free_slot

@allow_2_enemies:
    lda s_lane_active_count
    cmp #2
    bcs @lane_full_exit

@find_free_slot:
    ; Find the first inactive slot in this lane
    ldx #0
@search_free:
    txa
    clc
    adc s_lane_base_temp
    tay
    lda g_enemy_active, y
    beq @slot_found
    inx
    cpx #3
    bne @search_free

@lane_full_exit:
    rts

@slot_found:
    ; Activate slot Y
    lda #1
    sta g_enemy_active, y

    ; Initialize reload timer: 50 + (rand & 31) frames (approx 1.0 - 1.6s before first shot)
    jsr starfield_rand
    and #$1f
    clc
    adc #50
    sta g_enemy_reload_timer, y

    ; Spawn X off-screen to the right: X = 344 (X_lo = 88, X_hi = 1)
    lda #88
    sta g_enemy_x_lo, y
    lda #1
    sta g_enemy_x_hi, y

    ; Choose base Y depending on lane:
    ; Lane 0 (Top):    Base Y = 60 + (rand & 15)  -> 60..75  (with sine ±8: Y = 52..83, sprite 52..103, Lane 50..110)
    ; Lane 1 (Middle): Base Y = 125 + (rand & 15) -> 125..140 (with sine ±8: Y = 117..148, sprite 117..168, Lane 115..175)
    ; Lane 2 (Bottom): Base Y = 190 + (rand & 15) -> 190..205 (with sine ±8: Y = 182..213, sprite 182..233, Lane 180..240)
    jsr starfield_rand
    and #$0f            ; 0..15
    sta s_rand_offset_temp

    lda s_lane_index_temp
    bne +
    ; Lane 0
    lda #60
    clc
    adc s_rand_offset_temp
    jmp @store_y

+   cmp #1
    bne +
    ; Lane 1
    lda #125
    clc
    adc s_rand_offset_temp
    jmp @store_y

+   ; Lane 2
    lda #190
    clc
    adc s_rand_offset_temp

@store_y:
    sta g_enemy_base_y, y
    sta g_enemy_y, y

    ; Enemy archetype: Sprite 4 (Enemy Ship 1, Block 131 - Smallest enemy sprite)
    lda #SPRITE_PTR_ENEMY_1
    sta g_enemy_type, y

    ; Choose enemy individual color (Light Red, Green, Purple, Yellow, Orange)
    jsr starfield_rand
    and #$03
    tax
    lda @color_palette, x
    sta g_enemy_color, y

    ; Choose motion pattern: 50% straight, 50% sine wave
    jsr starfield_rand
    and #$01
    sta g_enemy_pattern, y

    ; Randomize initial sine phase (0..31)
    jsr starfield_rand
    and #$1f
    sta g_enemy_phase, y

    ; Set horizontal speed (1 or 2 px/frame)
    jsr starfield_rand
    and #$01
    clc
    adc #1              ; Speed 1 or 2
    sta g_enemy_speed, y
    rts

@color_palette:
    !byte COLOR_LIGHT_RED, COLOR_LIGHT_GREEN, COLOR_PURPLE, COLOR_YELLOW

s_lane_index_temp:    !byte 0
s_rand_offset_temp:   !byte 0
s_lane_base_temp:     !byte 0
s_lane_active_count:  !byte 0

; ==============================================================================
; Subroutine: enemies_update
; Purpose: Updates spawn timers, moves active enemies, applies waves, despawns.
; ==============================================================================
enemies_update:
    ; 1. Advance enemy shot color cycling index each frame (0..6)
    inc g_enemy_shot_cycle_idx
    lda g_enemy_shot_cycle_idx
    cmp #NUM_ENEMY_SHOT_COLORS
    bcc +
    lda #0
    sta g_enemy_shot_cycle_idx
+

    ; 2. Update Spawning for all 3 Lanes
    ldx #0
@lane_spawn_loop:
    stx s_lane_index_temp
    dec g_lane_spawn_timer, x
    bne @next_lane

    ; Timer fired: spawn an enemy in lane X
    jsr enemies_spawn_lane

    ; Reset lane timer based on elapsed time (scaling wave intensity)
    lda g_game_time_total_sec + 1
    bne @spawn_high_intensity
    lda g_game_time_total_sec + 0
    cmp #60
    bcs @spawn_high_intensity
    cmp #30
    bcs @spawn_med_intensity

    ; Phase 1 (0..29 sec): Warm-up / relaxed spawning (generously spaced)
    ; Timer = 180 + (rand & 63) frames (approx 3.6s to 4.8s per lane)
    jsr starfield_rand
    and #$3f
    clc
    adc #180
    jmp @store_lane_timer

@spawn_med_intensity:
    ; Phase 2 (30..59 sec): Active spawning
    ; Timer = 130 + (rand & 63) frames (approx 2.6s to 3.8s per lane)
    jsr starfield_rand
    and #$3f
    clc
    adc #130
    jmp @store_lane_timer

@spawn_high_intensity:
    ; Phase 3 (60+ sec): High intensity spawning
    ; Timer = 90 + (rand & 31) frames (approx 1.8s to 2.4s per lane)
    jsr starfield_rand
    and #$1f
    clc
    adc #90

@store_lane_timer:
    ldx s_lane_index_temp
    sta g_lane_spawn_timer, x

@next_lane:
    ldx s_lane_index_temp
    inx
    cpx #3
    bne @lane_spawn_loop

    ; 2. Move & Update All 9 Enemies
    ldx #0
@update_enemy_loop:
    lda g_enemy_active, x
    bne @enemy_is_active
    jmp @skip_enemy

@enemy_is_active:
    ; Move horizontally left by speed (1 or 2 px)
    lda g_enemy_x_lo, x
    sec
    sbc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcs +
    ; Borrow from X MSB
    dec g_enemy_x_hi, x

+   ; Despawn check: if X_hi == 0 and X_lo < 16 (fully exited left visible border)
    lda g_enemy_x_hi, x
    bne @apply_trajectory
    lda g_enemy_x_lo, x
    cmp #16
    bcs @apply_trajectory

    ; Deactivate enemy slot
    lda #0
    sta g_enemy_active, x
    jmp @skip_enemy

@apply_trajectory:
    ; If pattern == 0 (straight), Y stays at base_y
    lda g_enemy_pattern, x
    beq @check_shooting

    ; Pattern 1: Sinusoidal wave within lane bounds
    inc g_enemy_phase, x
    lda g_enemy_phase, x
    and #$1f            ; Keep within 0..31 (32 entries)
    sta g_enemy_phase, x
    tay
    lda g_enemy_sine_table, y
    clc
    adc g_enemy_base_y, x ; Signed two's complement addition (base_y + delta)
    sta g_enemy_y, x

@check_shooting:
    ; Check if game time >= 15 seconds (warm-up phase does not shoot)
    lda g_game_time_total_sec + 1
    bne @can_shoot
    lda g_game_time_total_sec + 0
    cmp #15
    bcc @skip_enemy

@can_shoot:
    dec g_enemy_reload_timer, x
    bne @skip_enemy

    ; Reload timer reached 0: re-arm reload timer (60..123 frames = 1.2s..2.5s)
    txa
    pha
    jsr starfield_rand
    and #$3f
    clc
    adc #60
    sta s_reload_temp
    pla
    tax
    lda s_reload_temp
    sta g_enemy_reload_timer, x

    ; Check if enemy is within horizontal firing window: 60 <= X <= 300
    lda g_enemy_x_hi, x
    beq @check_left_x
    ; X_hi == 1: X = 256 + X_lo. In range if X_lo <= 44 (X <= 300)
    lda g_enemy_x_lo, x
    cmp #45
    bcs @skip_enemy
    jmp @in_firing_range

@check_left_x:
    ; X_hi == 0: X = X_lo. In range if X_lo >= 60
    lda g_enemy_x_lo, x
    cmp #60
    bcc @skip_enemy

@in_firing_range:
    ; Find lane index for this enemy slot (0, 1, or 2)
    ldy g_enemy_lane_table, x

    ; Only fire if this lane's shot slot is currently inactive
    lda g_enemy_shot_active, y
    bne @skip_enemy

    ; Activate shot in this lane
    lda #1
    sta g_enemy_shot_active, y

    ; Set shot Y: centered vertically with enemy (enemy_y + 2)
    lda g_enemy_y, x
    clc
    adc #2
    sta g_enemy_shot_y, y

    ; Set shot speed: 3 pixels/frame leftward
    lda #3
    sta g_enemy_shot_speed, y

    ; Set shot X: 6 pixels in front of enemy nose
    lda g_enemy_x_lo, x
    sec
    sbc #6
    sta g_enemy_shot_x_lo, y
    lda g_enemy_x_hi, x
    sbc #0
    sta g_enemy_shot_x_hi, y

@skip_enemy:
    inx
    cpx #MAX_ENEMIES
    beq +
    jmp @update_enemy_loop
+

    ; 3. Move & Update All 3 Lane Enemy Shots
    ldx #0
@update_shot_loop:
    lda g_enemy_shot_active, x
    beq @skip_shot

    ; Move shot leftward: X = X - speed
    lda g_enemy_shot_x_lo, x
    sec
    sbc g_enemy_shot_speed, x
    sta g_enemy_shot_x_lo, x
    bcs +
    dec g_enemy_shot_x_hi, x

+   ; Despawn check: if X_hi == 0 and X_lo < 16 (exited left visible screen)
    lda g_enemy_shot_x_hi, x
    bne @skip_shot
    lda g_enemy_shot_x_lo, x
    cmp #16
    bcs @skip_shot

    ; Despawn bullet
    lda #0
    sta g_enemy_shot_active, x

@skip_shot:
    inx
    cpx #MAX_ENEMY_SHOTS
    bne @update_shot_loop
    rts

; ==============================================================================
; Subroutine: enemies_render_lane
; Purpose: Updates Hardware Sprites 2, 3, 4 (Enemies) and Sprite 5 (Enemy Shot).
; Input: A = Lane Index (0 = Top Third, 1 = Middle Third, 2 = Bottom Third).
; Called directly by Raster Interrupts at Scanlines 0, 112, and 177.
; ==============================================================================
enemies_render_lane:
    sta s_render_lane_in
    ; Compute starting slot index: base = A * 3
    asl                 ; A * 2
    clc
    adc s_render_lane_in ; A * 3
    sta s_render_base_idx

    ; Fetch current MSB and Enable masks from VIC-II to preserve Sprites 0 and 1
    lda VIC_SPR_MSB
    and #$c3            ; Clear bits 2, 3, 4, 5 (~$3C)
    sta s_msb_mask

    lda VIC_SPR_ENABLE
    and #$c3            ; Clear bits 2, 3, 4, 5 (~$3C)
    sta s_enable_mask

    ; --------------------------------------------------------------------------
    ; Hardware Sprite 2 (First enemy in this lane)
    ; --------------------------------------------------------------------------
    ldx s_render_base_idx
    lda g_enemy_active, x
    beq @disable_spr2

    ; Active: Set X, Y, Pointer, Color, MSB bit 2, Enable bit 2
    lda g_enemy_x_lo, x
    sta VIC_SPR2_X
    lda g_enemy_y, x
    sta VIC_SPR2_Y
    lda g_enemy_type, x
    sta SPRITE_PTRS + 2
    lda g_enemy_color, x
    sta VIC_SPR2_COLOR

    lda g_enemy_x_hi, x
    beq +
    lda s_msb_mask
    ora #$04            ; Bit 2 = 1
    sta s_msb_mask

+   lda s_enable_mask
    ora #$04            ; Bit 2 = 1
    sta s_enable_mask
    jmp @spr3

@disable_spr2:
    lda #0
    sta VIC_SPR2_Y

@spr3:
    ; --------------------------------------------------------------------------
    ; Hardware Sprite 3 (Second enemy in this lane)
    ; --------------------------------------------------------------------------
    inx
    lda g_enemy_active, x
    beq @disable_spr3

    lda g_enemy_x_lo, x
    sta VIC_SPR3_X
    lda g_enemy_y, x
    sta VIC_SPR3_Y
    lda g_enemy_type, x
    sta SPRITE_PTRS + 3
    lda g_enemy_color, x
    sta VIC_SPR3_COLOR

    lda g_enemy_x_hi, x
    beq +
    lda s_msb_mask
    ora #$08            ; Bit 3 = 1
    sta s_msb_mask

+   lda s_enable_mask
    ora #$08            ; Bit 3 = 1
    sta s_enable_mask
    jmp @spr4

@disable_spr3:
    lda #0
    sta VIC_SPR3_Y

@spr4:
    ; --------------------------------------------------------------------------
    ; Hardware Sprite 4 (Third enemy in this lane)
    ; --------------------------------------------------------------------------
    inx
    lda g_enemy_active, x
    beq @disable_spr4

    lda g_enemy_x_lo, x
    sta VIC_SPR4_X
    lda g_enemy_y, x
    sta VIC_SPR4_Y
    lda g_enemy_type, x
    sta SPRITE_PTRS + 4
    lda g_enemy_color, x
    sta VIC_SPR4_COLOR

    lda g_enemy_x_hi, x
    beq +
    lda s_msb_mask
    ora #$10            ; Bit 4 = 1
    sta s_msb_mask

+   lda s_enable_mask
    ora #$10            ; Bit 4 = 1
    sta s_enable_mask
    jmp @spr5

@disable_spr4:
    lda #0
    sta VIC_SPR4_Y

@spr5:
    ; --------------------------------------------------------------------------
    ; Hardware Sprite 5 (Enemy Shot for this lane)
    ; --------------------------------------------------------------------------
    ldy s_render_lane_in
    lda g_enemy_shot_active, y
    beq @disable_spr5

    lda g_enemy_shot_x_lo, y
    sta VIC_SPR5_X
    lda g_enemy_shot_y, y
    sta VIC_SPR5_Y
    lda #SPRITE_PTR_ENEMY_SHOT_1
    sta SPRITE_PTRS + 5

    ; Set cycling energy color for enemy shot (like player shot)
    ldx g_enemy_shot_cycle_idx
    lda g_enemy_shot_colors, x
    sta VIC_SPR5_COLOR

    lda g_enemy_shot_x_hi, y
    beq +
    lda s_msb_mask
    ora #$20            ; Bit 5 = 1
    sta s_msb_mask

+   lda s_enable_mask
    ora #$20            ; Bit 5 = 1
    sta s_enable_mask
    jmp @finish_render

@disable_spr5:
    lda #0
    sta VIC_SPR5_Y

@finish_render:
    ; Write final composite MSB and Enable registers to VIC-II
    lda s_msb_mask
    sta VIC_SPR_MSB
    lda s_enable_mask
    sta VIC_SPR_ENABLE
    rts

; ==============================================================================
; Subroutine: enemies_render (Stub)
; Note: Real-time rendering is performed by enemies_render_lane via Raster IRQs.
; ==============================================================================
enemies_render:
    rts
