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
    !byte COLOR_CYAN, COLOR_ORANGE, COLOR_LIGHT_BLUE, COLOR_LIGHT_GREEN
    !byte COLOR_GREEN, COLOR_PURPLE
    !byte COLOR_CYAN, COLOR_ORANGE
g_enemy_pattern:    !fill MAX_ENEMIES, 0
g_enemy_phase:      !fill MAX_ENEMIES, 0
g_enemy_roam_timer: !fill MAX_ENEMIES, 0 ; 0 = Entering screen, >0 = Countdown to roam decision
g_enemy_speed:      !fill MAX_ENEMIES, 0
g_enemy_hp:         !fill MAX_ENEMIES, 0
g_enemy_archetype:  !fill MAX_ENEMIES, 0
g_enemy_dir_x:      !fill MAX_ENEMIES, 0 ; 0 = Moving Left, 1 = Moving Right
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

; ------------------------------------------------------------------------------
; Enemy Archetype Data Tables (8 Archetypes: Index 0 to 7)
; ------------------------------------------------------------------------------
PATTERN_MODE_SINE_MIX   = 0     ; Sometimes straight, sometimes sine (Enemies 1..5)
PATTERN_MODE_HUNT_MIX   = 1     ; Sometimes sine, sometimes tracking (Enemy 6)
PATTERN_MODE_HUNT_ONLY  = 2     ; Dynamic unpredictable vertical tracking (Enemies 7..8)

enemy_table_sprite:
    !byte SPRITE_PTR_ENEMY_1    ; 131: Enemy 1 (Scout)
    !byte SPRITE_PTR_ENEMY_2    ; 132: Enemy 2 (Light Fighter)
    !byte SPRITE_PTR_ENEMY_3    ; 133: Enemy 3 (Interceptor)
    !byte SPRITE_PTR_ENEMY_4    ; 134: Enemy 4 (Scorpion)
    !byte SPRITE_PTR_ENEMY_5    ; 135: Enemy 5 (Batplane)
    !byte SPRITE_PTR_ENEMY_6    ; 136: Enemy 6 (Spider)
    !byte SPRITE_PTR_ENEMY_7    ; 137: Enemy 7 (The Eye)
    !byte SPRITE_PTR_ENEMY_8    ; 138: Enemy 8 (Death)

enemy_table_hp:
    !byte 1, 1, 1, 2, 2, 3, 3, 3

enemy_table_pattern_mode:
    !byte PATTERN_MODE_SINE_MIX     ; Enemy 1: straight or sine wave
    !byte PATTERN_MODE_SINE_MIX     ; Enemy 2: straight or sine wave
    !byte PATTERN_MODE_SINE_MIX     ; Enemy 3: straight or sine wave
    !byte PATTERN_MODE_SINE_MIX     ; Enemy 4: straight or sine wave
    !byte PATTERN_MODE_SINE_MIX     ; Enemy 5: straight or sine wave
    !byte PATTERN_MODE_HUNT_MIX     ; Enemy 6: sine wave or unpredictable tracking
    !byte PATTERN_MODE_HUNT_ONLY    ; Enemy 7: unpredictable vertical tracking
    !byte PATTERN_MODE_HUNT_ONLY    ; Enemy 8: unpredictable vertical tracking

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

; Unlock thresholds in total elapsed seconds (16-bit)
enemy_table_unlock_sec_lo:
    !byte <0, <15, <35, <60, <95, <140, <195, <260

enemy_table_unlock_sec_hi:
    !byte >0, >15, >35, >60, >95, >140, >195, >260

; ------------------------------------------------------------------------------
; 32-Entry Weighted Tier Spawn Tables (8 Tiers x 32 bytes = 256 bytes total)
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
    !byte 0, 0, 1, 1, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4
    !byte 4, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 7, 7, 7

; ------------------------------------------------------------------------------
; 32-Entry Signed Sine Wave Lookup Table (Amplitude ±25 pixels, 1 full cycle)
; ------------------------------------------------------------------------------
g_enemy_sine_table:
    !byte   0,   5,  10,  14,  18,  22,  24,  25
    !byte  25,  25,  24,  22,  18,  14,  10,   5
    !byte   0,  -5, -10, -14, -18, -22, -24, -25
    !byte -25, -25, -24, -22, -18, -14, -10,  -5

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
    lda #35
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
    lda g_game_time_total_sec + 1
    bne @density_high           ; T >= 256s

    lda g_game_time_total_sec + 0
    cmp #10
    bcs @after_first_10s

    ; First 10 seconds: max 2 active enemies at once
    ldy #2
    jmp @check_density_limit

@after_first_10s:
    ldy #5                      ; 10s..29s: max 5
    cmp #30
    bcc @check_density_limit
    ldy #8                      ; 30s..59s: max 8
    cmp #60
    bcc @check_density_limit
    ldy #10                     ; 60s..119s: max 10
    cmp #120
    bcc @check_density_limit
    ldy #MAX_ENEMIES            ; 120s+: max 12
    jmp @check_density_limit

@density_high:
    ldy #MAX_ENEMIES            ; T >= 256s: max 12

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

    ; Spawn X off-screen right: X = 344 (X_lo = 88, X_hi = 1)
    lda #88
    sta g_enemy_x_lo, y
    lda #1
    sta g_enemy_x_hi, y

    ; Spawn Y: random full-screen altitude (52..220)
    jsr starfield_rand
    and #$7f                    ; 0..127
    clc
    adc #52
    sta s_spawn_y_temp
    jsr starfield_rand
    and #$1f                    ; 0..31
    clc
    adc s_spawn_y_temp
    cmp #222
    bcc +
    lda #220
+   sta g_enemy_y, y
    sta g_enemy_base_y, y

    ; Direction setup
    lda #0
    sta g_enemy_dir_x, y        ; Move left
    sta g_enemy_exploding, y
    sta g_enemy_flash, y

    lda #0
    sta g_enemy_roam_timer, y   ; 0 = Entering screen state

    ; Select archetype (via one-shot debug spawn or progression timeline)
    lda g_first_spawn_force
    beq @use_timeline
    sec
    sbc #1                      ; 1..8 -> 0..7
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
    lda tier_offsets, x
    sta s_tier_offset_temp
    jsr starfield_rand
    and #$1f
    clc
    adc s_tier_offset_temp
    tax
    lda tier_spawn_table, x     ; A = selected archetype (0..7)

    ; Enemy 8 Presence Guard: ensure at most 1 Enemy 8 active on screen
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
    lda #7
    jmp @setup_archetype

@downgrade_e8:
    lda #6                      ; Downgrade to Battleship (Enemy 7)

@setup_archetype:
    sta g_enemy_archetype, y
    tax                         ; X = archetype index (0..7)

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
    cpx #0
    bne +
    jsr starfield_rand
    and #$01
    clc
    adc #1
    sta g_enemy_speed, y
+
    ; Movement pattern setup
    lda enemy_table_pattern_mode, x
    cmp #PATTERN_MODE_HUNT_ONLY
    beq @set_pat_tracking
    cmp #PATTERN_MODE_HUNT_MIX
    beq @set_pat_hunt_mix

    ; PATTERN_MODE_SINE_MIX (Enemies 1..5): 50% straight, 50% wide sine
    jsr starfield_rand
    and #$01
    beq @set_pat_straight
    jmp @set_pat_sine

@set_pat_hunt_mix:
    ; Enemy 6: 50% wide sine, 50% unpredictable tracking
    jsr starfield_rand
    and #$01
    beq @set_pat_sine
    jmp @set_pat_tracking

@set_pat_straight:
    lda #PATTERN_STRAIGHT
    beq +

@set_pat_tracking:
    lda #PATTERN_TRACKING
    bne +

@set_pat_sine:
    jsr starfield_rand
    and #$1f
    sta g_enemy_phase, y
    lda #PATTERN_SINE
+   sta g_enemy_pattern, y
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

    ; Reset timer based on elapsed time and current density:
    lda g_game_time_total_sec + 1
    bne @normal_density_check   ; T >= 256s

    lda g_game_time_total_sec + 0
    cmp #10
    bcs @normal_density_check

    ; First 10 seconds: gentle intro (40..55 frames = 0.8..1.1s per enemy)
    jsr starfield_rand
    and #$0f
    clc
    adc #40
    sta g_wave_spawn_timer
    jmp @update_entities

@normal_density_check:
    lda s_active_count
    cmp #3
    bcs @normal_density_timer

    ; Low density (<3 enemies) after 10s: replenish in 12..19 frames (~0.24..0.38s)
    jsr starfield_rand
    and #$07
    clc
    adc #12
    sta g_wave_spawn_timer
    jmp @update_entities

@normal_density_timer:
    lda g_game_time_total_sec + 1
    bne @very_fast_spawn        ; T >= 256s
    lda g_game_time_total_sec + 0
    cmp #60
    bcs @fast_spawn             ; T >= 60s (1 min)

    ; Early game cadence (10s <= T < 60s): 20..35 frames (~0.40..0.70s)
    jsr starfield_rand
    and #$0f
    clc
    adc #20
    sta g_wave_spawn_timer
    jmp @update_entities

@fast_spawn:
    ; Mid game cadence (60s <= T < 256s): 14..25 frames (~0.28..0.50s)
    jsr starfield_rand
    and #$0b
    clc
    adc #14
    sta g_wave_spawn_timer
    jmp @update_entities

@very_fast_spawn:
    ; Late game cadence (T >= 256s): 10..17 frames (~0.20..0.34s)
    jsr starfield_rand
    and #$07
    clc
    adc #10
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

+   ; Spider (Archetype 5) always has main color = Light Gray ($0F)
    lda #COLOR_LIGHT_GRAY
    ldy g_enemy_archetype, x
    cpy #5
    beq @store_color

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
    ; --------------------------------------------------------------------------
    ; Horizontal Motion & Free-Roaming AI
    ; Phase 1: Enter screen from right roughly one third in (X <= 235)
    ; Phase 2: Free roaming across playfield (75 <= X <= 280) with unpredictable
    ;          direction reversals and dynamic pattern switching.
    ; --------------------------------------------------------------------------
    lda g_enemy_roam_timer, x
    beq @do_move_left

    ; === Phase 2: Free Roaming ===
    dec g_enemy_roam_timer, x
    bne @check_dir

    ; Roam decision timer fired: make unpredictable AI adjustments
    jsr starfield_rand
    and #$1f
    clc
    adc #25
    sta g_enemy_roam_timer, x

    ; 1. Randomly choose horizontal direction (50% left, 50% right)
    jsr starfield_rand
    and #$01
    sta g_enemy_dir_x, x

    ; 2. Dynamically switch vertical pattern ("can be a sine but not all the time")
    ldy g_enemy_archetype, x
    cpy #5
    bcs @roam_pat_high

    ; Enemies 1..5: 50% wide sine, 50% straight cruise
    jsr starfield_rand
    and #$01
    sta g_enemy_pattern, x
    jmp @roam_drift_y

@roam_pat_high:
    ; Enemies 6, 7, 8: 65% altitude tracking, 35% wide sine
    jsr starfield_rand
    and #$07
    cmp #3
    bcc +
    lda #PATTERN_TRACKING
    bne ++
+   lda #PATTERN_SINE
++  sta g_enemy_pattern, x

@roam_drift_y:
    ; Organically nudge baseline altitude by +-3 pixels
    jsr starfield_rand
    and #$07                    ; 0..7
    sec
    sbc #3                      ; -3..+4
    clc
    adc g_enemy_base_y, x
    cmp #60
    bcc +
    cmp #216
    bcs +
    sta g_enemy_base_y, x
+

@check_dir:
    lda g_enemy_dir_x, x
    bne @roam_right

@do_move_left:
    ; Moving Left at current speed (Phase 1 entry or Phase 2 roam left)
    lda g_enemy_x_lo, x
    sec
    sbc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcs +
    dec g_enemy_x_hi, x
+
    lda g_enemy_x_hi, x
    bne @apply_vert             ; If X >= 256, done with boundary checks

    lda g_enemy_roam_timer, x
    bne @check_roam_left_boundary

    ; Phase 1 check: reached 1/3 screen (X <= 235)?
    lda g_enemy_x_lo, x
    cmp #235
    bcs @apply_vert
    ; Reached 1/3 into screen: Transition to Free Roaming!
    jsr starfield_rand
    and #$1f
    clc
    adc #25
    sta g_enemy_roam_timer, x
    jmp @apply_vert

@check_roam_left_boundary:
    lda g_enemy_x_lo, x
    cmp #75
    bcs @apply_vert
    ; Reached left roam boundary: turn right!
    lda #75
    sta g_enemy_x_lo, x
    lda #1
    sta g_enemy_dir_x, x
    jmp @apply_vert

@roam_right:
    ; Roam Moving Right at current speed
    lda g_enemy_x_lo, x
    clc
    adc g_enemy_speed, x
    sta g_enemy_x_lo, x
    bcc +
    inc g_enemy_x_hi, x
+
    ; Right roam limit check (X >= 280)
    lda g_enemy_x_hi, x
    beq @apply_vert             ; If X_hi == 0, X <= 255 < 280
    lda g_enemy_x_lo, x
    cmp #24                     ; 256 + 24 = 280
    bcc @apply_vert
    ; Reached right roam boundary: turn left!
    lda #24
    sta g_enemy_x_lo, x
    lda #0
    sta g_enemy_dir_x, x

@apply_vert:
    lda g_enemy_pattern, x
    beq @check_shooting         ; 0 = Straight horizontal flight
    cmp #PATTERN_SINE
    beq @apply_sine             ; 1 = Wide sinusoidal wave oscillation

    ; 2 = PATTERN_TRACKING: Unpredictable dynamic vertical tracking (Enemies 6, 7, 8)
    jsr starfield_rand
    and #$03                    ; Add natural jitter (75% movement rate)
    beq @check_shooting

    lda g_enemy_y, x
    cmp g_player_y
    beq @check_shooting
    bcc @track_down

    ; Enemy is below player: drift upwards
    sec
    sbc #1
    bne @clamp_y

@track_down:
    ; Enemy is above player: drift downwards
    clc
    adc #1
    bne @clamp_y

@apply_sine:
    ; Wide Sine wave: Y = base_y + sine[phase] clamped to 52..226
    inc g_enemy_phase, x
    lda g_enemy_phase, x
    and #$1f
    sta g_enemy_phase, x
    tay
    lda g_enemy_sine_table, y
    clc
    adc g_enemy_base_y, x

@clamp_y:
    cmp #52
    bcs +
    lda #52
+   cmp #227
    bcc +
    lda #226
+   sta g_enemy_y, x

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

    ; Post-Enemy 8 cadence acceleration (T >= 360s)
    lda g_game_time_total_sec + 1
    cmp #>360
    bne ++
    lda g_game_time_total_sec + 0
    cmp #<360
++  bcc @rearm_done
    lda s_reload_temp
    sec
    sbc #12
    cmp #15
    bcs +++
    lda #15
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
    ; Despawn check: X < 16
    lda g_bullet_x_hi, x
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
    ; Find free bullet slot (0..3)
    ldy #0
-   lda g_bullet_active, y
    beq @bullet_slot_found
    iny
    cpy #MAX_ENEMY_BULLETS
    bne -
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
