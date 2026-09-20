; ==============================================================================
; POWERUPS.ASM - Letter 'P' Powerup Entity & Playfield Grid Collision (Phase 9)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
;
; Manages:
; - Letter 'P' powerup composed of custom charset tiles:
;   * Top-Left:     Tile $00 (0)
;   * Top-Right:    Tile $01 (1)
;   * Bottom-Left:  Tile $10 (16)
;   * Bottom-Right: Tile $11 (17)
; - Screen RAM & Color RAM placement at playfield right edge (cols 38..39)
; - Uniform leftward scrolling synchronized with 25 FPS starfield shifts
; - Accurate bounding-box collection by player ship
; - Evolution leveling up through 5 ship phases (and full HP heal at max phase)
; ==============================================================================

POWERUP_TYPE_P      = 0         ; Evolution Phase Level-Up ('P')
POWERUP_TYPE_B      = 1         ; Smart Bomb ('B')
POWERUP_TYPE_E      = 2         ; Energy Recovery ('E')
NUM_POWERUP_TYPES   = 3

POWERUP_INITIAL_DELAY   = 200   ; 200 frames = 4.0 seconds at 50 Hz PAL (was 12s)
POWERUP_SPAWN_INTERVAL  = 400   ; 400 frames = 8.0 seconds at 50 Hz PAL (was 18s)

; 2x2 Custom Charset Tiles for P, B, and E
powerup_tile_tl:
    !byte 0, 2, 4               ; P=0, B=2, E=4
powerup_tile_tr:
    !byte 1, 3, 5               ; P=1, B=3, E=5
powerup_tile_bl:
    !byte 16, 18, 20            ; P=16, B=18, E=20
powerup_tile_br:
    !byte 17, 19, 21            ; P=17, B=19, E=21

; ------------------------------------------------------------------------------
; Powerup RAM State Variables
; ------------------------------------------------------------------------------
g_powerup_active:   !byte 0     ; 1 = Active on screen, 0 = Inactive
g_powerup_type:     !byte POWERUP_TYPE_P ; Current powerup type (0=P, 1=B, 2=E)
g_powerup_col:      !byte 0     ; Left column of powerup (0..38, $FF = offscreen left)
g_powerup_row:      !byte 0     ; Top row of powerup (2..22)
g_powerup_timer_lo: !byte 0     ; Countdown timer low byte for natural spawn
g_powerup_timer_hi: !byte 0     ; Countdown timer high byte for natural spawn
s_powerup_diff_lo:  !byte 0     ; Math scratch for collision testing
s_powerup_diff_hi:  !byte 0     ; Math scratch for collision testing
s_powerup_color_timer:   !byte 20 ; 20 frames = 0.4s at 50 Hz PAL
s_powerup_color_idx:     !byte 0  ; Index in cycle (0..3 for P, 0..2 for B/E)
s_powerup_current_color: !byte COLOR_PURPLE

; Color cycle table for P: Purple -> Blue -> Light Blue -> Cyan
powerup_p_color_cycle:
    !byte COLOR_PURPLE, COLOR_BLUE, COLOR_LIGHT_BLUE, COLOR_CYAN

; Color cycle table for B: PURPLE -> Red -> Light Red
powerup_b_color_cycle:
    !byte COLOR_PURPLE, COLOR_RED, COLOR_LIGHT_RED

; Color cycle table for E: Green -> Light Green -> Cyan
powerup_e_color_cycle:
    !byte COLOR_GREEN, COLOR_LIGHT_GREEN, COLOR_CYAN

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

; ==============================================================================
; Subroutine: powerups_init
; Purpose: Resets powerup state and arms initial natural spawn timer (12 seconds).
; ==============================================================================
powerups_init:
    lda #0
    sta g_powerup_active
    sta g_powerup_type
    sta g_powerup_col
    sta g_powerup_row
    sta s_powerup_color_idx
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
; Subroutine: powerups_spawn
; Purpose: Attempts natural spawn at playfield right edge. Picks random type.
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
    jmp @spawn_stamp

@normal_type_pick:
    ; Pick from 8-entry table (50% E, 37.5% P, 12.5% B)
    jsr starfield_rand
    and #$07
    tax
    lda powerup_type_table, x
    sta g_powerup_type

@spawn_stamp:
    jsr powerups_stamp_new
    rts

; ==============================================================================
; Subroutine: powerups_spawn_forced
; Purpose: Immediately spawns powerup (erasing old one if active) for debug hotkey.
;          Cycles powerup type: P -> B -> E -> P.
; ==============================================================================
powerups_spawn_forced:
    lda g_powerup_active
    beq +
    jsr powerups_erase
+
    ; Cycle powerup type (0 -> 1 -> 2 -> 0)
    inc g_powerup_type
    lda g_powerup_type
    cmp #NUM_POWERUP_TYPES
    bcc +
    lda #0
    sta g_powerup_type
+
    jsr powerups_stamp_new
    ; Visual border flash feedback
    lda #COLOR_WHITE
    sta VIC_BORDER_COLOR
    lda #8
    sta g_debug_border_timer
    rts

; ==============================================================================
; Subroutine: powerups_spawn_forced_type
; Purpose: Immediately spawns specified powerup type passed in A.
; Arguments: A = powerup type (POWERUP_TYPE_P, POWERUP_TYPE_B, POWERUP_TYPE_E)
; ==============================================================================
powerups_spawn_forced_type:
    pha
    lda g_powerup_active
    beq +
    jsr powerups_erase
+
    pla
    sta g_powerup_type
    jsr powerups_stamp_new
    ; Visual border flash feedback
    lda #COLOR_WHITE
    sta VIC_BORDER_COLOR
    lda #8
    sta g_debug_border_timer
    rts

; ==============================================================================
; Internal Subroutine: powerups_stamp_new
; Purpose: Picks random playfield row, stamps 4 quadrants of current powerup type.
; ==============================================================================
powerups_stamp_new:
    ; Pick random row between 3 and 18
    jsr starfield_rand
    and #$0f                    ; 0..15
    clc
    adc #3                      ; 3..18
    sta g_powerup_row

    lda #38
    sta g_powerup_col
    lda #1
    sta g_powerup_active

    ; Reset color cycle (0.4s per color)
    lda #0
    sta s_powerup_color_idx
    lda #20
    sta s_powerup_color_timer

    ; Load current powerup type index
    ldx g_powerup_type

    ; 1. Stamp Top Row (Row R): Char TL at Col 38, Char TR at Col 39
    ldy g_powerup_row
    lda screen_row_table_lo, y
    sta $fb
    lda screen_row_table_hi, y
    sta $fc

    ldy #38
    lda powerup_tile_tl, x
    sta ($fb), y
    iny                         ; 39
    lda powerup_tile_tr, x
    sta ($fb), y

    ; 2. Stamp Bottom Row (Row R + 1): Char BL at Col 38, Char BR at Col 39
    ldy g_powerup_row
    iny                         ; Row R + 1
    lda screen_row_table_lo, y
    sta $fb
    lda screen_row_table_hi, y
    sta $fc

    ldy #38
    lda powerup_tile_bl, x
    sta ($fb), y
    iny                         ; 39
    lda powerup_tile_br, x
    sta ($fb), y

    ; 3. Apply initial color across both rows
    jmp powerups_recolor

; ==============================================================================
; Subroutine: powerups_erase
; Purpose: Erases current powerup cells from Screen RAM by writing blank space ($20).
;          Scans a 5-column window (col - 2 .. col + 2) on both rows to ensure
;          every quadrant tile (0, 1, 16, 17) is completely erased without artifacts.
; ==============================================================================
powerups_erase:
    lda g_powerup_active
    bne +
    rts
+
    ; 1. Clean Row R
    ldy g_powerup_row
    cpy #25
    bcs @start_row2
    lda screen_row_table_lo, y
    sta $fb
    lda screen_row_table_hi, y
    sta $fc

    ; Determine start column: max(0, g_powerup_col - 2)
    lda g_powerup_col
    cmp #2
    bcs +
    lda #2
+   sec
    sbc #2
    tay                         ; Y = start_col

@erase_row1_loop:
    cpy #40
    bcs @start_row2
    lda ($fb), y
    cmp #6                      ; Top quadrants: 0, 1 (P), 2, 3 (B), 4, 5 (E)
    bcs @next_r1
    lda #$20
    sta ($fb), y
@next_r1:
    iny
    tya
    sec
    sbc g_powerup_col
    cmp #3                      ; Check up to col + 2
    bmi @erase_row1_loop

@start_row2:
    ; 2. Clean Row R + 1
    ldy g_powerup_row
    iny
    cpy #25
    bcs @erase_done
    lda screen_row_table_lo, y
    sta $fb
    lda screen_row_table_hi, y
    sta $fc

    ; Determine start column: max(0, g_powerup_col - 2)
    lda g_powerup_col
    cmp #2
    bcs +
    lda #2
+   sec
    sbc #2
    tay                         ; Y = start_col

@erase_row2_loop:
    cpy #40
    bcs @erase_done
    lda ($fb), y
    cmp #16                     ; Bottom quadrants: 16, 17 (P), 18, 19 (B), 20, 21 (E)
    bcc @next_r2
    cmp #22
    bcs @next_r2
    lda #$20
    sta ($fb), y
@next_r2:
    iny
    tya
    sec
    sbc g_powerup_col
    cmp #3                      ; Check up to col + 2
    bmi @erase_row2_loop

@erase_done:
    rts

; ==============================================================================
; Subroutine: powerups_recolor
; Purpose: Re-paints current cycling color into Color RAM for active powerup tiles.
;          Cycles through Purple, Blue, Light Blue, Cyan (0.5s each).
; ==============================================================================
powerups_recolor:
    lda g_powerup_active
    bne +
    rts
+
    ldx s_powerup_color_idx
    lda g_powerup_type
    cmp #POWERUP_TYPE_B
    beq @color_b
    cmp #POWERUP_TYPE_E
    beq @color_e

    ; Default: Powerup P (Purple -> Blue -> Light Blue -> Cyan)
    lda powerup_p_color_cycle, x
    jmp @store_color

@color_b:
    ; Powerup B: PURPLE -> Red -> Light Red
    lda powerup_b_color_cycle, x
    jmp @store_color

@color_e:
    ; Powerup E: Green -> Light Green -> Cyan
    lda powerup_e_color_cycle, x

@store_color:
    sta s_powerup_current_color

    ldx #0                      ; Row offset: 0 = Row R, 1 = Row R + 1
@row_loop:
    txa
    clc
    adc g_powerup_row
    tay
    cpy #25
    bcs @next_row

    lda color_row_table_lo, y
    sta $fd
    lda color_row_table_hi, y
    sta $fe

    lda g_powerup_col
    cmp #$ff
    beq @col_edge

    tay
    lda s_powerup_current_color
    sta ($fd), y
    iny
    sta ($fd), y
    jmp @next_row

@col_edge:
    ldy #0
    lda s_powerup_current_color
    sta ($fd), y

@next_row:
    inx
    cpx #2
    bne @row_loop
    rts

; ==============================================================================
; Subroutine: powerups_update
; Purpose: Advances scroll position on starfield shift frames first, updates
;          color cycling animation, then counts down natural spawn timer.
; ==============================================================================
powerups_update:
    ; 1. Synchronize column scroll with starfield shift (every 4 frames)
    lda g_starfield_frame
    and #$03
    bne @check_anim

    lda g_powerup_active
    beq @check_anim

    ; If col was 0, decrement to $FF (left half leaves screen, right half at col 0)
    ; If col was $FF, both halves have left screen -> deactivate!
    lda g_powerup_col
    cmp #$ff
    beq @deactivate

    sec
    sbc #1
    sta g_powerup_col
    cmp #$ff
    bne @check_anim

@deactivate:
    lda #0
    sta g_powerup_active

@check_anim:
    lda g_powerup_active
    beq @check_spawn

    ; Decrement color animation timer (20 frames = 0.4s at 50 Hz PAL)
    dec s_powerup_color_timer
    bne @apply_recolor
    lda #20
    sta s_powerup_color_timer
    inc s_powerup_color_idx

    lda g_powerup_type
    beq @wrap_p                 ; P has 4 colors

    ; B and E have 3 colors (0..2)
    lda s_powerup_color_idx
    cmp #3
    bcc @apply_recolor
    lda #0
    sta s_powerup_color_idx
    jmp @apply_recolor

@wrap_p:
    lda s_powerup_color_idx
    and #$03
    sta s_powerup_color_idx

@apply_recolor:
    jsr powerups_recolor

@check_spawn:
    ; 2. Decrement natural spawn timer
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

    ; Timer reached 0: try to spawn powerup naturally and re-arm
    jsr powerups_spawn
    lda #<POWERUP_SPAWN_INTERVAL
    sta g_powerup_timer_lo
    lda #>POWERUP_SPAWN_INTERVAL
    sta g_powerup_timer_hi

@update_done:
    rts

; ==============================================================================
; Subroutine: powerups_check_collision
; Purpose: Checks player ship bounding box against Letter 'P' grid position.
;          Levels up player phase on touch and restores HP to 5 if at Phase 5.
; ==============================================================================
powerups_check_collision:
    ; Exit if powerup is inactive or partially offscreen ($FF)
    lda g_powerup_active
    beq @exit_no_coll
    lda g_powerup_col
    cmp #$ff
    beq @exit_no_coll

    ; Exit if player is dead
    lda g_player_alive
    beq @exit_no_coll
    bne @do_check

@exit_no_coll:
    rts

@do_check:
    ; --------------------------------------------------------------------------
    ; 1. Vertical Range Check:
    ; diff_y = (player_y + 16) - powerup_y[row]
    ; Overlap if: 0 <= diff_y < (player_h + 16)
    ; Unscaled player: player_h = 21 -> threshold = 37
    ; Scaled player:   player_h = 42 -> threshold = 58
    ; --------------------------------------------------------------------------
    ldy g_powerup_row
    lda g_player_y
    clc
    adc #16
    sec
    sbc powerup_y_coords, y     ; diff_y in Accumulator

    ldx g_player_phase
    dex                         ; 1..5 -> 0..4
    ldy player_phase_scaled, x
    bne @scaled_v_test

    cmp #37                     ; 21 + 16 = 37
    bcs @exit_no_coll
    bcc @check_horizontal

@scaled_v_test:
    cmp #58                     ; 42 + 16 = 58
    bcs @exit_no_coll

@check_horizontal:
    ; --------------------------------------------------------------------------
    ; 2. Horizontal Range Check:
    ; diff_x = player_x - powerup_x[col]
    ; Overlap if: 0 <= (diff_x + player_w) < (player_w + 16)
    ; Unscaled player: player_w = 24 -> threshold = 40 (24 + 16)
    ; Scaled player:   player_w = 48 -> threshold = 64 (48 + 16)
    ; --------------------------------------------------------------------------
    ldy g_powerup_col
    lda g_player_x + 0
    sec
    sbc powerup_x_coords_lo, y
    sta s_powerup_diff_lo
    lda g_player_x + 1
    sbc powerup_x_coords_hi, y
    sta s_powerup_diff_hi

    ; Check if scaled
    ldx g_player_phase
    dex                         ; 0..4
    lda player_phase_scaled, x
    bne @scaled_h_test

    ; Unscaled: add player_w (24)
    lda s_powerup_diff_lo
    clc
    adc #24
    sta s_powerup_diff_lo
    lda s_powerup_diff_hi
    adc #0
    bne @exit_no_coll           ; Out of horizontal range
    lda s_powerup_diff_lo
    cmp #40                     ; 24 + 16 = 40
    bcs @exit_no_coll
    bcc @powerup_collected

@scaled_h_test:
    ; Scaled: add player_w (48)
    lda s_powerup_diff_lo
    clc
    adc #48
    sta s_powerup_diff_lo
    lda s_powerup_diff_hi
    adc #0
    bne @exit_no_coll           ; Out of horizontal range
    lda s_powerup_diff_lo
    cmp #64                     ; 48 + 16 = 64
    bcs @exit_no_coll

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

    ; Award 500 bonus points (5 * 100)
    lda #5
    jsr hud_add_score

@e_flash:
    ; Light Green border flash for healing feedback
    lda #COLOR_LIGHT_GREEN
    sta VIC_BORDER_COLOR
    lda #8
    sta g_debug_border_timer
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
    ldx #0
@bomb_enemy_loop:
    lda g_enemy_active, x
    beq @bomb_next_enemy
    lda g_enemy_exploding, x
    bne @bomb_next_enemy
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

; ------------------------------------------------------------------------------
; Column 0..39 to Raster X Coordinates (24 + Col * 8)
; ------------------------------------------------------------------------------
powerup_x_coords_lo:
    !byte  24,  32,  40,  48,  56,  64,  72,  80
    !byte  88,  96, 104, 112, 120, 128, 136, 144
    !byte 152, 160, 168, 176, 184, 192, 200, 208
    !byte 216, 224, 232, 240, 248,   0,   8,  16
    !byte  24,  32,  40,  48,  56,  64,  72,  80

powerup_x_coords_hi:
    !byte 0, 0, 0, 0, 0, 0, 0, 0
    !byte 0, 0, 0, 0, 0, 0, 0, 0
    !byte 0, 0, 0, 0, 0, 0, 0, 0
    !byte 0, 0, 0, 0, 0, 1, 1, 1
    !byte 1, 1, 1, 1, 1, 1, 1, 1

; ------------------------------------------------------------------------------
; Row 0..24 to Raster Y Coordinates (50 + Row * 8)
; ------------------------------------------------------------------------------
powerup_y_coords:
    !byte  50,  58,  66,  74,  82,  90,  98, 106
    !byte 114, 122, 130, 138, 146, 154, 162, 170
    !byte 178, 186, 194, 202, 210, 218, 226, 234, 242
