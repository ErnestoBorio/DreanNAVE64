; ==============================================================================
; ENEMIES.ASM - Dynamic Y-Sorted Sprite Multiplexer & Free-Roaming AI (Phase 6)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
;
; Features:
; - Dynamic Y-Sorted Multiplexer supporting up to 16 virtual sprites:
;     12 Free-Roaming Enemy Ships (0..11)
;     4 Free-Flying Aimed Bullets (12..15)
; - Glitch-free round-robin interrupt chain across Hardware Sprites 2..7.
; - Total Lane Abolishment: Entities roam and shoot across full screen (Y = 50..235).
; - Player-targeted ballistic aiming: Bullets track player position in real time.
; - Organic turnaround depths, multi-hit HP damage flash, and 3-frame explosion sequencing.
; ==============================================================================

; Trajectory Pattern Equates

PATTERN_STRAIGHT    = 0         ; Linear horizontal patrol
PATTERN_SINE        = 1         ; Wide sinusoidal wave oscillation (±25 px)
PATTERN_TRACKING    = 2         ; Dynamic vertical hunting & altitude tracking

; ------------------------------------------------------------------------------
; Virtual Sprite Export Table (16 Virtual Sprites: 0..11 Enemies, 12..15 Bullets)
; ------------------------------------------------------------------------------
v_spr_active:       !fill MAX_VIRTUAL_SPRITES, 0
v_spr_x_lo:         !fill MAX_VIRTUAL_SPRITES, 0
v_spr_x_hi:         !fill MAX_VIRTUAL_SPRITES, 0
v_spr_y:            !fill MAX_VIRTUAL_SPRITES, 0
v_spr_ptr:          !fill MAX_VIRTUAL_SPRITES, 0
v_spr_color:        !fill MAX_VIRTUAL_SPRITES, 0
v_spr_mc:           !fill MAX_VIRTUAL_SPRITES, 0 ; 1 = Multicolor (enemies), 0 = Hi-res (bullets)

; ------------------------------------------------------------------------------
; Dynamic Multiplexer State & Hardware Lookup Tables
; ------------------------------------------------------------------------------
g_sort_order:       !byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
g_sort_count:       !byte 0
g_multiplexer_active: !byte 0
g_irq_curr_virt:    !byte 0
g_irq_next_virt:    !byte 0
g_irq_phys_slot:    !byte 0

; Physical Hardware Sprites 2..7 (slots 0..5) register offsets and masks
s_phys_x_reg:       !byte $04, $06, $08, $0a, $0c, $0e ; Offsets from $D000 (VIC_SPR2_X .. SPR7_X)
s_phys_y_reg:       !byte $05, $07, $09, $0b, $0d, $0f ; Offsets from $D000 (VIC_SPR2_Y .. SPR7_Y)
s_phys_col_reg:     !byte $29, $2a, $2b, $2c, $2d, $2e ; Offsets from $D000 (VIC_SPR2_COLOR .. SPR7_COLOR)
s_phys_ptr_offset:  !byte $fa, $fb, $fc, $fd, $fe, $ff ; Offsets from $0700 (SPRITE_PTRS + 2 .. + 7)
s_phys_mask:        !byte $04, $08, $10, $20, $40, $80 ; Bit masks for MSB, Enable, Multicolor

; ------------------------------------------------------------------------------
; Enemy Ship State Variables (12 slots: 0..11)
; ------------------------------------------------------------------------------
g_enemy_active:     !fill MAX_ENEMIES, 0
g_enemy_x_lo:       !fill MAX_ENEMIES, 0
g_enemy_x_hi:       !fill MAX_ENEMIES, 0
g_enemy_y:          !fill MAX_ENEMIES, 0
g_enemy_base_y:     !fill MAX_ENEMIES, 0
g_enemy_type:       !fill MAX_ENEMIES, 0
g_enemy_color:      !fill MAX_ENEMIES, 0
s_enemy_color_timer: !byte 25   ; Half-second timer (25 frames @ 50 Hz PAL)
s_enemy_color_idx:   !byte 0    ; Current index in enemy energy sequence (0..5)
enemy_energy_colors:
    !byte COLOR_CYAN, COLOR_ORANGE, COLOR_LIGHT_BLUE, COLOR_LIGHT_GREEN
    !byte COLOR_GREEN, COLOR_PURPLE

g_enemy_pattern:    !fill MAX_ENEMIES, 0
g_enemy_phase:      !fill MAX_ENEMIES, 0
g_enemy_roam_timer: !fill MAX_ENEMIES, 0 ; 0 = Entering screen, >0 = Countdown to roam decision
g_enemy_speed:      !fill MAX_ENEMIES, 0
g_enemy_hp:         !fill MAX_ENEMIES, 0
g_enemy_archetype:  !fill MAX_ENEMIES, 0
g_enemy_dir_x:      !fill MAX_ENEMIES, 0 ; 0 = Moving Left, 1 = Moving Right
g_enemy_entry_dir:  !fill MAX_ENEMIES, 0 ; 0 = Top, 1 = Left side, 2 = Right side
g_enemy_curve_timer: !fill MAX_ENEMIES, 0 ; Side-entry curve countdown timer (24..0)
g_enemy_exploding:  !fill MAX_ENEMIES, 0 ; Explosion timer (12..0)
g_enemy_flash:      !fill MAX_ENEMIES, 0 ; Damage flash timer (3..0)
g_enemy_reload_timer: !fill MAX_ENEMIES, 60

; Free-roaming wave spawn timer
g_wave_spawn_timer: !byte 20
g_first_spawn_force: !byte 0    ; 0 = timeline progression, 1..8 = force Enemy 1..8 on next spawn only

; ------------------------------------------------------------------------------
; Enemy Bullet State Variables (4 slots: 0..3)
; ------------------------------------------------------------------------------
g_bullet_active:    !fill MAX_ENEMY_BULLETS, 0
g_bullet_x_lo:      !fill MAX_ENEMY_BULLETS, 0
g_bullet_x_hi:      !fill MAX_ENEMY_BULLETS, 0
g_bullet_y:         !fill MAX_ENEMY_BULLETS, 0
g_bullet_vel_x:     !fill MAX_ENEMY_BULLETS, 0
g_bullet_vel_y:     !fill MAX_ENEMY_BULLETS, 0 ; Signed byte (-2, -1, 0, 1, 2)
g_bullet_type:      !fill MAX_ENEMY_BULLETS, 0
g_bullet_color:     !fill MAX_ENEMY_BULLETS, 0

; Temporary calculation variables
s_sort_i:           !byte 0
s_sort_j:           !byte 0
s_sort_key_idx:     !byte 0
s_sort_key_y:       !byte 0
s_batch_size:       !byte 0
s_msb_mask:         !byte 0
s_enable_mask:      !byte 0
s_mc_mask:          !byte 0
s_reload_temp:      !byte 0
s_tier_offset_temp: !byte 0
s_reg_temp:         !byte 0
s_virt_temp:        !byte 0
s_mask_temp:        !byte 0
s_active_count:     !byte 0
s_spawn_y_temp:     !byte 0
s_shot_slot_temp:   !byte 0
s_enemy_slot_temp:  !byte 0
s_patrol_limit:     !byte 0
s_curve_dy_temp:    !byte 0
s_curve_dx_temp:    !byte 0

; ------------------------------------------------------------------------------
; Enemy Archetype Data Tables (8 Archetypes: Index 1 to 8, Index 0 is dummy)
; ------------------------------------------------------------------------------
PATTERN_MODE_SINE_MIX   = 0     ; Sometimes straight, sometimes sine
PATTERN_MODE_HUNT_MIX   = 1     ; Sometimes sine, sometimes tracking
PATTERN_MODE_HUNT_ONLY  = 2     ; Dynamic unpredictable vertical tracking

enemy_table_sprite:
    !byte 0                     ; Index 0 dummy
    !byte SPRITE_PTR_ENEMY_1    ; Archetype 1: Sprite 4: Enemy 1 (Scout)
    !byte SPRITE_PTR_ENEMY_2    ; Archetype 2: Sprite 5: Enemy 2 (Light Fighter)
    !byte SPRITE_PTR_ENEMY_3    ; Archetype 3: Sprite 6: Enemy 3 (Interceptor)
    !byte SPRITE_PTR_ENEMY_4    ; Archetype 4: Sprite 7: Enemy 4 (Scorpion)
    !byte SPRITE_PTR_ENEMY_5    ; Archetype 5: Sprite 8: Enemy 5 (Batplane)
    !byte SPRITE_PTR_ENEMY_6    ; Archetype 6: Sprite 9: Enemy 6 (Spider)
    !byte SPRITE_PTR_ENEMY_7    ; Archetype 7: Sprite 10: Enemy 7 (The Eye)
    !byte SPRITE_PTR_ENEMY_8    ; Archetype 8: Sprite 11: Enemy 8 (Death)

enemy_table_hp:
    !byte 0, 1, 1, 1, 2, 2, 3, 3, 3


enemy_table_speed:
    !byte 0, 1, 2, 2, 2, 2, 2, 2, 1

enemy_table_reload:
    !byte 0, 85, 75, 65, 55, 50, 45, 42, 38

enemy_table_shot_speed:
    !byte 0, 3, 3, 3, 3, 3, 4, 4, 4

enemy_table_shot_type:
    !byte 0
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; Enemy 1
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; Enemy 2
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; Enemy 3
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; Enemy 4
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; Enemy 5
    !byte SPRITE_PTR_ENEMY_SHOT_1   ; Enemy 6
    !byte SPRITE_PTR_ENEMY_SHOT_2   ; Enemy 7 (The Eye - Spread)
    !byte SPRITE_PTR_ENEMY_SHOT_2   ; Enemy 8 (Death - Spread)

; Unlock thresholds in total elapsed seconds (16-bit)
; Spaced out late-game progression: Spider @ 155s (2:35), Eye @ 215s (3:35), Death @ 285s (4:45)
enemy_table_unlock_sec_lo:
    !byte <0, <20, <45, <75, <110, <155, <215, <285

enemy_table_unlock_sec_hi:
    !byte >0, >20, >45, >75, >110, >155, >215, >285

; ------------------------------------------------------------------------------
; 16-Entry Weighted Tier Spawn Table (8 Tiers x 16 bytes = 128 bytes total)
; Offset = tier * 16 (0, 16, 32, 48, 64, 80, 96, 112)
; ------------------------------------------------------------------------------
tier_spawn_table:
    ; Tier 0 (0..19s): 100% Enemy 1 (16 entries)
    !byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

    ; Tier 1 (20..44s): 69% E1 (11), 31% E2 (5)
    !byte 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2

    ; Tier 2 (45..74s): 50% E1 (8), 31% E2 (5), 19% E3 (3)
    !byte 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3

    ; Tier 3 (75..109s): E1..E4 equal distribution (4 each = 25% each)
    !byte 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4

    ; Tier 4 (110..154s): E1: 3, E2: 3, E3: 3, E4: 3, E5: 4
    !byte 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 5

    ; Tier 5 (155..214s): E1: 2, E2: 2, E3: 3, E4: 3, E5: 4, E6: 2
    !byte 1, 1, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6

    ; Tier 6 (215..284s): E1: 2, E2: 2, E3: 2, E4: 2, E5: 3, E6: 3, E7: 2
    !byte 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7

    ; Tier 7 (285s+ / 4:45+): E1: 1, E2: 1, E3: 1, E4: 2, E5: 2, E6: 2, E7: 3, E8: 4 (Death 25% of spawns)
    !byte 1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 7, 7, 8, 8, 8, 8


; ------------------------------------------------------------------------------
; 32-Entry Signed Sine Wave Lookup Table (Amplitude ±25 pixels, 1 full cycle)
; ------------------------------------------------------------------------------
g_enemy_sine_table:
    !byte   0,   5,  10,  14,  18,  22,  24,  25
    !byte  25,  25,  24,  22,  18,  14,  10,   5
    !byte   0,  -5, -10, -14, -18, -22, -24, -25
    !byte -25, -25, -24, -22, -18, -14, -10,  -5

; ------------------------------------------------------------------------------
; 8-Direction Movement Delta Tables (4 Straight: 0..3, 4 Diagonal: 4..7)
; ------------------------------------------------------------------------------
scorp_dx_tab:
    !byte -1,  1,  0,  0, -1, -1,  1,  1
scorp_dy_tab:
    !byte  0,  0, -1,  1, -1,  1, -1,  1

; ------------------------------------------------------------------------------
; Death Random Velocity Components (-2, -1, 1, 2)
; ------------------------------------------------------------------------------
death_vel_tab:
    !byte -2, -1,  1,  2

; ------------------------------------------------------------------------------
; Soft Curved Swoop Delta Tables for Side Entry (24-frame curve: 6 segments x 4 frames)
; Index = countdown timer >> 2 (values 5..0)
; ------------------------------------------------------------------------------
curve_dy_tab:
    !byte 0, 1, 2, 2, 3, 3      ; dy: 3 at entry -> 0 at exit (horizontal -> vertical)
curve_dx_tab:
    !byte 3, 3, 3, 2, 1, 0      ; dx: 0 at entry -> 3 at exit (horizontal -> vertical)

; ------------------------------------------------------------------------------
; Smooth & Predictable Semicircle Table for Scorpion (Archetype 4)
; 32 steps (1 step per frame), Amplitude = 32 px (span = 64 px)
; ------------------------------------------------------------------------------
scorp_curve_dy_tab:
    !byte  0,  3,  6, 10, 13, 16, 18, 21, 23, 25, 27, 29, 30, 31, 32, 32
    !byte 32, 32, 31, 30, 29, 27, 25, 23, 21, 18, 16, 13, 10,  6,  3,  0




; ==============================================================================
; Subroutine: enemies_clear_all
; Purpose: Despawns all active enemies and bullets immediately.
; ==============================================================================
enemies_clear_all:
    lda #0
    ldx #MAX_VIRTUAL_SPRITES - 1
-   sta v_spr_active, x
    dex
    bpl -

    ldx #MAX_ENEMIES - 1
-   sta g_enemy_active, x
    sta g_enemy_entry_dir, x
    sta g_enemy_curve_timer, x
    sta g_enemy_exploding, x
    sta g_enemy_flash, x
    dex
    bpl -

    ldx #MAX_ENEMY_BULLETS - 1
-   sta g_bullet_active, x
    dex
    bpl -
    rts

; ==============================================================================
; Subroutine: enemies_init
; Purpose: Resets all enemy and bullet slots and configures initial sprite state.
; ==============================================================================
enemies_init:
    ldx #0
-   lda #0
    sta g_enemy_active, x
    sta g_enemy_entry_dir, x
    sta g_enemy_curve_timer, x
    sta g_enemy_x_lo, x
    sta g_enemy_x_hi, x
    sta g_enemy_y, x
    sta g_enemy_base_y, x
    sta g_enemy_pattern, x
    sta g_enemy_phase, x
    sta g_enemy_roam_timer, x
    sta g_enemy_archetype, x
    sta g_enemy_hp, x
    sta g_enemy_dir_x, x
    sta g_enemy_exploding, x
    sta g_enemy_flash, x
    lda #60
    sta g_enemy_reload_timer, x
    inx
    cpx #MAX_ENEMIES
    bne -

    lda #0
    ldx #MAX_ENEMY_BULLETS - 1
-   sta g_bullet_active, x
    sta g_bullet_x_lo, x
    sta g_bullet_x_hi, x
    sta g_bullet_y, x
    sta g_bullet_vel_x, x
    sta g_bullet_vel_y, x
    sta g_bullet_type, x
    sta g_bullet_color, x
    dex
    bpl -

    lda #0
    sta g_multiplexer_active
    sta g_sort_count
    sta g_first_spawn_force
    lda #40
    sta g_wave_spawn_timer

    ; Disable physical Sprites 2..7 initially ($D015 Bits 2..7 = 0)
    lda VIC_SPR_ENABLE
    and #$03
    sta VIC_SPR_ENABLE

    ; Ensure X/Y Expansion disabled for Sprites 2..7
    lda VIC_SPR_EXP_X
    and #$03
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    and #$03
    sta VIC_SPR_EXP_Y

    ; Priority: Sprites in front of background
    lda VIC_SPR_PRIORITY
    and #$03
    sta VIC_SPR_PRIORITY
    rts

; ==============================================================================
; Subroutine: enemies_spawn_archetype
; Purpose: Spawns an enemy of specified archetype (0..7) in a free slot.
; Input: A = archetype (0..7)
; ==============================================================================
enemies_spawn_archetype:
    pha                         ; Save archetype on stack

    ; Find free slot
    ldx #0
-   lda g_enemy_active, x
    beq @archetype_slot_found
    inx
    cpx #MAX_ENEMIES
    bne -

    ; All slots full: steal slot 0
    ldx #0

@archetype_slot_found:
    txa
    tay                         ; Y = enemy slot (0..11)
    lda #1
    sta g_enemy_active, y

    ; Spawn X off-screen right (X = 344: X_lo = 88, X_hi = 1)
    lda #88
    sta g_enemy_x_lo, y
    lda #1
    sta g_enemy_x_hi, y

    ; Spawn Y: random altitude (52..220)
    jsr enemies_get_random_spawn_y
    sta g_enemy_y, y
    sta g_enemy_base_y, y


    ; Reset enemy state flags
    lda #0
    sta g_enemy_dir_x, y
    sta g_enemy_entry_dir, y    ; Debug forced spawns use top spawn
    sta g_enemy_exploding, y
    sta g_enemy_flash, y
    sta g_enemy_roam_timer, y
    sta g_enemy_phase, y
    sta g_enemy_pattern, y

    pla                         ; Restore archetype (0..7)
    jmp enemy_setup_archetype_slot

; ==============================================================================
; Helper Subroutine: enemies_get_random_spawn_y
; Returns: A = random Y coordinate (52..220)
; ==============================================================================
enemies_get_random_spawn_y:
    jsr starfield_rand
    and #$7f
    clc
    adc #52
    sta s_spawn_y_temp
    jsr starfield_rand
    and #$1f
    clc
    adc s_spawn_y_temp
    cmp #221
    bcc +
    lda #220
+   rts

; ==============================================================================
; Helper Subroutine: enemies_get_random_spawn_x
; Returns: A = random X low byte, X = random X high byte (X coordinate = 140..267)
; ==============================================================================
enemies_get_random_spawn_x:
    jsr starfield_rand
    and #$7f                    ; 0..127
    clc
    adc #140                    ; 140..267 (safely in upper screen altitude)
    sta s_spawn_y_temp
    lda #0
    adc #0                      ; High byte (0 or 1 if >= 256)
    tax                         ; X = high byte
    lda s_spawn_y_temp          ; A = low byte
    rts

; ==============================================================================
; Subroutine: enemies_spawn
; Purpose: Spawns a new enemy at a randomized full-screen altitude (Y = 52..220).
; ==============================================================================
enemies_spawn:
    ; Count currently active enemies
    lda #0
    sta s_active_count
    ldx #0
-   lda g_enemy_active, x
    beq +
    inc s_active_count
+   inx
    cpx #MAX_ENEMIES
    bne -

    ; Max allowed active enemies (driven by elapsed game timeline):
    ; Lower density (max 5 simultaneous enemies) keeps the screen readable
    lda g_game_time_total_sec + 1
    bne @density_late           ; T >= 256s -> max 5

    lda g_game_time_total_sec + 0
    cmp #30
    bcs +
    ldy #2                      ; 0..29s: max 2
    jmp @check_density_limit

+   cmp #60
    bcs +
    ldy #3                      ; 30..59s: max 3
    jmp @check_density_limit

+   cmp #100
    bcs +
    ldy #4                      ; 60..99s: max 4
    jmp @check_density_limit

+   ldy #5                      ; 100s+: max 5
    jmp @check_density_limit

@density_late:
    ldy #5                      ; Deep game cap: max 5 enemies

@check_density_limit:
    cpy s_active_count
    beq @spawn_exit
    bcc @spawn_exit

@find_free_slot:
    ldx #0
-   lda g_enemy_active, x
    beq @slot_found
    inx
    cpx #MAX_ENEMIES
    bne -
@spawn_exit:
    rts

@slot_found:
    ; X = free enemy slot index (0..11)
    txa
    tay
    lda #1
    sta g_enemy_active, y

    ; Random entry selector: 50% Top, 25% Left side, 25% Right side
    jsr starfield_rand
    and #$03                    ; 0..3
    cmp #2
    bcs @spawn_from_top         ; 2, 3 -> Top spawn (50%)
    cmp #1
    beq @spawn_from_right       ; 1 -> Right side spawn (25%)

@spawn_from_left:
    ; Spawn on Left side (Y = 48, entering along soft curve into screen)
    lda #1
    sta g_enemy_entry_dir, y
    lda #48
    sta g_enemy_y, y
    lda #0
    sta g_enemy_dir_x, y        ; Start flank Left (dir_x = 0)
    beq @spawn_side_common

@spawn_from_right:
    ; Spawn on Right side (Y = 224, entering along soft curve into screen)
    lda #2
    sta g_enemy_entry_dir, y
    lda #224
    sta g_enemy_y, y
    lda #1
    sta g_enemy_dir_x, y        ; Start flank Right (dir_x = 1)

@spawn_side_common:
    lda #24
    sta g_enemy_curve_timer, y  ; 24-frame soft curve countdown (24..0)
    ; Random altitude/height along vertical screen: X = 140..267
    jsr enemies_get_random_spawn_x
    sta g_enemy_x_lo, y
    txa
    sta g_enemy_x_hi, y
    jmp @finish_spawn_pos


@spawn_from_top:
    ; Spawn from Top (X = 344, off-screen top in TATE)
    lda #0
    sta g_enemy_entry_dir, y
    sta g_enemy_curve_timer, y  ; 0 = No curve entry
    sta g_enemy_dir_x, y        ; Move down
    lda #88
    sta g_enemy_x_lo, y
    lda #1
    sta g_enemy_x_hi, y
    ; Random horizontal position (52..220)
    jsr enemies_get_random_spawn_y
    sta g_enemy_y, y
    sta g_enemy_base_y, y

@finish_spawn_pos:
    ; State cleanup
    lda #0
    sta g_enemy_exploding, y
    sta g_enemy_flash, y

    ; Select archetype (via one-shot debug spawn or progression timeline)
    lda g_first_spawn_force
    beq @use_timeline
    ldx #0
    stx g_first_spawn_force     ; Reset one-shot flag after use
    jmp @setup_archetype

@use_timeline:
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
    txa
    asl
    asl
    asl
    asl                         ; A = tier * 16 (0, 16, 32, 48, 64, 80, 96, 112)
    sta s_tier_offset_temp
    jsr starfield_rand
    and #$0f                    ; 16 entries per tier (0..15)
    clc
    adc s_tier_offset_temp
    tax
    lda tier_spawn_table, x     ; A = selected archetype (1..8)


    ; Spider (Enemy 6) Presence Guard: ensure at most 1 Spider active on screen
    cmp #6
    bne @check_e8_guard
    ldx #0
-   lda g_enemy_active, x
    beq +
    lda g_enemy_archetype, x
    cmp #6
    beq @downgrade_e6
+   inx
    cpx #MAX_ENEMIES
    bne -
    lda #6
    jmp @setup_archetype

@downgrade_e6:
    lda #5                      ; Downgrade to Enemy 5 (Batplane)
    jmp @setup_archetype

@check_e8_guard:
    ; Enemy 8 Presence Guard: ensure at most 1 Enemy 8 active on screen
    cmp #8
    bne @setup_archetype
    ldx #0
-   lda g_enemy_active, x
    beq +
    lda g_enemy_archetype, x
    cmp #8
    beq @downgrade_e8
+   inx
    cpx #MAX_ENEMIES
    bne -
    lda #8
    jmp @setup_archetype

@downgrade_e8:
    lda #7                      ; Downgrade to Enemy 7 (The Eye)

@setup_archetype:
enemy_setup_archetype_slot:
    sta g_enemy_archetype, y
    tax                         ; X = archetype index (1..8)

    ; Set sprite pointer & HP
    lda enemy_table_sprite, x
    sta g_enemy_type, y
    lda enemy_table_hp, x
    sta g_enemy_hp, y

    ; Set reload timer
    jsr starfield_rand
    and #$1f
    clc
    adc enemy_table_reload, x
    sta g_enemy_reload_timer, y

    ; Set speed
    lda enemy_table_speed, x
    sta g_enemy_speed, y

    ; Archetype-specific setup (1..8):
    cpx #1
    bne +
    jmp @setup_scout
+   cpx #2
    bne +
    jmp @setup_enemy2
+   cpx #3
    bne +
    jmp @setup_enemy3
+   cpx #4
    bne +
    jmp @setup_eye              ; Archetype 4: Scorpion (half circles towards bottom)
+   cpx #5
    bne +
    jmp @setup_batplane
+   cpx #6
    bne +
    jmp @setup_spider
+   cpx #7
    bne +
    jmp @setup_scorpion         ; Archetype 7: The Eye (8-direction random bounce)
+   cpx #8
    bne +
    jmp @setup_death
+   rts

@setup_scout:
    lda #0
    sta g_enemy_dir_x, y
    rts

@setup_enemy2:
    lda #0
    sta g_enemy_pattern, y
    jsr starfield_rand
    and #$0f
    clc
    adc #15
    sta g_enemy_roam_timer, y
    rts

@setup_enemy3:
    lda #0
    sta g_enemy_phase, y
    sta g_enemy_dir_x, y
    lda g_enemy_entry_dir, y
    bne +                       ; Side spawn preserves position
    lda #56
    sta g_enemy_y, y
    sta g_enemy_base_y, y
    jsr starfield_rand
    lsr
    bcc +
    lda #216
    sta g_enemy_y, y
    sta g_enemy_base_y, y
    lda #1
    sta g_enemy_dir_x, y
+   rts

@setup_scorpion:
    lda g_enemy_entry_dir, y
    bne +
    ; Archetype 7 (The Eye): Start at X = 280, random 8-direction bounce
    lda #24
    sta g_enemy_x_lo, y
    lda #1
    sta g_enemy_x_hi, y         ; Start at X = 280
+   jsr starfield_rand
    and #$07
    sta g_enemy_pattern, y
    jsr starfield_rand
    and #$1f
    clc
    adc #24
    sta g_enemy_roam_timer, y
    rts

@setup_batplane:
    lda #0
    sta g_enemy_phase, y
    sta g_enemy_pattern, y
    lda g_enemy_entry_dir, y
    bne +                       ; Side spawn already has target depth in base_y
    lda g_enemy_y, y
    sta g_enemy_base_y, y
+   jsr starfield_rand
    and #$1f
    clc
    adc #40
    sta g_enemy_roam_timer, y
    rts

@setup_spider:
    lda #0
    sta g_enemy_phase, y        ; Entering mode (flying to center)
    sta g_enemy_dir_x, y        ; Clockwise (0)
    lda #170
    sta g_enemy_pattern, y      ; Initial X_center = 170
    lda #136
    sta g_enemy_base_y, y       ; Initial Y_center = 136
    lda #8
    sta g_enemy_roam_timer, y
    rts

@setup_eye:
    lda g_enemy_entry_dir, y
    bne @setup_eye_side
    ; Archetype 4 (Scorpion): Start at top of screen (X = 280), ready to make half circles down
    lda #24
    sta g_enemy_x_lo, y
    lda #1
    sta g_enemy_x_hi, y         ; Start at X = 280
    jsr starfield_rand
    and #$3f
    clc
    adc #104                    ; Y_c = 104..167 (nicely centered)
    sta g_enemy_base_y, y
    sta g_enemy_y, y
    cmp #136
    lda #0                      ; Swing right if Y <= 136
    bcc +
    lda #$40                    ; Swing left if Y > 136
+   sta g_enemy_phase, y        ; Descend mode (0), step = 0, swing = 0 or $40
    rts

@setup_eye_side:
    ; Side spawn: initialize center Y and start in descend mode
    jsr starfield_rand
    and #$1f
    clc
    adc #120                    ; Y_c = 120..151 (screen center)
    sta g_enemy_base_y, y
    lda #0
    sta g_enemy_phase, y        ; Descend mode (0), step = 0, swing right (0)
    rts


@setup_death:
    lda g_enemy_entry_dir, y
    bne +
    ; Death starts at X = 260, random Vx and Vy in any direction
    lda #4
    sta g_enemy_x_lo, y
    lda #1
    sta g_enemy_x_hi, y         ; Start at X = 260
+   jsr starfield_rand
    and #$03
    tax
    lda death_vel_tab, x
    sta g_enemy_dir_x, y        ; Vx (-2, -1, 1, 2)
    jsr starfield_rand
    and #$03
    tax
    lda death_vel_tab, x
    sta g_enemy_pattern, y      ; Vy (-2, -1, 1, 2)
    jsr starfield_rand
    and #$1f
    clc
    adc #30
    sta g_enemy_roam_timer, y
    rts

; ==============================================================================
; Subroutine: enemies_update
; Purpose: Updates wave timers, enemies, and free-flying aimed bullets.
; ==============================================================================
enemies_update:
    ; 1. Enemy color cycling timer (25 frames = 0.5s in 50 Hz PAL)
    dec s_enemy_color_timer
    bne +
    lda #25
    sta s_enemy_color_timer
    dec s_enemy_color_idx
    bpl +
    lda #5
    sta s_enemy_color_idx
+
    ; 2. Wave Spawn Timer
    dec g_wave_spawn_timer
    bne @update_entities

    ; Timer fired: spawn an enemy
    jsr enemies_spawn

    ; Reset timer based on elapsed time:
    lda g_game_time_total_sec + 1
    bne @late_spawn             ; T >= 256s

    lda g_game_time_total_sec + 0
    cmp #45
    bcs @after_45s

    ; Phase 1 (0..44s): 50..65 frames (~1.0..1.3s per spawn)
    jsr starfield_rand
    and #$0f
    clc
    adc #50
    sta g_wave_spawn_timer
    jmp @update_entities

@after_45s:
    cmp #90
    bcs @after_90s

    ; Phase 2 (45..89s): 40..55 frames (~0.8..1.1s per spawn)
    jsr starfield_rand
    and #$0f
    clc
    adc #40
    sta g_wave_spawn_timer
    jmp @update_entities

@after_90s:
    cmp #150
    bcs @late_spawn

    ; Phase 3 (90..149s): 35..48 frames (~0.7..1.0s per spawn)
    jsr starfield_rand
    and #$0d
    clc
    adc #35
    sta g_wave_spawn_timer
    jmp @update_entities

@late_spawn:
    ; Phase 4 (150s+): 30..42 frames (~0.6..0.85s per spawn)
    jsr starfield_rand
    and #$0c
    clc
    adc #30
    sta g_wave_spawn_timer

@update_entities:
    ; 3. Move & Update All 12 Enemies
    ldx #0
@enemy_loop:
    lda g_enemy_active, x
    bne @enemy_active
    jmp @next_enemy_upd

@enemy_active:
    ; Flash timer
    lda g_enemy_flash, x
    beq +
    dec g_enemy_flash, x
    lda #COLOR_WHITE
    sta g_enemy_color, x
    bne @skip_color

+   ; Spider (Archetype 6) always has main color = Light Gray ($0F)
    ; All other enemies (including Archetype 7 The Eye and Archetype 8 Death) cycle energy colors
    ldy g_enemy_archetype, x
    cpy #6
    bne @cycle_color
    lda #COLOR_LIGHT_GRAY
    bne @store_color

@cycle_color:
    txa
    clc
    adc s_enemy_color_idx
    tay
    lda enemy_energy_colors, y

@store_color:
    sta g_enemy_color, x
@skip_color:
    ; Explosion timer
    lda g_enemy_exploding, x
    beq @not_exploding
    dec g_enemy_exploding, x
    beq @exp_done

    ; Cycle energy color one per frame during explosion
    ldy g_energy_cycle_idx
    lda g_energy_colors, y
    sta g_enemy_color, x

    lda #SPRITE_PTR_EXPLOSION_1
    ldy g_enemy_exploding, x
    cpy #8
    bcs +
    lda #SPRITE_PTR_EXPLOSION_2
    cpy #4
    bcs +
    lda #SPRITE_PTR_EXPLOSION_3
+   sta g_enemy_type, x
    jmp @next_enemy_upd
@exp_done:
    lda #0
    sta g_enemy_active, x
    jmp @next_enemy_upd

@not_exploding:
    lda g_enemy_entry_dir, x
    beq @normal_archetype_movement
    jmp @move_side_entry

@normal_archetype_movement:
    lda g_enemy_archetype, x
    cmp #1
    bne +
    jmp @move_scout             ; Archetype 1: Scout
+   cmp #2
    bne +
    jmp @move_enemy2            ; Archetype 2: Light Fighter
+   cmp #3
    bne +
    jmp @move_enemy3            ; Archetype 3: Interceptor
+   cmp #4
    bne +
    jmp @move_eye               ; Archetype 4: Scorpion (half circles towards bottom)
+   cmp #5
    bne +
    jmp @move_batplane          ; Archetype 5: Batplane
+   cmp #6
    bne +
    jmp @move_spider            ; Archetype 6: Spider
+   cmp #7
    bne +
    jmp @move_scorpion          ; Archetype 7: The Eye (8-direction random bounce)
+   cmp #8
    bne +
    jmp @move_death             ; Archetype 8: Death
+   jmp @next_enemy_upd

@move_side_entry:
    ; 1. Look up curve velocity deltas from dedicated countdown timer (24..0)
    lda g_enemy_curve_timer, x
    beq @side_entry_done
    sec
    sbc #1
    sta g_enemy_curve_timer, x
    lsr
    lsr                         ; (23..0) >> 2 -> Segment 5..0
    cmp #6
    bcc +
    lda #5                      ; Safety clamp to table bounds (0..5)
+   tay
    lda curve_dy_tab, y
    sta s_curve_dy_temp
    lda curve_dx_tab, y
    sta s_curve_dx_temp

    ; 2. Apply horizontal movement (Y)
    lda g_enemy_entry_dir, x
    cmp #1
    bne @side_curve_from_right

@side_curve_from_left:
    ; Left entry: Y increases into screen
    lda g_enemy_y, x
    clc
    adc s_curve_dy_temp
    sta g_enemy_y, x
    jmp @side_curve_apply_x

@side_curve_from_right:
    ; Right entry: Y decreases into screen
    lda g_enemy_y, x
    sec
    sbc s_curve_dy_temp
    sta g_enemy_y, x

@side_curve_apply_x:
    ; 3. Apply vertical movement (swoop down towards player)
    lda g_enemy_x_lo, x
    sec
    sbc s_curve_dx_temp
    sta g_enemy_x_lo, x
    bcs @side_curve_advance
    dec g_enemy_x_hi, x

@side_curve_advance:
    ; 4. Check if curve completed this frame
    lda g_enemy_curve_timer, x
    bne @side_curve_shoot

@side_entry_done:
    ; Timer expired: soft curve is complete!
    ; Clear entry flag to transition into archetype flight:
    lda #0
    sta g_enemy_entry_dir, x
    ; For Archetype 4 (Scorpion), initialize descent seamlessly from current position
    lda g_enemy_archetype, x
    cmp #4
    bne @side_curve_shoot
    lda g_enemy_y, x
    cmp #110
    bcs +
    lda #110
+   cmp #161
    bcc +
    lda #160
+   sta g_enemy_base_y, x
    lda g_enemy_y, x
    cmp #136
    lda #0                      ; Swing right if Y <= 136
    bcc +
    lda #$40                    ; Swing left if Y > 136
+   sta g_enemy_phase, x        ; Descend mode (0), step = 0


@side_curve_shoot:
    ; Check if within screen boundaries (50 <= Y <= 222) to allow shooting
    lda g_enemy_y, x
    cmp #50
    bcc +
    cmp #223
    bcs +
    jmp @check_shooting
+   jmp @next_enemy_upd

@move_scout:
    lda #80

@move_patrol:
    sta s_patrol_limit
    lda g_enemy_dir_x, x
    bne @patrol_move_up

@patrol_move_down:
    lda g_enemy_x_lo, x
    sec
    sbc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+   lda g_enemy_x_hi, x
    bne @patrol_shoot
    lda g_enemy_x_lo, x
    cmp s_patrol_limit
    bcs @patrol_shoot
    lda s_patrol_limit
    sta g_enemy_x_lo, x
    lda #1
    sta g_enemy_dir_x, x
    bne @patrol_shoot

@patrol_move_up:
    lda g_enemy_x_lo, x
    clc
    adc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcc +
    inc g_enemy_x_hi, x
+   lda g_enemy_x_hi, x
    beq @patrol_shoot
    lda g_enemy_x_lo, x
    cmp #24                     ; 256 + 24 = 280
    bcc @patrol_shoot
    lda #24
    sta g_enemy_x_lo, x
    lda #0
    sta g_enemy_dir_x, x

@patrol_shoot:
    jmp @check_shooting

@move_enemy2:
    ; "Enemy 2 will erratically go straight or in diagonals, randomly."
    ; "don't make any enemy escape the screen, let them hang out until destroyed"
    lda g_enemy_dir_x, x
    bne @e2_move_up

@e2_move_down:
    lda g_enemy_x_lo, x
    sec
    sbc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+   ; Check bottom bounce at X <= 60
    lda g_enemy_x_hi, x
    bne @e2_timer
    lda g_enemy_x_lo, x
    cmp #60
    bcs @e2_timer
    lda #60
    sta g_enemy_x_lo, x
    lda #1
    sta g_enemy_dir_x, x        ; Bounce: now moving up!
    jmp @e2_timer

@e2_move_up:
    lda g_enemy_x_lo, x
    clc
    adc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcc +
    inc g_enemy_x_hi, x
+   ; Check top bounce at X >= 280 ($0118)
    lda g_enemy_x_hi, x
    beq @e2_timer
    lda g_enemy_x_lo, x
    cmp #24                     ; 256 + 24 = 280
    bcc @e2_timer
    lda #24
    sta g_enemy_x_lo, x
    lda #0
    sta g_enemy_dir_x, x        ; Bounce: now moving down!

@e2_timer:
    ; 2. Erratic timer countdown
    dec g_enemy_roam_timer, x
    bne @e2_lateral
    ; Timer expired: pick new random direction
    jsr starfield_rand
    and #$03                    ; 0..3
    cmp #3
    bne +
    lda #0                      ; 0 or 3 = straight (dy = 0)
+   sta g_enemy_pattern, x
    ; Reset timer to 16..39 frames
    jsr starfield_rand
    and #$17
    clc
    adc #16
    sta g_enemy_roam_timer, x

@e2_lateral:
    ; 3. Lateral motion: 0 = straight, 1 = diagonal left, 2 = diagonal right
    lda g_enemy_pattern, x
    beq @e2_shoot               ; dy = 0
    cmp #1
    beq @e2_diag_left

@e2_diag_right:
    ; Move right (increasing Y)
    lda g_enemy_y, x
    clc
    adc g_enemy_speed, x
    cmp #220
    bcc @e2_store_y
    lda #1                      ; Hit right wall: bounce to diagonal left
    sta g_enemy_pattern, x
    lda #220
    bne @e2_store_y

@e2_diag_left:
    ; Move left (decreasing Y)
    lda g_enemy_y, x
    sec
    sbc g_enemy_speed, x
    cmp #52
    bcs @e2_store_y
    lda #2                      ; Hit left wall: bounce to diagonal right
    sta g_enemy_pattern, x
    lda #52

@e2_store_y:
    sta g_enemy_y, x
@e2_shoot:
    jmp @check_shooting

@move_enemy3:
    ; "Enemy 3 will spawn in either side, go straight down, sweep throught the bottom and go back up on the other side."
    ; "namely enemy 3 should do its round and repeat it indefinitely"
    lda g_enemy_phase, x
    bne +
    jmp @e3_phase0
+   cmp #1
    bne +
    jmp @e3_phase1
+   cmp #2
    bne +
    jmp @e3_phase2
+   jmp @e3_phase3

@e3_phase0:
    ; Phase 0: Go down (decreasing X)
    lda g_enemy_x_lo, x
    sec
    sbc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+   ; Soft curve into bottom sweep when approaching bottom (X <= 90)
    lda g_enemy_x_hi, x
    bne @e3_p0_done             ; X >= 256
    lda g_enemy_x_lo, x
    cmp #90
    bcs @e3_p0_done             ; X > 90 -> purely vertical
    ; In curve zone: also advance Y towards destination flank!
    lda g_enemy_dir_x, x
    bne @e3_p0_curve_left
@e3_p0_curve_right:
    inc g_enemy_y, x
    jmp @e3_p0_check_bottom
@e3_p0_curve_left:
    dec g_enemy_y, x
@e3_p0_check_bottom:
    lda g_enemy_x_lo, x
    cmp #70
    bcs @e3_p0_done
    lda #70
    sta g_enemy_x_lo, x
    lda #0
    sta g_enemy_x_hi, x
    lda #1
    sta g_enemy_phase, x        ; Bottom reached: enter Phase 1 (horizontal sweep)
@e3_p0_done:
    jmp @check_shooting

@e3_phase1:
    ; Phase 1: Sweep through bottom
    lda g_enemy_dir_x, x
    bne @e3_p1_sweep_left

@e3_p1_sweep_right:
    lda g_enemy_y, x
    clc
    adc g_enemy_speed, x
    sta g_enemy_y, x
    ; Soft curve upwards when approaching right flank (Y >= 196)
    cmp #196
    bcc @e3_p1_done
    ; 16-bit X increment
    lda g_enemy_x_lo, x
    clc
    adc #1
    sta g_enemy_x_lo, x
    bcc +
    inc g_enemy_x_hi, x
+   lda g_enemy_y, x
    cmp #216
    bcc @e3_p1_done
    lda #216
    sta g_enemy_y, x
    lda #2
    sta g_enemy_phase, x        ; Reached right flank: enter Phase 2 (go up)
    jmp @e3_p1_done

@e3_p1_sweep_left:
    lda g_enemy_y, x
    sec
    sbc g_enemy_speed, x
    sta g_enemy_y, x
    ; Soft curve upwards when approaching left flank (Y <= 76)
    cmp #77
    bcs @e3_p1_done
    ; 16-bit X increment
    lda g_enemy_x_lo, x
    clc
    adc #1
    sta g_enemy_x_lo, x
    bcc +
    inc g_enemy_x_hi, x
+   lda g_enemy_y, x
    cmp #56
    bcs @e3_p1_done
    lda #56
    sta g_enemy_y, x
    lda #2
    sta g_enemy_phase, x        ; Reached left flank: enter Phase 2 (go up)

@e3_p1_done:
    jmp @check_shooting

@e3_phase2:
    ; Phase 2: Go back up on the other side (increasing X)
    lda g_enemy_x_lo, x
    clc
    adc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcc +
    inc g_enemy_x_hi, x
+   ; Soft curve into top sweep when approaching top (X >= 260: X_hi=1 and X_lo >= 4)
    lda g_enemy_x_hi, x
    beq @e3_p2_done             ; X < 256
    lda g_enemy_x_lo, x
    cmp #4
    bcc @e3_p2_done             ; X < 260
    ; In curve zone: also advance Y towards return flank!
    lda g_enemy_dir_x, x
    bne @e3_p2_curve_right
@e3_p2_curve_left:
    dec g_enemy_y, x
    jmp @e3_p2_check_top
@e3_p2_curve_right:
    inc g_enemy_y, x
@e3_p2_check_top:
    lda g_enemy_x_lo, x
    cmp #24                     ; 256 + 24 = 280
    bcc @e3_p2_done
    lda #24
    sta g_enemy_x_lo, x
    lda #1
    sta g_enemy_x_hi, x
    lda #3
    sta g_enemy_phase, x        ; Top reached: enter Phase 3 (sweep top)

@e3_p2_done:
    jmp @check_shooting

@e3_phase3:
    ; Phase 3: Sweep through the top back to starting flank
    lda g_enemy_dir_x, x
    bne @e3_p3_sweep_right

@e3_p3_sweep_left:
    lda g_enemy_y, x
    sec
    sbc g_enemy_speed, x
    sta g_enemy_y, x
    ; Soft curve downwards when approaching starting flank (Y <= 76)
    cmp #77
    bcs @e3_p3_done
    ; 16-bit X decrement
    lda g_enemy_x_lo, x
    sec
    sbc #1
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+   lda g_enemy_y, x
    cmp #56
    bcs @e3_p3_done
    lda #56
    sta g_enemy_y, x
    lda #0
    sta g_enemy_phase, x        ; Reached starting flank: enter Phase 0 (dive down)!
    jmp @e3_p3_done

@e3_p3_sweep_right:
    lda g_enemy_y, x
    clc
    adc g_enemy_speed, x
    sta g_enemy_y, x
    ; Soft curve downwards when approaching starting flank (Y >= 196)
    cmp #196
    bcc @e3_p3_done
    ; 16-bit X decrement
    lda g_enemy_x_lo, x
    sec
    sbc #1
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+   lda g_enemy_y, x
    cmp #216
    bcc @e3_p3_done
    lda #216
    sta g_enemy_y, x
    lda #0
    sta g_enemy_phase, x        ; Reached starting flank: enter Phase 0 (dive down)!

@e3_p3_done:
    jmp @check_shooting

; ==============================================================================
; Archetype 7: The Eye (and Batplane Straight Mode)
; "the eye will randomly move in diagonal or in 4 straight directions"
; "don't make any enemy escape the screen, let them hang out until destroyed"
; Directions (0..7):
; 0: Down (-X), 1: Up (+X), 2: Left (-Y), 3: Right (+Y)
; 4: Down-Left (-X,-Y), 5: Down-Right (-X,+Y), 6: Up-Left (+X,-Y), 7: Up-Right (+X,+Y)
; ==============================================================================
@move_scorpion:
    dec g_enemy_roam_timer, x
    bne @scorp_move
    ; Roam timer expired: pick new random direction (0..7)
    jsr starfield_rand
    and #$07
    sta g_enemy_pattern, x
    ; Reset timer to 24..55 frames (~0.5..1.1s)
    jsr starfield_rand
    and #$1f
    clc
    adc #24
    sta g_enemy_roam_timer, x

@scorp_move:
    ; 1. Process X movement component
    ldy g_enemy_pattern, x
    lda scorp_dx_tab, y
    beq @scorp_check_y
    bmi @scorp_down

@scorp_up:
    lda g_enemy_x_lo, x
    clc
    adc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcc +
    inc g_enemy_x_hi, x
+   ; Check top bounce: X >= 280 (X_hi >= 1 and X_lo >= 24)
    lda g_enemy_x_hi, x
    beq @scorp_check_y
    lda g_enemy_x_lo, x
    cmp #24
    bcc @scorp_check_y
    lda #24
    sta g_enemy_x_lo, x
    ; Bounce X: reverse vertical component
    lda g_enemy_pattern, x
    cmp #4
    bcs +
    eor #1                      ; 1 (Up) -> 0 (Down)
    sta g_enemy_pattern, x
    bne @scorp_check_y
+   eor #2                      ; 6,7 (Up-L/R) -> 4,5 (Down-L/R)
    sta g_enemy_pattern, x
    bne @scorp_check_y

@scorp_down:
    lda g_enemy_x_lo, x
    sec
    sbc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+   ; Check bottom bounce: X <= 60
    lda g_enemy_x_hi, x
    bne @scorp_check_y
    lda g_enemy_x_lo, x
    cmp #60
    bcs @scorp_check_y
    lda #60
    sta g_enemy_x_lo, x
    ; Bounce X: reverse vertical component
    lda g_enemy_pattern, x
    cmp #4
    bcs +
    eor #1                      ; 0 (Down) -> 1 (Up)
    sta g_enemy_pattern, x
    bne @scorp_check_y
+   eor #2                      ; 4,5 (Down-L/R) -> 6,7 (Up-L/R)
    sta g_enemy_pattern, x

@scorp_check_y:
    ; 2. Process Y movement component
    ldy g_enemy_pattern, x
    lda scorp_dy_tab, y
    beq @scorp_shoot
    bmi @scorp_left

@scorp_right:
    lda g_enemy_y, x
    clc
    adc g_enemy_speed, x
    cmp #220
    bcc @scorp_store_y
    lda #220
    sta g_enemy_y, x
    ; Bounce Y: reverse horizontal component (always EOR #1)
    lda g_enemy_pattern, x
    eor #1
    sta g_enemy_pattern, x
    bne @scorp_shoot

@scorp_left:
    lda g_enemy_y, x
    sec
    sbc g_enemy_speed, x
    cmp #52
    bcs @scorp_store_y
    lda #52
    sta g_enemy_y, x
    ; Bounce Y: reverse horizontal component (always EOR #1)
    lda g_enemy_pattern, x
    eor #1
    sta g_enemy_pattern, x

@scorp_store_y:
    sta g_enemy_y, x

@scorp_shoot:
    jmp @check_shooting

; ==============================================================================
; Archetype 4: The Batplane
; "the batplane will switch between 4 straight directions and a sinus."
; "don't make any enemy escape the screen, let them hang out until destroyed"
; State:
; g_enemy_phase: Bit 7 = 0: 4 straight directions mode
;                Bit 7 = 1: Sinus mode (Bits 0..4 = phase angle 0..31)
; g_enemy_pattern: In straight: direction (0=Down, 1=Up, 2=Left, 3=Right)
;                  In sinus: primary X direction (0=Down, 1=Up)
; g_enemy_base_y: Baseline Y altitude for sinus oscillation
; ==============================================================================


@move_batplane:
    dec g_enemy_roam_timer, x
    bne @bat_execute

    ; Timer expired: switch modes!
    lda g_enemy_phase, x
    bmi @bat_switch_to_straight

@bat_switch_to_sinus:
    ; Currently straight -> switch to sinus!
    lda #$80                    ; Bit 7 = 1 (sinus mode), phase angle = 0
    sta g_enemy_phase, x
    lda g_enemy_y, x
    sta g_enemy_base_y, x
    ; Pick X direction: if X >= 160 move Down (0), else move Up (1)
    lda g_enemy_x_hi, x
    bne +
    lda g_enemy_x_lo, x
    cmp #160
+   bcs @bat_sin_down
    lda #1                      ; Move Up
    bne @bat_sin_dir_set
@bat_sin_down:
    lda #0                      ; Move Down
@bat_sin_dir_set:
    sta g_enemy_pattern, x
    ; Sinus duration: 50..81 frames (~1.0..1.6s)
    jsr starfield_rand
    and #$1f
    clc
    adc #50
    sta g_enemy_roam_timer, x
    bne @bat_execute

@bat_switch_to_straight:
    ; Currently sinus -> switch to 4 straight directions!
    lda #0
    sta g_enemy_phase, x
    jsr starfield_rand
    and #$03                    ; 0..3: Down, Up, Left, Right
    sta g_enemy_pattern, x
    ; Straight duration: 40..71 frames (~0.8..1.4s)
    jsr starfield_rand
    and #$1f
    clc
    adc #40
    sta g_enemy_roam_timer, x

@bat_execute:
    lda g_enemy_phase, x
    bpl @bat_straight_move

@bat_sinus_move:
    ; 1. Primary X motion (0 = Down, 1 = Up)
    lda g_enemy_pattern, x
    bne @bat_sin_up

@bat_sin_down_mv:
    lda g_enemy_x_lo, x
    sec
    sbc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+   ; Check bottom turnaround at X <= 60
    lda g_enemy_x_hi, x
    bne @bat_sin_y
    lda g_enemy_x_lo, x
    cmp #60
    bcs @bat_sin_y
    lda #60
    sta g_enemy_x_lo, x
    lda #1
    sta g_enemy_pattern, x      ; Turn around: move Up
    bne @bat_sin_y

@bat_sin_up:
    lda g_enemy_x_lo, x
    clc
    adc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcc +
    inc g_enemy_x_hi, x
+   ; Check top turnaround at X >= 280
    lda g_enemy_x_hi, x
    beq @bat_sin_y
    lda g_enemy_x_lo, x
    cmp #24                     ; 280
    bcc @bat_sin_y
    lda #24
    sta g_enemy_x_lo, x
    lda #0
    sta g_enemy_pattern, x      ; Turn around: move Down

@bat_sin_y:
    ; 2. Advance sinus phase angle and apply oscillation
    inc g_enemy_phase, x
    lda g_enemy_phase, x
    and #$1f
    tay
    lda g_enemy_sine_table, y
    clc
    adc g_enemy_base_y, x
    cmp #52
    bcs +
    lda #52
+   cmp #221
    bcc +
    lda #220
+   sta g_enemy_y, x
    jmp @check_shooting

@bat_straight_move:
    ; Batplane in 4 straight directions (0=Down, 1=Up, 2=Left, 3=Right)
    ; Directly executes @scorp_move with directions 0..3!
    jmp @scorp_move

; ==============================================================================
; Archetype 6: The Spider
; "the spider will roam in circles roughly around the center, randomly"
; "don't make any enemy escape the screen, let them hang out until destroyed"
; State:
; g_enemy_phase: Bit 7 = 0: Entering screen (smoothly steering to (195, 136))
;                Bit 7 = 1: Circling mode (Bits 0..4 = phase angle 0..31)
; g_enemy_dir_x: 0 = Clockwise (+phase), 1 = Counter-clockwise (-phase)
; g_enemy_pattern: Current center X coordinate (155..185)
; g_enemy_base_y:  Current center Y coordinate (120..152)
; ==============================================================================
@move_spider:
    lda g_enemy_phase, x
    bmi @spider_circling

@spider_entering:
    ; 1. Steer Y smoothly towards 136 (1 px/frame)
    lda g_enemy_y, x
    cmp #136
    beq @spider_enter_x
    bcc +
    dec g_enemy_y, x
    jmp @spider_enter_x
+   inc g_enemy_y, x

@spider_enter_x:
    ; 2. Steer X towards 195
    lda g_enemy_x_hi, x
    bne @spider_enter_x_hi_dec  ; X >= 256
    lda g_enemy_x_lo, x
    cmp #195
    beq @spider_enter_check_done
    bcc @spider_enter_x_inc
    ; X > 195: decrease by 2 towards 195
    sec
    sbc #2
    cmp #195
    bcs +
    lda #195
+   sta g_enemy_x_lo, x
    jmp @spider_shoot

@spider_enter_x_hi_dec:
    lda g_enemy_x_lo, x
    sec
    sbc #2
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+   jmp @spider_shoot

@spider_enter_x_inc:
    clc
    adc #1
    sta g_enemy_x_lo, x
    jmp @spider_shoot

@spider_enter_check_done:
    ; X == 195. Has Y also reached 136?
    lda g_enemy_y, x
    cmp #136
    beq @spider_enter_transition
    jmp @spider_shoot           ; Not yet, hold X=195 while Y finishes arriving

@spider_enter_transition:
    ; Both arrived at (195, 136)! Activate circling mode with zero jump
    lda #$80
    sta g_enemy_phase, x        ; Bit 7 = 1 (circling), angle = 0
    lda #170
    sta g_enemy_pattern, x      ; X_center = 170
    lda #136
    sta g_enemy_base_y, x       ; Y_center = 136
    lda #8
    sta g_enemy_roam_timer, x
    jmp @spider_shoot


@spider_circling:
    ; 1. Roam timer: every 8 frames, drift center by at most 1 pixel (gentle Brownian motion)
    dec g_enemy_roam_timer, x
    bne @spider_step_circle
    lda #8
    sta g_enemy_roam_timer, x

    ; Random drift for X_center (g_enemy_pattern, 155..185):
    jsr starfield_rand
    and #$07
    cmp #0
    bne +
    lda g_enemy_pattern, x
    cmp #156
    bcc @drift_y
    dec g_enemy_pattern, x
    jmp @drift_y
+   cmp #1
    bne @drift_y
    lda g_enemy_pattern, x
    cmp #184
    bcs @drift_y
    inc g_enemy_pattern, x

@drift_y:
    ; Random drift for Y_center (g_enemy_base_y, 120..152):
    jsr starfield_rand
    and #$07
    cmp #0
    bne +
    lda g_enemy_base_y, x
    cmp #121
    bcc @drift_dir
    dec g_enemy_base_y, x
    jmp @drift_dir
+   cmp #1
    bne @drift_dir
    lda g_enemy_base_y, x
    cmp #151
    bcs @drift_dir
    inc g_enemy_base_y, x

@drift_dir:
    ; Rare chance (1 in 32 every 8 frames) to reverse rotation direction
    jsr starfield_rand
    and #$1f
    bne @spider_step_circle
    lda g_enemy_dir_x, x
    eor #1
    sta g_enemy_dir_x, x

@spider_step_circle:
    ; 2. Advance phase angle (Clockwise = +1, Counter-clockwise = -1)
    lda g_enemy_phase, x
    and #$1f
    ldy g_enemy_dir_x, x
    bne @spider_step_ccw
@spider_step_cw:
    clc
    adc #1
    jmp @spider_phase_wrapped
@spider_step_ccw:
    sec
    sbc #1
@spider_phase_wrapped:
    and #$1f
    ora #$80                    ; Preserve Bit 7 (circling active)
    sta g_enemy_phase, x

    ; 3. Calculate Y = Y_center + sin(phase)
    and #$1f
    tay
    lda g_enemy_sine_table, y   ; Signed offset (-25..+25)
    clc
    adc g_enemy_base_y, x       ; + Y_center (120..152)
    sta g_enemy_y, x

    ; 4. Calculate X = X_center + cos(phase) = X_center + sin(phase + 8)
    lda g_enemy_phase, x
    clc
    adc #8
    and #$1f
    tay
    lda g_enemy_sine_table, y   ; Signed offset (-25..+25)
    clc
    adc g_enemy_pattern, x      ; + X_center (155..185)
    sta g_enemy_x_lo, x
    lda #0
    sta g_enemy_x_hi, x

@spider_shoot:
    jmp @check_shooting

; ==============================================================================
; Archetype 4: The Scorpion
; Moves in smooth, predictable half-circles (32 steps, 1 px/frame descent/ascent).
; g_enemy_phase:
;   Bit 7: Vertical direction (0 = Descending down towards player, 1 = Ascending back up)
;   Bit 6: Lateral swing (0 = Swing right +dy, 1 = Swing left -dy)
;   Bits 0..4: Step index k (0..31, 32 frames per semicircle)
; g_enemy_base_y: Center Y coordinate (Y_c)
; ==============================================================================
@move_eye:
    ; 1. Vertical Movement in X (1 px/frame, steady and predictable)
    lda g_enemy_phase, x
    bmi @sc4_move_up

@sc4_move_down:
    ; Descending towards player
    lda g_enemy_x_lo, x
    sec
    sbc #1
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+   ; Check if reached bottom turn-around limit (X <= 75)
    lda g_enemy_x_hi, x
    bne @sc4_lateral            ; X >= 256
    lda g_enemy_x_lo, x
    cmp #75
    bcs @sc4_lateral
    ; Reached bottom: smoothly reverse vertical direction to ascend (Bit 7 = 1)
    lda g_enemy_phase, x
    ora #$80
    sta g_enemy_phase, x
    bne @sc4_lateral

@sc4_move_up:
    ; Ascending back up towards top of screen
    lda g_enemy_x_lo, x
    clc
    adc #1
    sta g_enemy_x_lo, x
    bcc +
    inc g_enemy_x_hi, x
+   ; Check if reached top turn-around limit (X >= 275 -> 256 + 19)
    lda g_enemy_x_hi, x
    beq @sc4_lateral            ; X < 256
    lda g_enemy_x_lo, x
    cmp #19
    bcc @sc4_lateral
    ; Reached top: smoothly reverse vertical direction to descend (Bit 7 = 0)
    lda g_enemy_phase, x
    and #$7f
    sta g_enemy_phase, x

@sc4_lateral:
    ; 2. Advance half-circle step index k (0..31)
    lda g_enemy_phase, x
    and #$1f                    ; Current step k (0..31)
    clc
    adc #1
    cmp #32
    bcc @sc4_same_semi

    ; Semicircle completed! Reset step to 0 and toggle swing direction (Bit 6)
    lda g_enemy_phase, x
    eor #$40                    ; Toggle swing direction (0 <-> $40)
    and #$c0                    ; Keep Bits 7 & 6, clear step bits to 0
    sta g_enemy_phase, x
    ldy #0                      ; Step 0
    jmp @sc4_calc_y

@sc4_same_semi:
    ; Store incremented step into Bits 0..4, preserving Bits 7 & 6
    tay                         ; Y = new step k (1..31)
    lda g_enemy_phase, x
    and #$c0
    sty s_mask_temp
    ora s_mask_temp
    sta g_enemy_phase, x

@sc4_calc_y:
    ; Y contains step k (0..31)
    lda scorp_curve_dy_tab, y
    sta s_spawn_y_temp

    lda g_enemy_phase, x
    and #$40                    ; Bit 6 = 1: swing left, 0: swing right
    bne @sc4_swing_left

@sc4_swing_right:
    lda g_enemy_base_y, x
    clc
    adc s_spawn_y_temp
    jmp @sc4_clamp_y

@sc4_swing_left:
    lda g_enemy_base_y, x
    sec
    sbc s_spawn_y_temp

@sc4_clamp_y:
    cmp #52
    bcs +
    lda #52
+   cmp #221
    bcc +
    lda #220
+   sta g_enemy_y, x

@sc4_shoot:
    jmp @check_shooting

; ==============================================================================
; Archetype 8: Death
; "Death should move completely random only in any direction"
; "don't make any enemy escape the screen, let them hang out until destroyed"
; ==============================================================================
@move_death:
    dec g_enemy_roam_timer, x
    bne @death_move

@death_pick_dir:
    jsr starfield_rand
    and #$03
    tay
    lda death_vel_tab, y
    sta g_enemy_dir_x, x        ; Vx (-2, -1, 1, 2)
    jsr starfield_rand
    and #$03
    tay
    lda death_vel_tab, y
    sta g_enemy_pattern, x      ; Vy (-2, -1, 1, 2)
    jsr starfield_rand
    and #$1f
    clc
    adc #30
    sta g_enemy_roam_timer, x

@death_move:
    ; 1. Move X by Vx
    lda g_enemy_dir_x, x
    beq @death_move_y
    bpl @death_x_pos

@death_x_neg:
    ; Vx is negative: move down (towards bottom, decreasing X)
    lda g_enemy_dir_x, x
    eor #$ff
    clc
    adc #1
    sta s_spawn_y_temp          ; |Vx|
    lda g_enemy_x_lo, x
    sec
    sbc s_spawn_y_temp
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+   ; Check bottom screen limit: X <= 60
    lda g_enemy_x_hi, x
    bne @death_move_y
    lda g_enemy_x_lo, x
    cmp #60
    bcs @death_move_y
    ; Hit bottom: clamp and bounce (reverse Vx)
    lda #60
    sta g_enemy_x_lo, x
    lda g_enemy_dir_x, x
    eor #$ff
    clc
    adc #1
    sta g_enemy_dir_x, x
    jmp @death_move_y

@death_x_pos:
    ; Vx is positive: move up (towards top, increasing X)
    lda g_enemy_x_lo, x
    clc
    adc g_enemy_dir_x, x
    sta g_enemy_x_lo, x
    bcc +
    inc g_enemy_x_hi, x
+   ; Check top screen limit: X >= 280 (X_hi >= 1 and X_lo >= 24)
    lda g_enemy_x_hi, x
    beq @death_move_y
    lda g_enemy_x_lo, x
    cmp #24
    bcc @death_move_y
    ; Hit top: clamp and bounce (reverse Vx)
    lda #24
    sta g_enemy_x_lo, x
    lda g_enemy_dir_x, x
    eor #$ff
    clc
    adc #1
    sta g_enemy_dir_x, x

@death_move_y:
    ; 2. Move Y by Vy
    lda g_enemy_pattern, x
    beq @death_shoot
    bpl @death_y_pos

@death_y_neg:
    ; Vy is negative: move left (decreasing Y)
    lda g_enemy_pattern, x
    eor #$ff
    clc
    adc #1
    sta s_spawn_y_temp          ; |Vy|
    lda g_enemy_y, x
    sec
    sbc s_spawn_y_temp
    cmp #52
    bcs @death_store_y
    ; Hit left wall: clamp and bounce (reverse Vy)
    lda #52
    sta g_enemy_y, x
    lda g_enemy_pattern, x
    eor #$ff
    clc
    adc #1
    sta g_enemy_pattern, x
    jmp @death_shoot

@death_y_pos:
    ; Vy is positive: move right (increasing Y)
    lda g_enemy_y, x
    clc
    adc g_enemy_pattern, x
    cmp #220
    bcc @death_store_y
    ; Hit right wall: clamp and bounce (reverse Vy)
    lda #220
    sta g_enemy_y, x
    lda g_enemy_pattern, x
    eor #$ff
    clc
    adc #1
    sta g_enemy_pattern, x
    jmp @death_shoot

@death_store_y:
    sta g_enemy_y, x

@death_shoot:
    jmp @check_shooting

@check_shooting:
    ; Check if within firing range: 60 <= X <= 300
    lda g_enemy_x_hi, x
    beq @check_left_x
    lda g_enemy_x_lo, x
    cmp #45                     ; X <= 300
    bcs @next_enemy_upd
    jmp @can_fire
@check_left_x:
    lda g_enemy_x_lo, x
    cmp #60
    bcc @next_enemy_upd

@can_fire:
    dec g_enemy_reload_timer, x
    bne @next_enemy_upd

    ; Reload timer reached 0: re-arm
    ldy g_enemy_archetype, x
    txa
    pha
    jsr starfield_rand
    and #$1f
    clc
    adc enemy_table_reload, y
    sta s_reload_temp

    ; Post-Death cadence acceleration (T >= 345s / 5:45)
    lda g_game_time_total_sec + 1
    cmp #>345
    bne ++
    lda g_game_time_total_sec + 0
    cmp #<345
++  bcc @rearm_done
    lda s_reload_temp
    sec
    sbc #6
    cmp #28
    bcs +++
    lda #28
+++ sta s_reload_temp

@rearm_done:
    pla
    tax
    lda s_reload_temp
    sta g_enemy_reload_timer, x

    ; Fire aimed ballistic bullet
    jsr enemies_fire_aimed_bullet

@next_enemy_upd:
    inx
    cpx #MAX_ENEMIES
    beq +
    jmp @enemy_loop
+

    ; 4. Move & Update All 4 Free-Flying Bullets
    ldx #0
@bullet_loop:
    lda g_bullet_active, x
    bne @bullet_active
    jmp @next_bullet

@bullet_active:
    ; Cycle energy color one per frame (with per-slot offset for shimmering effect)
    txa
    clc
    adc g_energy_cycle_idx
    and #$07
    tay
    lda g_energy_colors, y
    sta g_bullet_color, x

    ; Move X leftward
    lda g_bullet_x_lo, x
    sec
    sbc g_bullet_vel_x, x
    sta g_bullet_x_lo, x
    bcs +
    dec g_bullet_x_hi, x
+
    ; Despawn check: X < 16 or negative underflow
    lda g_bullet_x_hi, x
    bmi @despawn_b
    bne @bullet_move_y
    lda g_bullet_x_lo, x
    cmp #16
    bcs @bullet_move_y
    lda #0
    sta g_bullet_active, x
    jmp @next_bullet

@bullet_move_y:
    ; Move Y vertically (signed velocity)
    lda g_bullet_y, x
    clc
    adc g_bullet_vel_y, x
    sta g_bullet_y, x

    ; Despawn check: Y < 48 or Y > 246
    cmp #48
    bcc @despawn_b
    cmp #247
    bcc @next_bullet
@despawn_b:
    lda #0
    sta g_bullet_active, x

@next_bullet:
    inx
    cpx #MAX_ENEMY_BULLETS
    bne @bullet_loop
    rts

; ==============================================================================
; Subroutine: enemies_fire_aimed_bullet
; Purpose: Spawns an aimed bullet from enemy slot X directed at player position.
; ==============================================================================
enemies_fire_aimed_bullet:
    stx s_enemy_slot_temp

    ; Find free bullet slot (0..3)
    ldy #0
-   lda g_bullet_active, y
    beq @bullet_slot_found
    iny
    cpy #MAX_ENEMY_BULLETS
    bne -
    ldx s_enemy_slot_temp
    rts                         ; All 4 slots busy

@bullet_slot_found:
    lda #1
    sta g_bullet_active, y

    ; Spawn position: nose of enemy ship
    lda g_enemy_x_lo, x
    sec
    sbc #6
    sta g_bullet_x_lo, y
    lda g_enemy_x_hi, x
    sbc #0
    sta g_bullet_x_hi, y

    lda g_enemy_y, x
    clc
    adc #8                      ; Centered vertically on 21px sprite
    sta g_bullet_y, y

    ; Speed & Type from archetype tables
    sty s_shot_slot_temp
    ldy g_enemy_archetype, x
    lda enemy_table_shot_type, y
    tax                         ; X = shot type
    lda enemy_table_shot_speed, y ; A = shot speed
    ldy s_shot_slot_temp        ; Y = bullet slot
    sta g_bullet_vel_x, y
    txa
    sta g_bullet_type, y

    ; Cycling energy color
    ldx g_energy_cycle_idx
    lda g_energy_colors, x
    sta g_bullet_color, y

    ; Calculate Aimed Vel Y:
    lda g_player_y
    sec
    sbc g_bullet_y, y
    bpl @player_below

    ; Player is ABOVE: A is negative
    eor #$ff
    clc
    adc #1                      ; Distance (bullet_y - player_y)
    cmp #35
    bcs @aim_steep_up
    cmp #10
    bcs @aim_shallow_up
    lda #0                      ; Straight
    jmp @store_vel_y
@aim_shallow_up:
    lda #$ff                    ; -1 px/frame
    jmp @store_vel_y
@aim_steep_up:
    lda #$fe                    ; -2 px/frame
    jmp @store_vel_y

@player_below:
    cmp #35
    bcs @aim_steep_down
    cmp #10
    bcs @aim_shallow_down
    lda #0                      ; Straight
    jmp @store_vel_y
@aim_shallow_down:
    lda #1                      ; +1 px/frame
    jmp @store_vel_y
@aim_steep_down:
    lda #2                      ; +2 px/frame

@store_vel_y:
    sta g_bullet_vel_y, y

    ; Trigger enemy shot sound effect
    lda #SFX_ENEMY_SHOT
    jsr sound_play_sfx

    ldx s_enemy_slot_temp
    rts

; ==============================================================================
; Subroutine: enemies_render
; Purpose: Exports active entities to virtual sprites, sorts them by Y,
;          loads the first batch into Hardware Sprites 2..7, and primes IRQs.
; Called every frame during VBLANK before scanline 50.
; ==============================================================================
enemies_render:
    jsr multiplexer_export
    jsr multiplexer_sort
    jsr multiplexer_prime
    rts

; ==============================================================================
; Subroutine: multiplexer_export
; Purpose: Packages active enemies (0..11) and bullets (0..3) into v_spr_* (0..15).
; ==============================================================================
multiplexer_export:
    ; 1. Export 12 Enemy Ships (Virtual 0..11)
    ldx #0
@export_enemies:
    lda g_enemy_active, x
    sta v_spr_active, x
    beq @next_enemy_exp

    lda g_enemy_x_lo, x
    sta v_spr_x_lo, x
    lda g_enemy_x_hi, x
    sta v_spr_x_hi, x
    lda g_enemy_y, x
    sta v_spr_y, x
    lda g_enemy_type, x
    sta v_spr_ptr, x
    lda g_enemy_color, x
    sta v_spr_color, x
    lda #1                      ; 1 = Multicolor (normal enemy ships)
    ldy g_enemy_exploding, x
    beq +
    lda #0                      ; 0 = Hi-res Monochrome (explosion)
+   sta v_spr_mc, x

@next_enemy_exp:
    inx
    cpx #MAX_ENEMIES
    bne @export_enemies

    ; 2. Export 4 Enemy Bullets (Virtual 12..15)
    ldx #0
@export_bullets:
    txa
    clc
    adc #MAX_ENEMIES            ; Virtual index 12..15
    tay

    lda g_bullet_active, x
    sta v_spr_active, y
    beq @next_bullet_exp

    lda g_bullet_x_lo, x
    sta v_spr_x_lo, y
    lda g_bullet_x_hi, x
    sta v_spr_x_hi, y
    lda g_bullet_y, x
    sta v_spr_y, y
    lda g_bullet_type, x
    sta v_spr_ptr, y
    lda g_bullet_color, x
    sta v_spr_color, y
    lda #0                      ; Hi-res monochrome
    sta v_spr_mc, y

@next_bullet_exp:
    inx
    cpx #MAX_ENEMY_BULLETS
    bne @export_bullets
    rts

; ==============================================================================
; Subroutine: multiplexer_sort
; Purpose: Filters active virtual sprites into g_sort_order and insertion-sorts
;          them ascending by Y coordinate.
; ==============================================================================
multiplexer_sort:
    ; Filter active sprites into g_sort_order
    lda #0
    sta g_sort_count
    ldx #0
@filter_active:
    lda v_spr_active, x
    beq +
    ldy g_sort_count
    txa
    sta g_sort_order, y
    inc g_sort_count
+   inx
    cpx #MAX_VIRTUAL_SPRITES
    bne @filter_active

    ; Insertion sort if g_sort_count >= 2
    lda g_sort_count
    cmp #2
    bcc @sort_done

    ldx #1
@sort_outer:
    stx s_sort_i
    lda g_sort_order, x
    sta s_sort_key_idx
    tay
    lda v_spr_y, y
    sta s_sort_key_y

    stx s_sort_j
@sort_inner:
    ldx s_sort_j
    beq @insert_key
    dex
    lda g_sort_order, x
    tay
    lda v_spr_y, y
    cmp s_sort_key_y
    bcc @insert_key
    beq @insert_key

    ; Shift right
    lda g_sort_order, x
    ldx s_sort_j
    sta g_sort_order, x
    dec s_sort_j
    jmp @sort_inner

@insert_key:
    ldx s_sort_j
    lda s_sort_key_idx
    sta g_sort_order, x

    inc s_sort_i
    ldx s_sort_i
    cpx g_sort_count
    bcc @sort_outer

@sort_done:
    rts

; ==============================================================================
; Subroutine: multiplexer_prime
; Purpose: Loads first batch (up to 6) into Hardware Sprites 2..7 and primes IRQ.
; ==============================================================================
multiplexer_prime:
    lda g_sort_count
    bne @have_sprites

    ; No active sprites: disable physical Sprites 2..7
    lda VIC_SPR_ENABLE
    and #$03                    ; Preserve Sprites 0 & 1
    sta VIC_SPR_ENABLE
    lda #0
    sta g_multiplexer_active
    sta VIC_RASTER
    rts

@have_sprites:
    lda g_sort_count
    cmp #6
    bcc +
    lda #6
+   sta s_batch_size

    ; Initialize composite masks (preserving Sprites 0 & 1)
    lda VIC_SPR_MSB
    and #$03
    sta s_msb_mask
    lda VIC_SPR_ENABLE
    and #$03
    sta s_enable_mask
    lda VIC_SPR_MULTICOLOR
    and #$03
    sta s_mc_mask

    ; Load first batch into physical slots 0..batch_size-1
    ldx #0
@load_batch_loop:
    cpx s_batch_size
    beq @disable_remaining

    lda g_sort_order, x
    tay
    sty s_virt_temp

    ; Write X lo
    lda s_phys_x_reg, x
    sta s_reg_temp
    ldy s_virt_temp
    lda v_spr_x_lo, y
    ldy s_reg_temp
    sta $d000, y

    ; Write Y
    lda s_phys_y_reg, x
    sta s_reg_temp
    ldy s_virt_temp
    lda v_spr_y, y
    ldy s_reg_temp
    sta $d000, y

    ; Write Pointer
    lda s_phys_ptr_offset, x
    sta s_reg_temp
    ldy s_virt_temp
    lda v_spr_ptr, y
    ldy s_reg_temp
    sta $0700, y

    ; Write Color
    lda s_phys_col_reg, x
    sta s_reg_temp
    ldy s_virt_temp
    lda v_spr_color, y
    ldy s_reg_temp
    sta $d000, y

    ; Update Enable mask
    lda s_phys_mask, x
    ora s_enable_mask
    sta s_enable_mask

    ; Update MSB mask
    ldy s_virt_temp
    lda v_spr_x_hi, y
    beq +
    lda s_phys_mask, x
    ora s_msb_mask
    sta s_msb_mask
+
    ; Update Multicolor mask
    ldy s_virt_temp
    lda v_spr_mc, y
    beq +
    lda s_phys_mask, x
    ora s_mc_mask
    sta s_mc_mask
+
    inx
    jmp @load_batch_loop

@disable_remaining:
    cpx #6
    beq @write_masks
    lda s_phys_y_reg, x
    tay
    lda #0
    sta $d000, y
    inx
    jmp @disable_remaining

@write_masks:
    lda s_msb_mask
    sta VIC_SPR_MSB
    lda s_mc_mask
    sta VIC_SPR_MULTICOLOR
    lda s_enable_mask
    sta VIC_SPR_ENABLE

    ; Check if mid-frame multiplexing is required (> 6 active sprites)
    lda g_sort_count
    cmp #7
    bcc @no_multiplex

    lda #1
    sta g_multiplexer_active
    lda #0
    sta g_irq_curr_virt         ; Virtual 0 finishes first
    sta g_irq_phys_slot         ; Physical slot 0 (Sprite 2) will be reloaded
    lda #6
    sta g_irq_next_virt         ; Virtual 6 waiting to load

    ; Trigger line = v_spr_y[g_sort_order[0]] + 21
    ldy g_sort_order + 0
    lda v_spr_y, y
    clc
    adc #21
    sta VIC_RASTER
    rts

@no_multiplex:
    lda #0
    sta g_multiplexer_active
    sta VIC_RASTER
    rts

; ==============================================================================
; Subroutine: multiplexer_irq_step
; Purpose: Reloads physical slot (g_irq_phys_slot) with virtual sprite
;          V = g_sort_order[g_irq_next_virt] and schedules the next IRQ trigger.
; Called from raster_irq in main.asm.
; ==============================================================================
multiplexer_irq_step:
    lda g_multiplexer_active
    bne +
    rts
+
    ldx g_irq_phys_slot         ; Physical slot 0..5 (Sprites 2..7)
    ldy g_irq_next_virt         ; Next virtual sprite index in sort list
    lda g_sort_order, y
    tay
    sty s_virt_temp

    ; Write X lo
    lda s_phys_x_reg, x
    sta s_reg_temp
    ldy s_virt_temp
    lda v_spr_x_lo, y
    ldy s_reg_temp
    sta $d000, y

    ; Write Y
    lda s_phys_y_reg, x
    sta s_reg_temp
    ldy s_virt_temp
    lda v_spr_y, y
    ldy s_reg_temp
    sta $d000, y

    ; Write Pointer
    lda s_phys_ptr_offset, x
    sta s_reg_temp
    ldy s_virt_temp
    lda v_spr_ptr, y
    ldy s_reg_temp
    sta $0700, y

    ; Write Color
    lda s_phys_col_reg, x
    sta s_reg_temp
    ldy s_virt_temp
    lda v_spr_color, y
    ldy s_reg_temp
    sta $d000, y

    ; Update MSB bit for this physical slot
    lda s_phys_mask, x
    eor #$ff
    and VIC_SPR_MSB
    sta s_mask_temp
    ldy s_virt_temp
    lda v_spr_x_hi, y
    beq +
    lda s_mask_temp
    ora s_phys_mask, x
    sta s_mask_temp
+   lda s_mask_temp
    sta VIC_SPR_MSB

    ; Update Multicolor bit for this physical slot
    lda s_phys_mask, x
    eor #$ff
    and VIC_SPR_MULTICOLOR
    sta s_mask_temp
    ldy s_virt_temp
    lda v_spr_mc, y
    beq +
    lda s_mask_temp
    ora s_phys_mask, x
    sta s_mask_temp
+   lda s_mask_temp
    sta VIC_SPR_MULTICOLOR

    ; Ensure this physical slot remains enabled
    lda VIC_SPR_ENABLE
    ora s_phys_mask, x
    sta VIC_SPR_ENABLE

    ; Advance indices
    inc g_irq_next_virt
    inc g_irq_curr_virt

    inc g_irq_phys_slot
    lda g_irq_phys_slot
    cmp #6
    bcc +
    lda #0
    sta g_irq_phys_slot
+
    ; Check if more virtual sprites remain in this frame
    lda g_irq_next_virt
    cmp g_sort_count
    bcs @multiplex_done

    ; Next trigger line is bottom of virtual sprite g_irq_curr_virt
    ldy g_irq_curr_virt
    lda g_sort_order, y
    tay
    lda v_spr_y, y
    clc
    adc #21
    cmp VIC_RASTER
    bcc @clamp_raster
    beq @clamp_raster
    sta VIC_RASTER
    rts

@clamp_raster:
    lda VIC_RASTER
    clc
    adc #2
    sta VIC_RASTER
    rts

@multiplex_done:
    lda #0
    sta g_multiplexer_active
    sta VIC_RASTER
    rts
