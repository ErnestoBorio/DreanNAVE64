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

; Trajectory Pattern Equates
PATTERN_STRAIGHT    = 0         ; Linear horizontal sweep
PATTERN_SINE        = 1         ; Sinusoidal wave within lane (Enemy 1)
PATTERN_DIAGONAL    = 2         ; Lane-bounded diagonal bounce (Enemies 2 & 3)

; Lane vertical boundaries for diagonal movement (keeps 21px sprite rigidly inside lane)
; Lane 0: Y = 52..88   (Sprite 52..109, Lane 50..110)
; Lane 1: Y = 117..153 (Sprite 117..174, Lane 115..175)
; Lane 2: Y = 182..218 (Sprite 182..239, Lane 180..240)
g_lane_min_y:       !byte 52, 117, 182
g_lane_max_y:       !byte 88, 153, 218

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
g_enemy_pattern:    !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; 0 = Straight, 1 = Sine, 2 = Diagonal
g_enemy_phase:      !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Sine angle (0..31) or Diag dir (0=UP, 1=DOWN)
g_enemy_speed:      !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Pixels per frame (1, 2, or 3)
g_enemy_hp:         !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; HP / Hits to destroy
g_enemy_archetype:  !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Archetype index (0..7)
g_enemy_dir_x:      !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; 0 = Moving Left, 1 = Moving Right
g_enemy_min_x:      !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Left turnaround limit (pass-specific)
g_enemy_exploding:  !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Explosion animation timer (12..0)
g_enemy_flash:      !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Damage flash timer (3..0)
g_enemy_base_color: !byte 0, 0, 0,  0, 0, 0,  0, 0, 0 ; Preserved base color for flash restore

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
g_enemy_shot_speed:   !byte 0, 0, 0   ; Horizontal speed (px/frame leftward)
g_enemy_shot_type:    !byte 0, 0, 0   ; Sprite block pointer (142 or 143)
g_enemy_shot_dir_y:   !byte 0, 0, 0   ; 0 = Straight, 1 = Moving UP, 2 = Moving DOWN

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

; Temporary rendering and calculation variables
s_render_lane_in:   !byte 0
s_render_base_idx:  !byte 0
s_msb_mask:         !byte 0
s_enable_mask:      !byte 0
s_reload_temp:      !byte 0
s_tier_offset_temp: !byte 0
s_shot_lane_temp:   !byte 0
s_min_x_temp:       !byte 0

; ------------------------------------------------------------------------------
; Enemy Archetype Data Tables (8 Archetypes: Index 0 to 7)
; ------------------------------------------------------------------------------
; Trajectory Pattern Mode Equates:
PATTERN_MODE_STRAIGHT   = 0     ; 100% Straight flight
PATTERN_MODE_SINE_MIX   = 1     ; 50% Straight, 50% Sine wave
PATTERN_MODE_DIAG_MIX   = 2     ; 38% Straight, 62% Diagonal bounce
PATTERN_MODE_SINE_ONLY  = 3     ; 100% Sine wave
PATTERN_MODE_DIAG_ONLY  = 4     ; 100% Diagonal bounce

enemy_table_sprite:
    !byte SPRITE_PTR_ENEMY_1    ; 131: Enemy 1 (Scout)
    !byte SPRITE_PTR_ENEMY_2    ; 132: Enemy 2 (Light Fighter)
    !byte SPRITE_PTR_ENEMY_3    ; 133: Enemy 3 (Interceptor)
    !byte SPRITE_PTR_ENEMY_4    ; 134: Enemy 4 (Gunship)
    !byte SPRITE_PTR_ENEMY_5    ; 135: Enemy 5 (Twin-Hull)
    !byte SPRITE_PTR_ENEMY_6    ; 136: Enemy 6 (Heavy Cruiser)
    !byte SPRITE_PTR_ENEMY_7    ; 137: Enemy 7 (Battleship)
    !byte SPRITE_PTR_ENEMY_8    ; 138: Enemy 8 (Dreadnought Boss)

enemy_table_hp:
    !byte 1, 1, 2, 2, 3, 3, 4, 6

enemy_table_pattern_mode:
    !byte PATTERN_MODE_SINE_MIX     ; Enemy 1: 50% straight, 50% sine
    !byte PATTERN_MODE_DIAG_MIX     ; Enemy 2: 38% straight, 62% diagonal
    !byte PATTERN_MODE_DIAG_ONLY    ; Enemy 3: diagonal bounce
    !byte PATTERN_MODE_STRAIGHT     ; Enemy 4: fast straight sweep
    !byte PATTERN_MODE_SINE_ONLY    ; Enemy 5: sine wave oscillation
    !byte PATTERN_MODE_DIAG_ONLY    ; Enemy 6: diagonal bounce
    !byte PATTERN_MODE_DIAG_MIX     ; Enemy 7: straight/diagonal
    !byte PATTERN_MODE_STRAIGHT     ; Enemy 8: heavy straight advance

enemy_table_speed:
    !byte 1, 2, 2, 3, 2, 2, 2, 1

enemy_table_reload:
    !byte 60, 50, 40, 35, 30, 28, 25, 20

enemy_table_shot_speed:
    !byte 3, 4, 4, 4, 4, 5, 5, 4

enemy_table_shot_type:
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; 142: Single shot
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; 142: Single shot
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; 142: Single shot
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; 142: Single shot
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; 142: Single shot
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; 142: Single shot
    !byte SPRITE_PTR_ENEMY_SHOT_2   ; 143: Spread shot
    !byte SPRITE_PTR_ENEMY_SHOT_2   ; 143: Spread shot

enemy_table_min_x:
    !byte 75, 70, 60, 55, 90, 85, 120, 160

; Unlock thresholds in total elapsed seconds (16-bit)
enemy_table_unlock_sec_lo:
    !byte <0, <30, <60, <100, <150, <210, <280, <360

enemy_table_unlock_sec_hi:
    !byte >0, >30, >60, >100, >150, >210, >280, >360

; ------------------------------------------------------------------------------
; 32-Entry Weighted Tier Spawn Tables (8 Tiers x 32 bytes = 256 bytes total)
; Descending probability guarantees lower enemies spawn more frequently than higher.
; ------------------------------------------------------------------------------
tier_offsets:
    !byte 0, 32, 64, 96, 128, 160, 192, 224

tier_spawn_table:
    ; Tier 0 (0..29s): 100% Enemy 1 (32 entries)
    !byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    !byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

    ; Tier 1 (30..59s): 69% E1 (22), 31% E2 (10)
    !byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    !byte 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

    ; Tier 2 (60..99s): 50% E1 (16), 31% E2 (10), 19% E3 (6)
    !byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    !byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2

    ; Tier 3 (100..149s): E1..E4 equal distribution (8 each = 25% each)
    !byte 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1
    !byte 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3

    ; Tier 4 (150..209s): E1: 6 (19%), E2: 6 (19%), E3: 6 (19%), E4: 7 (22%), E5: 7 (22%)
    !byte 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2
    !byte 2, 2, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4

    ; Tier 5 (210..279s): E1: 4 (12%), E2: 4 (12%), E3: 5 (16%), E4: 6 (19%), E5: 7 (22%), E6: 6 (19%)
    !byte 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3
    !byte 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5

    ; Tier 6 (280..359s): E1: 3 (9%), E2: 3 (9%), E3: 4 (12%), E4: 5 (16%), E5: 6 (19%), E6: 6 (19%), E7: 5 (16%)
    !byte 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4
    !byte 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6

    ; Tier 7 (360s+): E1: 2 (6%), E2: 2 (6%), E3: 3 (9%), E4: 5 (16%), E5: 5 (16%), E6: 5 (16%), E7: 7 (22%), E8: 3 (9%)
    ; High-tier enemies (E4..E8) account for 25 out of 32 spawns (78.1%)!
    !byte 0, 0, 1, 1, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4
    !byte 4, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7

; ------------------------------------------------------------------------------
; 32-Entry Signed Sine Wave Lookup Table (Amplitude ±8 pixels, 1 full cycle)
; ------------------------------------------------------------------------------
g_enemy_sine_table:
    !byte   0,   2,   3,   4,   6,   7,   7,   8
    !byte   8,   8,   7,   7,   6,   4,   3,   2
    !byte   0,  -2,  -3,  -4,  -6,  -7,  -7,  -8
    !byte  -8,  -8,  -7,  -7,  -6,  -4,  -3,  -2

; ==============================================================================
; Subroutine: enemies_clear_all
; Purpose: Despawns all active enemies and shots across all lanes immediately.
; ==============================================================================
enemies_clear_all:
    ldx #0
-   lda #0
    sta g_enemy_active, x
    sta g_enemy_exploding, x
    sta g_enemy_flash, x
    inx
    cpx #MAX_ENEMIES
    bne -

    ldx #0
-   lda #0
    sta g_enemy_shot_active, x
    sta g_enemy_shot_dir_y, x
    inx
    cpx #MAX_ENEMY_SHOTS
    bne -
    rts

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
    sta g_enemy_archetype, x
    sta g_enemy_hp, x
    sta g_enemy_dir_x, x
    sta g_enemy_min_x, x
    sta g_enemy_exploding, x
    sta g_enemy_flash, x
    sta g_enemy_base_color, x
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
    sta g_enemy_shot_type, x
    sta g_enemy_shot_dir_y, x
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
    ; Max allowed enemies in this lane:
    ; In debug mode (keys 1..8): allow full swarm (all 3 slots open)
    lda g_debug_force_enemy
    bne @find_free_slot

    ; Post-Enemy 8 (T >= 360s): allow 3 enemies per lane
    lda g_game_time_total_sec + 1
    cmp #>360
    bcc @check_earlier_density
    bne @find_free_slot
    lda g_game_time_total_sec + 0
    cmp #<360
    bcs @find_free_slot

@check_earlier_density:
    ; Phase 2 (30s <= T < 360s): Max 2 enemies per lane
    lda g_game_time_total_sec + 1
    bne @allow_2_enemies
    lda g_game_time_total_sec + 0
    cmp #30
    bcs @allow_2_enemies

    ; Phase 1 (T < 30s): Max 1 enemy per lane
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

    ; Check if debug force enemy is active (1..8)
    lda g_debug_force_enemy
    beq @use_timeline
    cmp #9
    bcs @use_timeline
    sec
    sbc #1                  ; Map 1..8 to Archetype 0..7
    jmp @setup_archetype

@use_timeline:
    ; Determine current unlocked tier (7 down to 0) based on total elapsed seconds
    ldx #7
-   lda g_game_time_total_sec + 1
    cmp enemy_table_unlock_sec_hi, x
    bcc +
    bne @tier_found
    lda g_game_time_total_sec + 0
    cmp enemy_table_unlock_sec_lo, x
    bcs @tier_found
+   dex
    bne -

@tier_found:
    ; X = current unlocked tier (0..7)
    lda tier_offsets, x
    sta s_tier_offset_temp
    jsr starfield_rand
    and #$1f                ; 0..31
    clc
    adc s_tier_offset_temp
    tax
    lda tier_spawn_table, x ; A = selected archetype (0..7)

    ; Enemy 8 Presence Guard: ensure at most 1 Enemy 8 active on screen at a time
    cmp #7
    bne @setup_archetype
    ldx #0
-   lda g_enemy_active, x
    beq +
    lda g_enemy_archetype, x
    cmp #7
    beq @downgrade_e8
+   inx
    cpx #MAX_ENEMIES
    bne -
    lda #7                  ; Keep Enemy 8
    jmp @setup_archetype

@downgrade_e8:
    lda #6                  ; Downgrade to Enemy 7 (Battleship)

@setup_archetype:
    sta g_enemy_archetype, y
    tax                     ; X = archetype index (0..7)

    ; Initialize roaming & status variables
    lda #0
    sta g_enemy_dir_x, y    ; Initial movement direction: Left (inward)
    sta g_enemy_exploding, y
    sta g_enemy_flash, y

    ; Calculate randomized left turnaround depth for this pass
    lda enemy_table_min_x, x
    sta s_min_x_temp
    jsr starfield_rand
    and #$1f                ; 0..31
    clc
    adc s_min_x_temp
    sta g_enemy_min_x, y

    ; Set sprite pointer (Blocks 131..138)
    lda enemy_table_sprite, x
    sta g_enemy_type, y

    ; Set HP (hits to destroy)
    lda enemy_table_hp, x
    sta g_enemy_hp, y

    ; Set reload timer: base + (rand & 31) frames
    jsr starfield_rand
    and #$1f
    clc
    adc enemy_table_reload, x
    sta g_enemy_reload_timer, y

    ; Set horizontal speed
    lda enemy_table_speed, x
    sta g_enemy_speed, y
    ; Special: Enemy 1 (archetype 0) has random speed 1 or 2
    cpx #0
    bne +
    jsr starfield_rand
    and #$01
    clc
    adc #1
    sta g_enemy_speed, y
+
    ; Set movement pattern based on pattern mode
    lda enemy_table_pattern_mode, x
    cmp #PATTERN_MODE_STRAIGHT
    beq @set_pat_straight
    cmp #PATTERN_MODE_SINE_MIX
    beq @set_pat_sine_mix
    cmp #PATTERN_MODE_DIAG_MIX
    beq @set_pat_diag_mix
    cmp #PATTERN_MODE_SINE_ONLY
    beq @set_pat_sine_only
    ; Default: PATTERN_MODE_DIAG_ONLY
    jmp @set_pat_diag_only

@set_pat_straight:
    lda #PATTERN_STRAIGHT
    sta g_enemy_pattern, y
    jmp @setup_color

@set_pat_sine_mix:
    jsr starfield_rand
    and #$01
    sta g_enemy_pattern, y
    jmp @setup_sine_phase

@set_pat_sine_only:
    lda #PATTERN_SINE
    sta g_enemy_pattern, y
@setup_sine_phase:
    jsr starfield_rand
    and #$1f
    sta g_enemy_phase, y
    jmp @setup_color

@set_pat_diag_mix:
    jsr starfield_rand
    and #$07
    cmp #3
    bcs @set_pat_diag_only
    lda #PATTERN_STRAIGHT
    sta g_enemy_pattern, y
    jmp @setup_color

@set_pat_diag_only:
    lda #PATTERN_DIAGONAL
    sta g_enemy_pattern, y
    ; Randomize initial direction: 0 = UP, 1 = DOWN
    jsr starfield_rand
    and #$01
    sta g_enemy_phase, y

@setup_color:
    ; Choose enemy individual color (Light Red, Green, Purple, Yellow)
    jsr starfield_rand
    and #$03
    tax
    lda @color_palette, x
    sta g_enemy_color, y
    sta g_enemy_base_color, y
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
    beq +
    jmp @next_lane
+

    ; Timer fired: spawn an enemy in lane X
    jsr enemies_spawn_lane

    ; Reset lane timer based on elapsed time (scaling wave intensity)
    ; In debug mode (keys 1..8): use fast spawn rate (50 + rand & 31)
    lda g_debug_force_enemy
    bne @spawn_enemy8_intensity

    ; Phase 6 (T >= 480s / 8 min): Endgame Frenzy (36 + rand & 15 frames = 0.7s - 1.0s per lane)
    lda g_game_time_total_sec + 1
    cmp #>480
    bcc +
    bne @spawn_frenzy_intensity
    lda g_game_time_total_sec + 0
    cmp #<480
    bcs @spawn_frenzy_intensity
+
    ; Phase 5 (T >= 360s / 6 min - Post-Enemy 8): High intensity (50 + rand & 31 frames = 1.0s - 1.6s per lane)
    lda g_game_time_total_sec + 1
    cmp #>360
    bcc +
    bne @spawn_enemy8_intensity
    lda g_game_time_total_sec + 0
    cmp #<360
    bcs @spawn_enemy8_intensity
+
    ; Phase 4 (T >= 180s / 3 min): Fast spawning (70 + rand & 31 frames = 1.4s - 2.0s per lane)
    lda g_game_time_total_sec + 1
    bne @spawn_fast_intensity
    lda g_game_time_total_sec + 0
    cmp #180
    bcs @spawn_fast_intensity

    ; Phase 3 (60..179 sec): (90 + rand & 31 frames = 1.8s - 2.4s per lane)
    cmp #60
    bcs @spawn_high_intensity

    ; Phase 2 (30..59 sec): (130 + rand & 63 frames = 2.6s - 3.8s per lane)
    cmp #30
    bcs @spawn_med_intensity

    ; Phase 1 (0..29 sec): Warm-up relaxed spawning (180 + rand & 63 frames = 3.6s - 4.8s per lane)
    jsr starfield_rand
    and #$3f
    clc
    adc #180
    jmp @store_lane_timer

@spawn_med_intensity:
    jsr starfield_rand
    and #$3f
    clc
    adc #130
    jmp @store_lane_timer

@spawn_high_intensity:
    jsr starfield_rand
    and #$1f
    clc
    adc #90
    jmp @store_lane_timer

@spawn_fast_intensity:
    jsr starfield_rand
    and #$1f
    clc
    adc #70
    jmp @store_lane_timer

@spawn_enemy8_intensity:
    jsr starfield_rand
    and #$1f
    clc
    adc #50
    jmp @store_lane_timer

@spawn_frenzy_intensity:
    jsr starfield_rand
    and #$0f
    clc
    adc #36

@store_lane_timer:
    ldx s_lane_index_temp
    sta g_lane_spawn_timer, x

@next_lane:
    ldx s_lane_index_temp
    inx
    cpx #3
    beq +
    jmp @lane_spawn_loop
+

    ; 2. Move & Update All 9 Enemies
    ldx #0
@update_enemy_loop:
    lda g_enemy_active, x
    bne @enemy_is_active
    jmp @skip_enemy

@enemy_is_active:
    ; 1. Handle damage flash timer
    lda g_enemy_flash, x
    beq +
    dec g_enemy_flash, x
    bne @flash_white
    ; Flash finished: restore base color
    lda g_enemy_base_color, x
    sta g_enemy_color, x
    jmp +
@flash_white:
    lda #COLOR_WHITE
    sta g_enemy_color, x
+
    ; 2. Handle explosion animation if destroying
    lda g_enemy_exploding, x
    beq @not_exploding
    dec g_enemy_exploding, x
    beq @explosion_finished

    lda g_enemy_exploding, x
    cmp #8
    bcs @exp_frame_1
    cmp #4
    bcs @exp_frame_2
    lda #SPRITE_PTR_EXPLOSION_3
    sta g_enemy_type, x
    jmp @skip_enemy
@exp_frame_2:
    lda #SPRITE_PTR_EXPLOSION_2
    sta g_enemy_type, x
    jmp @skip_enemy
@exp_frame_1:
    lda #SPRITE_PTR_EXPLOSION_1
    sta g_enemy_type, x
    jmp @skip_enemy

@explosion_finished:
    lda #0
    sta g_enemy_active, x
    jmp @skip_enemy

@not_exploding:
    ; 3. Horizontal Roaming Movement
    lda g_enemy_dir_x, x
    bne @move_right

    ; --- Moving LEFT (Inward towards player) ---
    lda g_enemy_x_lo, x
    sec
    sbc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+
    ; Check if reached left turnaround bound
    lda g_enemy_x_hi, x
    bne @apply_trajectory
    lda g_enemy_x_lo, x
    cmp g_enemy_min_x, x
    bcs @apply_trajectory
    ; Reached left bound: clamp and reverse direction to RIGHT
    lda g_enemy_min_x, x
    sta g_enemy_x_lo, x
    lda #1
    sta g_enemy_dir_x, x
    jmp @apply_trajectory

@move_right:
    ; --- Moving RIGHT (Hovering retreat at 1 px/frame) ---
    lda g_enemy_x_lo, x
    clc
    adc #1
    sta g_enemy_x_lo, x
    bcc +
    inc g_enemy_x_hi, x
+
    ; Check if reached right turnaround bound: X >= 295 (MSB >= 1 and LSB >= 39)
    lda g_enemy_x_hi, x
    beq @apply_trajectory
    lda g_enemy_x_lo, x
    cmp #39
    bcc @apply_trajectory
    ; Reached right bound: clamp and reverse direction to LEFT
    lda #39
    sta g_enemy_x_lo, x
    lda #0
    sta g_enemy_dir_x, x

    ; Re-randomize left turnaround bound for next inward pass
    ldy g_enemy_archetype, x
    jsr starfield_rand
    and #$1f                    ; 0..31
    clc
    adc enemy_table_min_x, y
    sta g_enemy_min_x, x

@apply_trajectory:
    ; If pattern == 0 (straight), Y stays at base_y
    lda g_enemy_pattern, x
    beq @check_shooting
    cmp #PATTERN_DIAGONAL
    beq @apply_diagonal

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
    jmp @check_shooting

@apply_diagonal:
    ; Pattern 2: Diagonal bounce within lane bounds (Enemies 2 & 3)
    ldy g_enemy_lane_table, x
    lda g_enemy_phase, x
    bne @diagonal_down

    ; Moving UP: dec Y
    lda g_enemy_y, x
    sec
    sbc #1
    sta g_enemy_y, x
    cmp g_lane_min_y, y
    bcs @check_shooting
    ; Hit top bound: reverse to DOWN
    lda g_lane_min_y, y
    sta g_enemy_y, x
    lda #1
    sta g_enemy_phase, x
    jmp @check_shooting

@diagonal_down:
    ; Moving DOWN: inc Y
    lda g_enemy_y, x
    clc
    adc #1
    sta g_enemy_y, x
    cmp g_lane_max_y, y
    bcc @check_shooting
    ; Hit bottom bound: reverse to UP
    lda g_lane_max_y, y
    sta g_enemy_y, x
    lda #0
    sta g_enemy_phase, x

@check_shooting:
    ; In debug force mode (keys 1..8), allow shooting immediately
    lda g_debug_force_enemy
    bne @can_shoot
    ; In normal mode: check if game time >= 15 seconds (warm-up phase does not shoot)
    lda g_game_time_total_sec + 1
    bne @can_shoot
    lda g_game_time_total_sec + 0
    cmp #15
    bcs @can_shoot
    jmp @skip_enemy

@can_shoot:
    dec g_enemy_reload_timer, x
    beq @do_rearm
    jmp @skip_enemy

@do_rearm:
    ; Reload timer reached 0: re-arm reload timer based on archetype
    ldy g_enemy_archetype, x
    txa
    pha
    jsr starfield_rand
    and #$1f
    clc
    adc enemy_table_reload, y
    sta s_reload_temp

    ; Post-Enemy 8 (T >= 360s) or debug key 8: boost shot cadence by reducing reload time
    lda g_debug_force_enemy
    cmp #8
    beq @boost_reload
    lda g_game_time_total_sec + 1
    cmp #>360
    bcc @store_reload
    bne @boost_reload
    lda g_game_time_total_sec + 0
    cmp #<360
    bcc @store_reload

@boost_reload:
    lda s_reload_temp
    sec
    sbc #12
    cmp #15
    bcs +
    lda #15
+   sta s_reload_temp

@store_reload:
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
    bcs @skip_enemy_j
    jmp @in_firing_range

@check_left_x:
    ; X_hi == 0: X = X_lo. In range if X_lo >= 60
    lda g_enemy_x_lo, x
    cmp #60
    bcc @skip_enemy_j
    jmp @in_firing_range

@skip_enemy_j:
    jmp @skip_enemy

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

    ; Set shot speed & type from archetype table
    sty s_shot_lane_temp
    ldy g_enemy_archetype, x
    lda enemy_table_shot_speed, y
    ldy s_shot_lane_temp
    sta g_enemy_shot_speed, y
    ldy g_enemy_archetype, x
    lda enemy_table_shot_type, y
    ldy s_shot_lane_temp
    sta g_enemy_shot_type, y

    ; Set shot trajectory direction:
    ; Enemies 1..4 (archetypes 0..3) always shoot straight (dir_y = 0)
    ; Enemies 5..8 (archetypes 4..7) sometimes shoot diagonally (bounded within lane)
    lda g_enemy_archetype, x
    cmp #4
    bcc @shot_straight

    ; Archetypes 4..5 (Enemies 5 & 6): 50% straight, 50% diagonal
    ; Archetypes 6..7 (Enemies 7 & 8): 25% straight, 75% diagonal
    cmp #6
    bcs @high_tier_shot

    jsr starfield_rand
    and #$03
    cmp #2
    bcs @shot_diagonal
    jmp @shot_straight

@high_tier_shot:
    jsr starfield_rand
    and #$03
    beq @shot_straight

@shot_diagonal:
    ; Randomize initial vertical direction (1 = UP, 2 = DOWN)
    jsr starfield_rand
    and #$01
    clc
    adc #1
    sta g_enemy_shot_dir_y, y
    jmp @shot_dir_done

@shot_straight:
    lda #0
    sta g_enemy_shot_dir_y, y

@shot_dir_done:
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

+   ; Move shot vertically if non-straight (clamping strictly within lane bounds without bouncing)
    lda g_enemy_shot_dir_y, x
    beq @no_y_move
    cmp #1
    bne @shot_move_down

    ; Moving UP: Y = Y - 1
    lda g_enemy_shot_y, x
    sec
    sbc #1
    sta g_enemy_shot_y, x
    cmp g_lane_min_y, x
    bcs @no_y_move
    ; Reached lane top bound: clamp and stop vertical movement (no bounce)
    lda g_lane_min_y, x
    sta g_enemy_shot_y, x
    lda #0
    sta g_enemy_shot_dir_y, x
    jmp @no_y_move

@shot_move_down:
    ; Moving DOWN: Y = Y + 1
    lda g_enemy_shot_y, x
    clc
    adc #1
    sta g_enemy_shot_y, x
    cmp g_lane_max_y, x
    bcc @no_y_move
    ; Reached lane bottom bound: clamp and stop vertical movement (no bounce)
    lda g_lane_max_y, x
    sta g_enemy_shot_y, x
    lda #0
    sta g_enemy_shot_dir_y, x

@no_y_move:
    ; Despawn check: if X_hi == 0 and X_lo < 16 (exited left visible screen)
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
    lda g_enemy_shot_type, y
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
