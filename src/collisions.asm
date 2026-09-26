; ==============================================================================
; COLLISIONS.ASM - Collision Detection Subsystem (Phase 6)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
;
; Manages:
; - Player missile vs Enemy ship bounding box sweep collision (50 px/frame sweep)
; - Multi-hit HP damage and white damage flash feedback
; - 3-frame multicolor explosion sequencing on destruction
; - Enemy slot recycling
; ==============================================================================

s_coll_diff_lo:     !byte 0
s_coll_diff_hi:     !byte 0

; ==============================================================================
; Subroutine: collisions_init
; Purpose: Resets collision subsystem state variables.
; ==============================================================================
collisions_init:
    lda #0
    sta s_coll_diff_lo
    sta s_coll_diff_hi
    rts

; ==============================================================================
; Subroutine: collisions_check
; Purpose: Tests active player missile against all 9 enemy slots using continuous
;          horizontal swept-box intersection to prevent high-speed tunneling.
; Called every frame in main game loop directly after enemies_update.
; ==============================================================================
collisions_check:
    ; Quick exit if no player missile is currently in flight
    lda g_missile_active
    cmp #1                      ; 1 = Missile in flight
    beq +
    rts
+
    ldx #0
@check_enemy_loop:
    ; 1. Check if enemy slot is active and not already exploding
    lda g_enemy_active, x
    beq @skip_enemy
    lda g_enemy_exploding, x
    bne @skip_enemy
    jmp @enemy_is_valid

@skip_enemy:
    jmp @next_enemy

@enemy_is_valid:
    ; 2. Vertical Range Check across all 5 shot types:
    ; diff_y = missile_y + shot_h_add[phase] - enemy_y
    ; Overlap if 0 <= diff_y < shot_v_threshold[phase]
    ldy g_player_phase
    dey                         ; 1..5 -> 0..4
    lda g_missile_y
    clc
    adc shot_h_add_table, y
    sec
    sbc g_enemy_y, x
    bcc @skip_enemy             ; diff_y < 0 (missile above enemy)
    cmp shot_v_threshold_table, y
    bcs @skip_enemy             ; diff_y >= threshold (missile below enemy)

    ; 3. Horizontal Swept Check (50 px/frame sweep + shot_w vs 24 px wide enemy):
    ; diff_x = missile_x - enemy_x + shot_w[phase]
    ; Overlap if 0 <= diff_x < shot_h_thresh[phase]
    lda g_missile_x + 0
    sec
    sbc g_enemy_x_lo, x
    sta s_coll_diff_lo
    lda g_missile_x + 1
    sbc g_enemy_x_hi, x
    sta s_coll_diff_hi

    ; Add shot_w
    lda s_coll_diff_lo
    clc
    adc shot_w_table, y
    sta s_coll_diff_lo
    lda s_coll_diff_hi
    adc #0
    bne @skip_enemy             ; Out of horizontal range (diff < 0 or diff >= 256)

    lda s_coll_diff_lo
    cmp shot_h_thresh_table, y
    bcs @skip_enemy

    ; --------------------------------------------------------------------------
    ; Direct Hit Confirmed!
    ; --------------------------------------------------------------------------
    ; Decrement enemy HP
    dec g_enemy_hp, x
    beq @enemy_destroyed

    ; Enemy damaged but alive (HP > 0): Trigger white flash for 3 frames
    lda #3
    sta g_enemy_flash, x
    lda #COLOR_WHITE
    sta g_enemy_color, x

    ; Trigger hit spark on Sprite 1 (4 frames)
    lda #4
    sta g_missile_active

    ; Position spark in front of enemy nose (enemy faces left at g_enemy_x)
    lda g_enemy_x_lo, x
    sec
    sbc #8
    sta g_missile_x + 0
    lda g_enemy_x_hi, x
    sbc #0
    sta g_missile_x + 1

    lda g_enemy_y, x
    sta g_missile_y

    ; Pick a random energy color for the hit spark
    jsr starfield_rand
    and #$07
    tay
    lda g_energy_colors, y
    sta g_spark_color
    rts

@enemy_destroyed:
    ; Enemy destroyed (HP == 0): Deactivate missile and trigger 12-frame explosion
    lda #0
    sta g_missile_active
    jsr collisions_kill_enemy
    rts

@next_enemy:
    inx
    cpx #MAX_ENEMIES
    beq @all_enemies_checked
    jmp @check_enemy_loop
@all_enemies_checked:
    rts

; ==============================================================================
; Subroutine: collisions_kill_enemy
; Purpose: Instantly destroys enemy slot X, triggers explosion and awards score.
; ==============================================================================
collisions_kill_enemy:
    lda #12
    sta g_enemy_exploding, x
    lda #SPRITE_PTR_EXPLOSION_1
    sta g_enemy_type, x

    ; Trigger enemy explosion sound effect
    lda #SFX_EXPLOSION_ENEMY
    jsr sound_play_sfx

    ; Award score points based on enemy archetype (0..7)
    ldy g_enemy_archetype, x
    lda enemy_score_table, y
    jmp hud_add_score

; ==============================================================================
; Subroutine: collisions_check_player
; Purpose: Tests active enemy ships and enemy bullets against player ship bounding
;          box. Applies phase demotion, HP loss, and invulnerability blinking.
; ==============================================================================
collisions_check_player:
    ; Exit if player is already destroyed
    lda g_player_alive
    bne +
    rts
+
    ; Exit if player is currently invulnerable
    lda g_player_invuln_timer
    beq +
    rts
+
    ; --------------------------------------------------------------------------
    ; 1. Check Player vs Active Enemy Ships (MAX_ENEMIES = 12)
    ; --------------------------------------------------------------------------
    ldx #0
@check_enemy_loop:
    lda g_enemy_active, x
    beq @next_enemy_ship
    lda g_enemy_exploding, x
    bne @next_enemy_ship

    ; Vertical range check:
    ; diff_y = enemy_y + 21 - player_y
    ; Overlap if 0 <= diff_y < (player_h + 21)
    ; Unscaled player: player_h = 21 -> threshold = 42
    ; Scaled player:   player_h = 42 -> threshold = 63
    lda g_enemy_y, x
    clc
    adc #21
    sec
    sbc g_player_y
    bcc @next_enemy_ship
    sta s_coll_diff_lo

    ldy g_player_phase
    dey                         ; 1..5 -> 0..4
    lda player_phase_scaled, y
    bne @scaled_enemy_v

    lda s_coll_diff_lo
    cmp #42
    bcs @next_enemy_ship
    bcc @check_h_enemy

@scaled_enemy_v:
    lda s_coll_diff_lo
    cmp #63
    bcs @next_enemy_ship

@check_h_enemy:
    ; Horizontal range check:
    ; diff_x = enemy_x - player_x
    ; Overlap if 0 <= (diff_x + 24) < (player_w + 24)
    ; Unscaled: player_w = 24 -> threshold = 48
    ; Scaled:   player_w = 48 -> threshold = 72
    lda g_enemy_x_lo, x
    sec
    sbc g_player_x + 0
    sta s_coll_diff_lo
    lda g_enemy_x_hi, x
    sbc g_player_x + 1
    sta s_coll_diff_hi

    lda s_coll_diff_lo
    clc
    adc #24
    sta s_coll_diff_lo
    lda s_coll_diff_hi
    adc #0
    bne @next_enemy_ship        ; Out of horizontal range

    ldy g_player_phase
    dey
    lda player_phase_scaled, y
    bne @scaled_enemy_h

    lda s_coll_diff_lo
    cmp #48
    bcs @next_enemy_ship
    jmp @player_hit_by_ship

@scaled_enemy_h:
    lda s_coll_diff_lo
    cmp #72
    bcs @next_enemy_ship
    jmp @player_hit_by_ship

@next_enemy_ship:
    inx
    cpx #MAX_ENEMIES
    bne @check_enemy_loop

    ; --------------------------------------------------------------------------
    ; 2. Check Player vs Active Enemy Bullets (MAX_ENEMY_BULLETS = 4)
    ; --------------------------------------------------------------------------
    ldx #0
@check_bullet_loop:
    lda g_bullet_active, x
    beq @next_bullet

    ; Vertical range check (bullet height = 8 px):
    ; diff_y = bullet_y + 8 - player_y
    ; Overlap if 0 <= diff_y < (player_h + 8)
    ; Unscaled: player_h = 21 -> threshold = 29
    ; Scaled:   player_h = 42 -> threshold = 50
    lda g_bullet_y, x
    clc
    adc #8
    sec
    sbc g_player_y
    bcc @next_bullet
    sta s_coll_diff_lo

    ldy g_player_phase
    dey
    lda player_phase_scaled, y
    bne @scaled_bullet_v

    lda s_coll_diff_lo
    cmp #29
    bcs @next_bullet
    bcc @check_h_bullet

@scaled_bullet_v:
    lda s_coll_diff_lo
    cmp #50
    bcs @next_bullet

@check_h_bullet:
    ; Horizontal range check (bullet width = 8 px):
    ; diff_x = bullet_x - player_x
    ; Overlap if 0 <= (diff_x + 8) < (player_w + 8)
    ; Unscaled: player_w = 24 -> threshold = 32
    ; Scaled:   player_w = 48 -> threshold = 56
    lda g_bullet_x_lo, x
    sec
    sbc g_player_x + 0
    sta s_coll_diff_lo
    lda g_bullet_x_hi, x
    sbc g_player_x + 1
    sta s_coll_diff_hi

    lda s_coll_diff_lo
    clc
    adc #8
    sta s_coll_diff_lo
    lda s_coll_diff_hi
    adc #0
    bne @next_bullet

    ldy g_player_phase
    dey
    lda player_phase_scaled, y
    bne @scaled_bullet_h

    lda s_coll_diff_lo
    cmp #32
    bcs @next_bullet
    bcc @player_hit_by_bullet

@scaled_bullet_h:
    lda s_coll_diff_lo
    cmp #56
    bcs @next_bullet

@player_hit_by_bullet:
    ; Consume bullet on impact
    lda #0
    sta g_bullet_active, x
    jmp @player_take_hit

@next_bullet:
    inx
    cpx #MAX_ENEMY_BULLETS
    bne @check_bullet_loop
    rts

@player_hit_by_ship:
    ; Instantly kill the enemy ship collided with, regardless of its HP
    jsr collisions_kill_enemy

@player_take_hit:
    ; 1. White border flash for damage feedback
    lda #COLOR_WHITE
    sta VIC_BORDER_COLOR
    lda #6
    sta g_debug_border_timer

    ; 2. 70-frame invulnerability window (1.4 seconds at 50 Hz PAL)
    lda #70
    sta g_player_invuln_timer

    ; 3. Phase demotion & HP damage
    lda g_player_phase
    cmp #1
    beq @take_hp_damage

    ; Drop down one phase (5 -> 4 -> 3 -> 2 -> 1)
    dec g_player_phase
    rts

@take_hp_damage:
    ; When in Phase 1, each hit decrements 1 of 5 HP
    dec g_player_hp
    beq @player_destroyed
    rts

@player_destroyed:
    ; Reached 0 HP: player is dead, ship motion stops, trigger explosion
    lda #0
    sta g_player_alive
    sta g_player_invuln_timer
    lda #24                     ; 24 frames (~0.48 sec) explosion animation
    sta g_player_exploding
    lda #12                     ; Extended 12-frame white border flash on death blow
    sta g_debug_border_timer
    lda #150                    ; 150 frames = 3.0 seconds delay before Game Over
    sta g_game_over_timer

    ; Trigger dramatic player destruction sound effect
    lda #SFX_PLAYER_DEATH
    jsr sound_play_sfx
    rts

; ------------------------------------------------------------------------------
; Player Shot Collision Geometry Tables (Phases 1..5)
; ------------------------------------------------------------------------------
shot_h_add_table:
    !byte  4, 13, 20, 26, 40

shot_v_threshold_table:
    !byte 25, 34, 41, 47, 61

shot_w_table:
    !byte 24, 24, 24, 48, 48

shot_h_thresh_table:
    !byte 98, 98, 98, 122, 122

; ------------------------------------------------------------------------------
; Enemy Point Values Table (Archetypes 1..8, index 0 is dummy)
; Points added to 16-bit score (displayed with two bulk zeroes: * 100)
; ------------------------------------------------------------------------------
enemy_score_table:
    !byte 0, 1, 2, 3, 4, 5, 7, 10, 15  ; Displayed as: 100, 200, 300, 400, 500, 700, 1000, 1500
