; ==============================================================================
; POWERUPS.ASM - Hardware Sprite Bonus Items (B, E, P) & Collision
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
;
; Manages:
; - Hardware multicolor sprite bonus items (B, E, P) moving independently
;   from background starfield at smooth 50 FPS arcade speed:
;   * 'B': Smart Bomb pickup (Sprite Block 209)
;   * 'E': Energy Recovery +1 HP pickup (Sprite Block 210)
;   * 'P': Evolution Phase Level-Up pickup (Sprite Block 211)
; - Rendered via the dynamic Y-sorting virtual sprite multiplexer (Slot 16)
; - Smooth leftward pixel travel (1 px/frame)
; - Accurate sprite-to-sprite AABB collision box testing with player ship
; - Evolution leveling up through 5 ship phases (and full HP heal at max phase)
; ==============================================================================

POWERUP_TYPE_P      = 0         ; Evolution Phase Level-Up ('P')
POWERUP_TYPE_B      = 1         ; Smart Bomb ('B')
POWERUP_TYPE_E      = 2         ; Energy Recovery ('E')
NUM_POWERUP_TYPES   = 3

POWERUP_INITIAL_DELAY   = 150   ; 150 frames = 3.0 seconds at 50 Hz PAL
POWERUP_SPAWN_INTERVAL  = 350   ; 350 frames = 7.0 seconds at 50 Hz PAL
POWERUP_STAGE_DURATION  = 250   ; 250 frames = 5.0 seconds at 50 Hz PAL
BOMB_BOSS_DAMAGE        = 2     ; Smart Bomb deals 2 HP damage to bosses

BONUS_BOUND_MIN_X       = 124   ; Lower boundary of top 2/3 of screen (24..324 range)
BONUS_BOUND_MAX_X_LO    = 49    ; Upper boundary of top 2/3: 256 + 49 = 305
BONUS_BOUND_MAX_X_HI    = 1
BONUS_BOUND_MIN_Y       = 56    ; Left screen boundary
BONUS_BOUND_MAX_Y       = 232   ; Right screen boundary

BONUS_SPAWN_TOP_X_LO    = 88    ; Off-screen top X = 344 (256 + 88)
BONUS_SPAWN_TOP_X_HI    = 1
BONUS_SPAWN_LEFT_Y      = 29    ; Off-screen left Y = 29 (29 + 20 = 49 < 50 border)
BONUS_SPAWN_RIGHT_Y     = 250   ; Off-screen right Y = 250 (at 250 right border)

; Sprite block pointers for P, B, E (from sprites_data.asm)
powerup_sprite_table:
    !byte SPRITE_PTR_BONUS_P    ; 0: P (Phase Level-Up)
    !byte SPRITE_PTR_BONUS_B    ; 1: B (Smart Bomb)
    !byte SPRITE_PTR_BONUS_E    ; 2: E (Energy Recovery)

; ------------------------------------------------------------------------------
; Powerup RAM State Variables
; ------------------------------------------------------------------------------
g_powerup_active:       !byte 0     ; 1 = Active on screen, 0 = Inactive
g_powerup_visible:      !byte 0     ; 1 = Rendered in multiplexer, 0 = Hidden
g_powerup_type:         !byte POWERUP_TYPE_P ; Current powerup type (0=P, 1=B, 2=E)
g_powerup_x_lo:         !byte 0     ; Sprite X low byte
g_powerup_x_hi:         !byte 0     ; Sprite X high byte (MSB)
g_powerup_y:            !byte 0     ; Sprite Y (scanline 50..235)
g_powerup_timer_lo:     !byte 0     ; Countdown timer low byte for natural spawn
g_powerup_timer_hi:     !byte 0     ; Countdown timer high byte for natural spawn
s_powerup_diff_lo:      !byte 0     ; Math scratch for collision testing
s_powerup_diff_hi:      !byte 0     ; Math scratch for collision testing
s_powerup_color_timer:  !byte 20    ; 20 frames = 0.4s at 50 Hz PAL
s_powerup_color_idx:    !byte 0     ; Index in cycle (0..3 for P, 0..2 for B/E)
s_powerup_current_color:!byte COLOR_PURPLE

; Chaotic motion & lifecycle state
s_powerup_vx:           !byte 0     ; Signed velocity in X (-2..+2)
s_powerup_vy:           !byte 0     ; Signed velocity in Y (-2..+2)
s_powerup_impulse_timer:!byte 0     ; Frames until next chaotic vector shift
s_powerup_avx:          !byte 0     ; Actual eased X velocity (signed, 1/16 px/frame)
s_powerup_avy:          !byte 0     ; Actual eased Y velocity (signed, 1/16 px/frame)
s_powerup_fx:           !byte 0     ; X sub-pixel fraction (1/256 px)
s_powerup_fy:           !byte 0     ; Y sub-pixel fraction (1/256 px)
s_powerup_dlo:          !byte 0     ; Velocity delta low (fraction)
s_powerup_dhi:          !byte 0     ; Velocity delta high (whole pixels, signed)
s_powerup_dext:         !byte 0     ; Sign extension ($00/$FF)
s_powerup_life_stage:   !byte 0     ; 0 = Solid (5.0s), 1 = Flashing (5.0s)
s_powerup_life_timer:   !byte 0     ; Countdown timer for current stage (250 frames)

; Color cycle table for B: Red -> Light Red -> Purple
powerup_b_color_cycle:
    !byte COLOR_RED, COLOR_LIGHT_RED, COLOR_PURPLE

; Color cycle table for E: Green -> Light Green -> Cyan
powerup_e_color_cycle:
    !byte COLOR_GREEN, COLOR_LIGHT_GREEN, COLOR_CYAN

; Color cycle table for P: Blue -> Light Blue -> Cyan
powerup_p_color_cycle:
    !byte COLOR_BLUE, COLOR_LIGHT_BLUE, COLOR_CYAN

; Next item transform sequence when shot: B -> E -> P -> B
; Index: 0=P -> B (1), 1=B -> E (2), 2=E -> P (0)
powerup_next_type_table:
    !byte POWERUP_TYPE_B        ; 0 (P) -> 1 (B)
    !byte POWERUP_TYPE_E        ; 1 (B) -> 2 (E)
    !byte POWERUP_TYPE_P        ; 2 (E) -> 0 (P)

; 8-Entry spawn table (50% E, 37.5% P, 12.5% B)
powerup_type_table:
    !byte POWERUP_TYPE_E        ; 0: E (Energy)
    !byte POWERUP_TYPE_P        ; 1: P (Phase Level-Up)
    !byte POWERUP_TYPE_E        ; 2: E (Energy)
    !byte POWERUP_TYPE_B        ; 3: B (Smart Bomb)
    !byte POWERUP_TYPE_E        ; 4: E (Energy)
    !byte POWERUP_TYPE_P        ; 5: P (Phase Level-Up)
    !byte POWERUP_TYPE_E        ; 6: E (Energy)
    !byte POWERUP_TYPE_P        ; 7: P (Phase Level-Up)

; ------------------------------------------------------------------------------
; Chaotic Velocity Tables (32 diverse 2D vector pairs)
; Contains pure X/Y moves, 2:1 and 1:2 non-diagonal angles, and diagonals
; ------------------------------------------------------------------------------
chaotic_vx_table:
    !byte   1,   0,  -1,   0,   2,  -2,   0,   0   ; Pure X and pure Y moves
    !byte   2,   1,   2,  -1,  -2,   1,  -2,  -1   ; 2:1 steep angles
    !byte   1,   2,   1,  -2,  -1,   2,  -1,  -2   ; 1:2 shallow angles
    !byte   1,   1,  -1,   1,   1,  -1,  -1,  -1   ; 1:1 diagonals

chaotic_vy_table:
    !byte   0,   1,   0,  -1,   0,   0,   2,  -2   ; Pure X and pure Y moves
    !byte   1,   2,  -1,  -2,   1,   2,  -1,  -2   ; 2:1 steep angles
    !byte   2,   1,  -2,  -1,   2,   1,  -2,  -1   ; 1:2 shallow angles
    !byte   1,   1,   1,  -1,  -1,   1,  -1,  -1   ; 1:1 diagonals

bounce_perturb_table:
    !byte  -2,  -1,   1,   2

; ==============================================================================
; Subroutine: powerups_init
; Purpose: Resets powerup state and arms initial natural spawn timer.
; ==============================================================================
powerups_init:
    lda #0
    sta g_powerup_active
    sta g_powerup_visible
    sta g_powerup_type
    sta g_powerup_x_lo
    sta g_powerup_x_hi
    sta g_powerup_y
    sta s_powerup_color_idx
    sta s_powerup_life_stage
    sta s_powerup_life_timer
    sta s_powerup_vx
    sta s_powerup_vy
    sta s_powerup_impulse_timer
    lda #20
    sta s_powerup_color_timer
    lda #COLOR_PURPLE
    sta s_powerup_current_color
    lda #<POWERUP_INITIAL_DELAY
    sta g_powerup_timer_lo
    lda #>POWERUP_INITIAL_DELAY
    sta g_powerup_timer_hi
    rts

; ==============================================================================
; Subroutine: powerup_do_spawn
; Purpose: Initializes position in upper half of playfield (X = 230..293, Y = 70..197),
;          assigns initial chaotic velocity, and arms 10.0-second lifecycle timer.
; ==============================================================================
; ==============================================================================
; Subroutine: powerup_calc_delta
; Input:  A = signed velocity (1/16 px/frame)
; Output: s_powerup_dlo = fraction byte (v*16 low), s_powerup_dhi = whole pixels
;         (arithmetic v>>4), s_powerup_dext = sign extension ($00/$FF)
; ==============================================================================
powerup_calc_delta:
    pha
    asl
    asl
    asl
    asl
    sta s_powerup_dlo
    pla
    cmp #$80
    ror
    cmp #$80
    ror
    cmp #$80
    ror
    cmp #$80
    ror
    sta s_powerup_dhi
    ldy #0
    cmp #$80
    bcc +
    ldy #$ff
+   sty s_powerup_dext
    rts

powerup_do_spawn:
    lda #0
    sta s_powerup_fx
    sta s_powerup_fy

    ; Pick spawn edge: 0 = Left side (25%), 1 = Right side (25%), 2..3 = Top (50%)
    jsr starfield_rand
    and #$03
    cmp #2
    bcs @spawn_bonus_top
    cmp #1
    beq @spawn_bonus_right

@spawn_bonus_left:
    ; Off-screen Left (Y = 29), moving rightward into screen
    lda #BONUS_SPAWN_LEFT_Y
    sta g_powerup_y
    lda #2
    sta s_powerup_vy
    lda #12
    sta s_powerup_avy
    jmp @spawn_bonus_side_x

@spawn_bonus_right:
    ; Off-screen Right (Y = 250), moving leftward into screen
    lda #BONUS_SPAWN_RIGHT_Y
    sta g_powerup_y
    lda #$fe                    ; -2
    sta s_powerup_vy
    lda #$f4                    ; -12
    sta s_powerup_avy

@spawn_bonus_side_x:
    ; Pick X well inside top 2/3 roaming zone: 148..275
    jsr starfield_rand
    and #$7f                    ; 0..127
    clc
    adc #148                    ; 148..275
    sta g_powerup_x_lo
    lda #0
    adc #0
    sta g_powerup_x_hi
    ; Gentle vertical drift (-1 or +1)
    lda #0
    sta s_powerup_avx
    jsr starfield_rand
    and #$01
    bne +
    lda #$ff                    ; -1
+   sta s_powerup_vx
    jmp @spawn_bonus_timers

@spawn_bonus_top:
    ; Off-screen Top (X = 344), moving downward into top 2/3 of screen
    lda #BONUS_SPAWN_TOP_X_LO
    sta g_powerup_x_lo
    lda #BONUS_SPAWN_TOP_X_HI
    sta g_powerup_x_hi
    lda #$fe                    ; -2
    sta s_powerup_vx
    lda #$f4                    ; -12
    sta s_powerup_avx
    ; Pick Y well inside horizontal playfield: 80..207
    jsr starfield_rand
    and #$7f                    ; 0..127
    clc
    adc #80                     ; 80..207
    sta g_powerup_y
    ; Gentle horizontal drift (-1 or +1)
    lda #0
    sta s_powerup_avy
    jsr starfield_rand
    and #$01
    bne +
    lda #$ff                    ; -1
+   sta s_powerup_vy

@spawn_bonus_timers:
    ; Initial impulse timer (64..95 frames) so it glides fully into playfield first
    jsr starfield_rand
    and #$1f
    clc
    adc #64
    sta s_powerup_impulse_timer

    ; Initialize 10.0-second lifecycle (Stage 0: 5.0s solid)
    lda #0
    sta s_powerup_life_stage
    lda #POWERUP_STAGE_DURATION ; 250 frames = 5.0s at 50 Hz
    sta s_powerup_life_timer
    lda #1
    sta g_powerup_visible
    sta g_powerup_active

    ; Reset color cycle and apply initial color immediately
    lda #0
    sta s_powerup_color_idx
    lda #20
    sta s_powerup_color_timer
    jsr powerups_apply_color_now
    rts

; ==============================================================================
; Subroutine: powerups_spawn
; Purpose: Attempts natural spawn in upper half. Picks random type.
;          (50% chance E, 37.5% chance P, 12.5% chance B; 75% E if player HP <= 2).
; ==============================================================================
powerups_spawn:
    lda g_powerup_active
    beq +
    rts
+
    ; If player HP is critical (<= 2), give 75% chance of E
    lda g_player_hp
    cmp #3
    bcs @normal_type_pick

    jsr starfield_rand
    and #$03
    beq @normal_type_pick       ; 25% chance of normal table pick
    lda #POWERUP_TYPE_E         ; 75% chance of E emergency heal
    sta g_powerup_type
    jmp powerup_do_spawn

@normal_type_pick:
    ; Pick from 8-entry table (50% E, 37.5% P, 12.5% B)
    jsr starfield_rand
    and #$07
    tax
    lda powerup_type_table, x
    sta g_powerup_type
    jmp powerup_do_spawn

; ==============================================================================
; Subroutine: powerups_spawn_forced
; Purpose: Immediately spawns powerup for debug hotkey, cycling P -> B -> E -> P.
; ==============================================================================
powerups_spawn_forced:
    inc g_powerup_type
    lda g_powerup_type
    cmp #NUM_POWERUP_TYPES
    bcc +
    lda #0
    sta g_powerup_type
+   jsr powerup_do_spawn
    ; Visual border flash feedback
    lda #COLOR_WHITE
    sta VIC_BORDER_COLOR
    lda #8
    sta g_debug_border_timer
    rts

; ==============================================================================
; Subroutine: powerups_spawn_forced_type
; Purpose: Immediately spawns specified powerup type passed in Accumulator.
; ==============================================================================
powerups_spawn_forced_type:
    sta g_powerup_type
    jsr powerup_do_spawn
    ; Visual border flash feedback
    lda #COLOR_WHITE
    sta VIC_BORDER_COLOR
    lda #8
    sta g_debug_border_timer
    rts

powerups_spawn_forced_pos:
    jmp powerup_do_spawn

; ==============================================================================
; Subroutine: powerups_erase
; Purpose: Deactivates current powerup sprite.
; ==============================================================================
powerups_erase:
    lda #0
    sta g_powerup_active
    sta g_powerup_visible
    rts

; ==============================================================================
; Subroutine: powerups_update
; Purpose: Manages chaotic wandering strictly on top 2/3 of screen, 5s solid
;          + 5s flashing lifecycle countdown, color cycling, and spawn timers.
; ==============================================================================
powerups_update:
    ; 1. Check if powerup is active
    lda g_powerup_active
    bne +
    jmp @check_spawn
+

    ; --------------------------------------------------------------------------
    ; 2. Lifecycle Countdown (5.0s Solid + 5.0s Flashing -> Gone)
    ; --------------------------------------------------------------------------
    dec s_powerup_life_timer
    bne @life_running

    ; Stage timer reached 0: transition or expire
    lda s_powerup_life_stage
    bne @powerup_expired       ; If already Stage 1, total 10 seconds elapsed -> expire!

    ; Transition Stage 0 (Solid) -> Stage 1 (Flashing)
    lda #1
    sta s_powerup_life_stage
    lda #POWERUP_STAGE_DURATION ; 250 frames = 5.0 seconds
    sta s_powerup_life_timer
    jmp @life_running

@powerup_expired:
    lda #0
    sta g_powerup_active
    sta g_powerup_visible
    ; Re-arm natural spawn timer so next powerup appears in 7s
    lda #<POWERUP_SPAWN_INTERVAL
    sta g_powerup_timer_lo
    lda #>POWERUP_SPAWN_INTERVAL
    sta g_powerup_timer_hi
    jmp @check_spawn

@life_running:
    ; --------------------------------------------------------------------------
    ; 3. Visibility Determination
    ; --------------------------------------------------------------------------
    lda s_powerup_life_stage
    beq @visible_solid

    ; In Stage 1: Flashing (alternating visible / hidden in succession)
    ; Bit 2 of life timer toggles every 4 frames (80ms ON, 80ms OFF)
    lda s_powerup_life_timer
    and #$04
    beq @visible_hide

@visible_solid:
    lda #1
    sta g_powerup_visible
    jmp @visibility_done

@visible_hide:
    lda #0
    sta g_powerup_visible

@visibility_done:
    ; --------------------------------------------------------------------------
    ; 4. Chaotic Movement Vector Selection (Impulse & Jitter)
    ; --------------------------------------------------------------------------
    dec s_powerup_impulse_timer
    bne @check_jitter

    ; Impulse timer expired: pick new random vector from chaotic table
    jsr starfield_rand
    and #$3f                    ; 0..63
    clc
    adc #40                     ; 40..103 frames (~0.8s to ~2.1s)
    sta s_powerup_impulse_timer

    jsr starfield_rand
    and #$1f                    ; 0..31
    tax
    lda chaotic_vx_table, x
    sta s_powerup_vx
    lda chaotic_vy_table, x
    sta s_powerup_vy
    jmp @apply_motion

@check_jitter:
    ; Skip jitter while still gliding in from off-screen
    lda s_powerup_impulse_timer
    cmp #45
    bcs @apply_motion
    ; Every 8 frames, small chance of brownian drift nudge to curve trajectories
    and #$07
    bne @apply_motion
    jsr starfield_rand
    and #$03
    bne @apply_motion           ; 25% chance
    jsr starfield_rand
    and #$03
    tax
    lda bounce_perturb_table, x ; -2, -1, 1, 2
    clc
    adc s_powerup_vy
    ; Clamp vy to -2..2
    cmp #$fd                    ; < -2 ? ($FE = -2, $FD = -3)
    bcs +
    lda #$fe                    ; clamp to -2
+   cmp #3
    bcc +
    lda #2                      ; clamp to 2
+   sta s_powerup_vy

@apply_motion:
    ; --------------------------------------------------------------------------
    ; 5. Eased steering + sub-pixel motion.
    ; s_powerup_vx/vy (-2..2) are TARGET directions. Actual velocity
    ; (1/16 px/frame units) eases toward target*6 by 1 unit every 4 frames,
    ; so turns are wide, gentle arcs. Max speed = 12/16 = 0.75 px/frame.
    ; --------------------------------------------------------------------------
    lda s_powerup_life_timer
    and #$03
    bne @do_move

    ; --- steer X ---
    lda s_powerup_vx
    asl
    sta s_powerup_diff_lo
    asl
    clc
    adc s_powerup_diff_lo       ; target = vx * 6
    sec
    sbc s_powerup_avx
    beq @steer_y
    bmi @dec_avx
    inc s_powerup_avx
    jmp @steer_y
@dec_avx:
    dec s_powerup_avx

@steer_y:
    lda s_powerup_vy
    asl
    sta s_powerup_diff_lo
    asl
    clc
    adc s_powerup_diff_lo       ; target = vy * 6
    sec
    sbc s_powerup_avy
    beq @do_move
    bmi @dec_avy
    inc s_powerup_avy
    jmp @do_move
@dec_avy:
    dec s_powerup_avy

@do_move:
    ; --- move X (16-bit position + 8-bit fraction) ---
    lda s_powerup_avx
    jsr powerup_calc_delta
    lda s_powerup_fx
    clc
    adc s_powerup_dlo
    sta s_powerup_fx
    lda g_powerup_x_lo
    adc s_powerup_dhi
    sta g_powerup_x_lo
    lda g_powerup_x_hi
    adc s_powerup_dext
    sta g_powerup_x_hi

    ; --- move Y (8-bit position + 8-bit fraction) ---
    lda s_powerup_avy
    jsr powerup_calc_delta
    lda s_powerup_fy
    clc
    adc s_powerup_dlo
    sta s_powerup_fy
    lda g_powerup_y
    adc s_powerup_dhi
    sta g_powerup_y

    ; --------------------------------------------------------------------------
    ; 6. Top 2/3 Playfield Clamping & Chaotic Reflection
    ; Bounds: X in [124..305], Y in [56..232]
    ; Allows smooth entry when spawning off-screen at Top (X=344) or Sides (Y=29/250)
    ; --------------------------------------------------------------------------
    ; --- Check X Lower Bound: 124 (Bottom of Top 2/3) ---
    lda g_powerup_x_hi
    bne @check_x_max            ; If hi > 0, X >= 256 > 124 (safe)
    lda g_powerup_x_lo
    cmp #BONUS_BOUND_MIN_X      ; 124
    bcs @x_bounds_ok

    ; Hit 124 boundary: clamp and reflect forward (vx = +1 or +2)
    lda #BONUS_BOUND_MIN_X
    sta g_powerup_x_lo
    lda #1
    sta s_powerup_avx
    jsr starfield_rand
    and #$01
    clc
    adc #1                      ; +1 or +2
    sta s_powerup_vx
    ; Chaotic Y perturbation
    jsr starfield_rand
    and #$03
    tax
    lda bounce_perturb_table, x
    sta s_powerup_vy
    jmp @x_bounds_ok

@check_x_max:
    ; --- Check X Upper Bound: 305 (Top of Screen: hi = 1, lo = 49) ---
    lda g_powerup_x_hi
    cmp #1
    bcc @x_bounds_ok            ; hi == 0, safe
    lda g_powerup_x_lo
    cmp #BONUS_BOUND_MAX_X_LO   ; 49
    bcc @x_bounds_ok

    ; If already moving downward into screen (avx < 0, e.g. top spawn), allow entry
    lda s_powerup_avx
    bmi @x_bounds_ok

    ; Hit 305 boundary from inside: clamp and reflect backward (vx = -1 or -2)
    lda #BONUS_BOUND_MAX_X_LO
    sta g_powerup_x_lo
    lda #1
    sta g_powerup_x_hi
    lda #$ff
    sta s_powerup_avx
    jsr starfield_rand
    and #$01
    clc
    adc #1
    eor #$ff
    clc
    adc #1                      ; -1 or -2 ($FF or $FE)
    sta s_powerup_vx
    ; Chaotic Y perturbation
    jsr starfield_rand
    and #$03
    tax
    lda bounce_perturb_table, x
    sta s_powerup_vy

@x_bounds_ok:
    ; --- Check Y Left Bound: 56 ---
    lda g_powerup_y
    cmp #BONUS_BOUND_MIN_Y      ; 56
    bcs @check_y_max

    ; If already moving rightward into screen (avy > 0, e.g. left spawn), allow entry
    lda s_powerup_avy
    beq @bounce_y_min
    bpl @y_bounds_ok

@bounce_y_min:
    ; Hit Y min from inside: clamp and reflect right (vy = +1 or +2)
    lda #BONUS_BOUND_MIN_Y
    sta g_powerup_y
    lda #1
    sta s_powerup_avy
    jsr starfield_rand
    and #$01
    clc
    adc #1                      ; +1 or +2
    sta s_powerup_vy
    ; Chaotic X perturbation
    jsr starfield_rand
    and #$03
    tax
    lda bounce_perturb_table, x
    sta s_powerup_vx
    jmp @y_bounds_ok

@check_y_max:
    ; --- Check Y Right Bound: 232 ---
    cmp #BONUS_BOUND_MAX_Y      ; 232
    bcc @y_bounds_ok

    ; If already moving leftward into screen (avy < 0, e.g. right spawn), allow entry
    lda s_powerup_avy
    bmi @y_bounds_ok

    ; Hit Y max from inside: clamp and reflect left (vy = -1 or -2)
    lda #BONUS_BOUND_MAX_Y
    sta g_powerup_y
    lda #$ff
    sta s_powerup_avy
    jsr starfield_rand
    and #$01
    clc
    adc #1
    eor #$ff
    clc
    adc #1                      ; -1 or -2
    sta s_powerup_vy
    ; Chaotic X perturbation
    jsr starfield_rand
    and #$03
    tax
    lda bounce_perturb_table, x
    sta s_powerup_vx

@y_bounds_ok:
    ; --------------------------------------------------------------------------
    ; 7. Color Cycle Animation (every 20 frames)
    ; --------------------------------------------------------------------------
    dec s_powerup_color_timer
    bne @apply_color
    lda #20
    sta s_powerup_color_timer
    inc s_powerup_color_idx
    lda s_powerup_color_idx
    cmp #3
    bcc @apply_color
    lda #0
    sta s_powerup_color_idx

@apply_color:
    jsr powerups_apply_color_now

@check_spawn:
    ; --------------------------------------------------------------------------
    ; 8. Natural Spawn Countdown (only counts when no powerup active)
    ; --------------------------------------------------------------------------
    lda g_powerup_active
    bne @update_done            ; Don't count down spawn timer while one is active

    lda g_powerup_timer_lo
    sec
    sbc #1
    sta g_powerup_timer_lo
    lda g_powerup_timer_hi
    sbc #0
    sta g_powerup_timer_hi
    bne @update_done
    lda g_powerup_timer_lo
    bne @update_done

    ; Timer reached 0: spawn powerup naturally and re-arm
    jsr powerups_spawn
    lda #<POWERUP_SPAWN_INTERVAL
    sta g_powerup_timer_lo
    lda #>POWERUP_SPAWN_INTERVAL
    sta g_powerup_timer_hi

@update_done:
    rts

; ==============================================================================
; Subroutine: powerups_apply_color_now
; Purpose: Sets s_powerup_current_color based on g_powerup_type and s_powerup_color_idx.
; ==============================================================================
powerups_apply_color_now:
    ldx s_powerup_color_idx
    lda g_powerup_type
    cmp #POWERUP_TYPE_B
    beq @color_b
    cmp #POWERUP_TYPE_E
    beq @color_e

    ; POWERUP_TYPE_P: Blue -> Light Blue -> Cyan
    lda powerup_p_color_cycle, x
    sta s_powerup_current_color
    rts

@color_b:
    ; POWERUP_TYPE_B: Red -> Light Red -> Purple
    lda powerup_b_color_cycle, x
    sta s_powerup_current_color
    rts

@color_e:
    ; POWERUP_TYPE_E: Green -> Light Green -> Cyan
    lda powerup_e_color_cycle, x
    sta s_powerup_current_color
    rts

; ==============================================================================
; Subroutine: powerups_check_shot
; Purpose: Tests active player missile against active bonus item.
;          If hit: missile is absorbed (sparks), and the bonus cycles to the
;          next type in the sequence: B -> E -> P -> B.
; ==============================================================================
powerups_check_shot:
    ; Exit if powerup is not active
    lda g_powerup_active
    bne +
    rts
+
    ; Exit if missile is not currently in flight (1 = in flight)
    lda g_missile_active
    cmp #1
    beq +
    rts
+

    ; 1. Vertical Range Check:
    ; diff_y = (g_powerup_y + 21) - g_missile_y
    ; Overlap if 0 < diff_y < shot_v_threshold[phase]
    ldy g_player_phase
    dey                         ; 1..5 -> 0..4
    lda g_powerup_y
    clc
    adc #21
    sec
    sbc g_missile_y
    bcc @no_hit                 ; powerup is entirely above missile
    beq @no_hit
    cmp shot_v_threshold_table, y
    bcs @no_hit                 ; powerup is entirely below missile

    ; 2. Horizontal Swept Check (missile moves rightward):
    ; T = missile_x + shot_sweep_table[phase]
    ; diff_x = T - powerup_x
    ; Overlap if 0 < diff_x < shot_h_thresh_table[phase]
    lda g_missile_x + 0
    clc
    adc shot_sweep_table, y
    sta s_powerup_diff_lo
    lda g_missile_x + 1
    adc #0
    sta s_powerup_diff_hi

    lda s_powerup_diff_lo
    sec
    sbc g_powerup_x_lo
    sta s_powerup_diff_lo
    lda s_powerup_diff_hi
    sbc g_powerup_x_hi
    bne @no_hit                 ; diff_x < 0 or diff_x >= 256

    lda s_powerup_diff_lo
    beq @no_hit
    cmp shot_h_thresh_table, y
    bcs @no_hit

    ; --------------------------------------------------------------------------
    ; Direct Hit Confirmed: Cycle B -> E -> P -> B
    ; --------------------------------------------------------------------------
    ldx g_powerup_type          ; 0=P, 1=B, 2=E
    lda powerup_next_type_table, x
    sta g_powerup_type

    ; Reset color cycle index and set new color immediately
    lda #0
    sta s_powerup_color_idx
    lda #20
    sta s_powerup_color_timer
    jsr powerups_apply_color_now

    ; Absorb missile: trigger 4-frame hit spark on Sprite 1
    lda #4
    sta g_missile_active

    ; Position spark at the bonus coordinates
    lda g_powerup_x_lo
    sec
    sbc #4
    sta g_missile_x + 0
    lda g_powerup_x_hi
    sbc #0
    sta g_missile_x + 1

    lda g_powerup_y
    sta g_missile_y

    ; Energy color for spark
    lda #COLOR_WHITE
    sta g_spark_color

    ; Audio feedback: play typewriter click / chime sound
    lda #SFX_KEY_CLICK
    jsr sound_play_sfx

@no_hit:
    rts

; ==============================================================================
; Subroutine: powerups_check_collision
; Purpose: Checks player ship bounding box against Bonus sprite position.
;          Levels up player phase on touch and restores HP to 5 if at Phase 5.
; ==============================================================================
powerups_check_collision:
    ; Exit if powerup is inactive
    lda g_powerup_active
    beq @exit_no_coll

    ; Exit if player is dead
    lda g_player_alive
    beq @exit_no_coll

    ; --------------------------------------------------------------------------
    ; 1. Vertical Range Check:
    ; diff_y = (g_powerup_y + 21) - g_player_y
    ; Overlap if 0 < diff_y < (player_h + 21)
    ; Unscaled player: player_h = 21 -> threshold = 42
    ; Scaled player:   player_h = 42 -> threshold = 63
    ; --------------------------------------------------------------------------
    lda g_powerup_y
    clc
    adc #21
    sec
    sbc g_player_y             ; diff_y in Accumulator
    bcc @exit_no_coll          ; diff_y < 0
    beq @exit_no_coll
    sta s_powerup_diff_lo

    ldx g_player_phase
    dex                         ; 1..5 -> 0..4
    lda player_phase_scaled, x
    bne @scaled_v_test

    lda s_powerup_diff_lo
    cmp #42
    bcs @exit_no_coll
    bcc @check_horizontal

@scaled_v_test:
    lda s_powerup_diff_lo
    cmp #63
    bcs @exit_no_coll

@check_horizontal:
    ; --------------------------------------------------------------------------
    ; 2. Horizontal Range Check (16-bit math):
    ; diff_x = (g_powerup_x + 24) - g_player_x
    ; Overlap if 0 < diff_x < (player_w + 24)
    ; Unscaled player: player_w = 24 -> threshold = 48
    ; Scaled player:   player_w = 48 -> threshold = 72
    ; --------------------------------------------------------------------------
    lda g_powerup_x_lo
    clc
    adc #24
    sta s_powerup_diff_lo
    lda g_powerup_x_hi
    adc #0
    sta s_powerup_diff_hi

    lda s_powerup_diff_lo
    sec
    sbc g_player_x + 0
    sta s_powerup_diff_lo
    lda s_powerup_diff_hi
    sbc g_player_x + 1
    bne @exit_no_coll           ; diff_x < 0 or diff_x >= 256

    lda s_powerup_diff_lo
    beq @exit_no_coll

    ldx g_player_phase
    dex                         ; 0..4
    lda player_phase_scaled, x
    bne @scaled_h_test

    lda s_powerup_diff_lo
    cmp #48
    bcs @exit_no_coll
    bcc @powerup_collected

@scaled_h_test:
    lda s_powerup_diff_lo
    cmp #72
    bcs @exit_no_coll
    bcc @powerup_collected

@exit_no_coll:
    rts

@powerup_collected:
    ; Erase powerup from screen buffer and deactivate
    jsr powerups_erase
    lda #0
    sta g_powerup_active

    ; Re-arm natural spawn timer
    lda #<POWERUP_SPAWN_INTERVAL
    sta g_powerup_timer_lo
    lda #>POWERUP_SPAWN_INTERVAL
    sta g_powerup_timer_hi

    ; Dispatch based on g_powerup_type (0=P, 1=B, 2=E)
    lda g_powerup_type
    beq @collect_type_p
    cmp #POWERUP_TYPE_B
    beq @collect_type_b
    jmp @collect_type_e

@collect_type_p:
    ; Evolution: Level up player phase (max 5)
    lda g_player_phase
    cmp #5
    bcs @p_feedback
    inc g_player_phase

@p_feedback:
    ; Flash border white for collection
    lda #COLOR_WHITE
    sta VIC_BORDER_COLOR
    lda #8
    sta g_debug_border_timer

    ; Trigger bonus chime sound effect
    lda #SFX_BONUS
    jsr sound_play_sfx

    ; Award 500 bonus points for collecting 'P' (5 * 100)
    lda #5
    jsr hud_add_score
    rts

@collect_type_b:
    ; Smart Bomb:
    jsr powerups_trigger_smart_bomb
    rts

@collect_type_e:
    ; Energy:
    ; 1. Restore +1 HP up to maximum 5 HP
    lda g_player_hp
    cmp #5
    bcc @heal_hp

    ; Already at full health: award 1,000 bonus points (10 * 100)
    lda #10
    jsr hud_add_score
    jmp @e_flash

@heal_hp:
    inc g_player_hp             ; Restore exactly +1 HP
    lda #0
    sta g_clutch_timer_lo
    sta g_clutch_timer_hi

    ; Award 500 bonus points (5 * 100)
    lda #5
    jsr hud_add_score

@e_flash:
    ; Light Green border flash for healing feedback
    lda #COLOR_LIGHT_GREEN
    sta VIC_BORDER_COLOR
    lda #8
    sta g_debug_border_timer

    ; Trigger bonus chime sound effect
    lda #SFX_BONUS
    jsr sound_play_sfx
    rts

@no_collision:
    rts

; ==============================================================================
; Subroutine: powerups_trigger_smart_bomb
; Purpose: Destroys all active enemies, clears bullets, triggers white strobe flash,
;          and awards 500 bonus points.
; ==============================================================================
powerups_trigger_smart_bomb:
    ; 1. Extended white border flash (15 frames = 0.3s)
    lda #COLOR_WHITE
    sta VIC_BORDER_COLOR
    lda #15
    sta g_debug_border_timer

    ; 2. Destroy all active living enemies
    ; 2. Trigger smart bomb rumble sound effect
    lda #SFX_BOMB
    jsr sound_play_sfx

    ; 3. Destroy all active living enemies (or deal 2 HP damage to boss in duel)
    ldx #0
@bomb_enemy_loop:
    lda g_enemy_active, x
    beq @bomb_next_enemy
    lda g_enemy_exploding, x
    bne @bomb_next_enemy

    ; Check if this is the boss during a boss duel (Slot 0 + g_boss_duel_active)
    cpx #0
    bne @bomb_kill_enemy
    lda g_boss_duel_active
    beq @bomb_kill_enemy

    ; Boss hit by Smart Bomb: deal 2 HP damage instead of instant kill
    lda g_enemy_hp + 0
    sec
    sbc #BOMB_BOSS_DAMAGE
    bcc @boss_bomb_lethal
    beq @boss_bomb_lethal
    sta g_enemy_hp + 0

    ; Flash boss white for hit feedback
    lda #6
    sta g_enemy_flash + 0
    lda #COLOR_WHITE
    sta g_enemy_color + 0
    jmp @bomb_next_enemy

@boss_bomb_lethal:
@bomb_kill_enemy:
    txa
    pha
    jsr collisions_kill_enemy
    pla
    tax
@bomb_next_enemy:
    inx
    cpx #MAX_ENEMIES
    bne @bomb_enemy_loop

    ; 3. Clear all active enemy bullets
    ldx #0
    lda #0
@bomb_bullet_loop:
    sta g_bullet_active, x
    inx
    cpx #MAX_ENEMY_BULLETS
    bne @bomb_bullet_loop

    ; 4. Award 500 bonus points for bomb pickup
    lda #5
    jsr hud_add_score
    rts

; ------------------------------------------------------------------------------
; Playfield Row Base Address Tables (Rows 0..24)
; ------------------------------------------------------------------------------
screen_row_table_lo:
    !byte $00, $28, $50, $78, $a0, $c8, $f0, $18
    !byte $40, $68, $90, $b8, $e0, $08, $30, $58
    !byte $80, $a8, $d0, $f8, $20, $48, $70, $98, $c0

screen_row_table_hi:
    !byte $04, $04, $04, $04, $04, $04, $04, $05
    !byte $05, $05, $05, $05, $05, $06, $06, $06
    !byte $06, $06, $06, $06, $07, $07, $07, $07, $07

color_row_table_lo = screen_row_table_lo

color_row_table_hi:
    !byte $d8, $d8, $d8, $d8, $d8, $d8, $d8, $d9
    !byte $d9, $d9, $d9, $d9, $d9, $da, $da, $da
    !byte $da, $da, $da, $da, $db, $db, $db, $db, $db

