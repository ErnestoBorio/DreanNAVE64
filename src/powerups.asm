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

POWERUP_CHAR_TL     = 0         ; Top-Left quadrant tile index
POWERUP_CHAR_TR     = 1         ; Top-Right quadrant tile index
POWERUP_CHAR_BL     = 16        ; Bottom-Left quadrant tile index ($10)
POWERUP_CHAR_BR     = 17        ; Bottom-Right quadrant tile index ($11)
POWERUP_COLOR       = COLOR_YELLOW ; Vibrant Yellow powerup color

POWERUP_INITIAL_DELAY   = 1250  ; 1,250 frames = 25.0 seconds at 50 Hz PAL
POWERUP_SPAWN_INTERVAL  = 2000  ; 2,000 frames = 40.0 seconds at 50 Hz PAL

; ------------------------------------------------------------------------------
; Powerup RAM State Variables
; ------------------------------------------------------------------------------
g_powerup_active:   !byte 0     ; 1 = Active on screen, 0 = Inactive
g_powerup_col:      !byte 0     ; Left column of powerup (0..38, $FF = offscreen left)
g_powerup_row:      !byte 0     ; Top row of powerup (2..22)
g_powerup_timer_lo: !byte 0     ; Countdown timer low byte for natural spawn
g_powerup_timer_hi: !byte 0     ; Countdown timer high byte for natural spawn
s_powerup_diff_lo:  !byte 0     ; Math scratch for collision testing
s_powerup_diff_hi:  !byte 0     ; Math scratch for collision testing

; ==============================================================================
; Subroutine: powerups_init
; Purpose: Resets powerup state and arms initial natural spawn timer (25 seconds).
; ==============================================================================
powerups_init:
    lda #0
    sta g_powerup_active
    sta g_powerup_col
    sta g_powerup_row
    lda #<POWERUP_INITIAL_DELAY
    sta g_powerup_timer_lo
    lda #>POWERUP_INITIAL_DELAY
    sta g_powerup_timer_hi
    rts

; ==============================================================================
; Subroutine: powerups_spawn
; Purpose: Attempts natural spawn at playfield right edge. If slot busy, exits.
; ==============================================================================
powerups_spawn:
    lda g_powerup_active
    beq +
    rts
+
    jsr powerups_stamp_new
    rts

; ==============================================================================
; Subroutine: powerups_spawn_forced
; Purpose: Immediately spawns powerup (erasing old one if active) for debug hotkey.
; ==============================================================================
powerups_spawn_forced:
    lda g_powerup_active
    beq +
    jsr powerups_erase
+
    jsr powerups_stamp_new
    ; Visual border flash feedback
    lda #COLOR_WHITE
    sta VIC_BORDER_COLOR
    lda #8
    sta g_debug_border_timer
    rts

; ==============================================================================
; Internal Subroutine: powerups_stamp_new
; Purpose: Picks random playfield row, stamps 4 quadrants to Screen & Color RAM.
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

    ; 1. Stamp Top Row (Row R): Char 0 at Col 38, Char 1 at Col 39
    ldy g_powerup_row
    lda screen_row_table_lo, y
    sta $fb
    lda screen_row_table_hi, y
    sta $fc

    lda color_row_table_lo, y
    sta $fd
    lda color_row_table_hi, y
    sta $fe

    ldy #38
    lda #POWERUP_CHAR_TL
    sta ($fb), y
    lda #POWERUP_COLOR
    sta ($fd), y

    iny                         ; 39
    lda #POWERUP_CHAR_TR
    sta ($fb), y
    lda #POWERUP_COLOR
    sta ($fd), y

    ; 2. Stamp Bottom Row (Row R + 1): Char 16 at Col 38, Char 17 at Col 39
    ldy g_powerup_row
    iny                         ; Row R + 1
    lda screen_row_table_lo, y
    sta $fb
    lda screen_row_table_hi, y
    sta $fc

    lda color_row_table_lo, y
    sta $fd
    lda color_row_table_hi, y
    sta $fe

    ldy #38
    lda #POWERUP_CHAR_BL
    sta ($fb), y
    lda #POWERUP_COLOR
    sta ($fd), y

    iny                         ; 39
    lda #POWERUP_CHAR_BR
    sta ($fb), y
    lda #POWERUP_COLOR
    sta ($fd), y

    rts

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
    cmp #POWERUP_CHAR_TL
    beq @wipe_r1
    cmp #POWERUP_CHAR_TR
    bne @next_r1
@wipe_r1:
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
    cmp #POWERUP_CHAR_BL
    beq @wipe_r2
    cmp #POWERUP_CHAR_BR
    bne @next_r2
@wipe_r2:
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
; Subroutine: powerups_update
; Purpose: Advances scroll position on starfield shift frames first, then counts
;          down natural spawn timer. This strict order prevents 1-column desync.
; ==============================================================================
powerups_update:
    ; 1. Synchronize column scroll with starfield shift (every 4 frames)
    lda g_starfield_frame
    and #$03
    bne @check_spawn

    lda g_powerup_active
    beq @check_spawn

    ; If col was 0, decrement to $FF (left half leaves screen, right half at col 0)
    ; If col was $FF, both halves have left screen -> deactivate!
    lda g_powerup_col
    cmp #$ff
    beq @deactivate

    sec
    sbc #1
    sta g_powerup_col
    cmp #$ff
    bne @check_spawn

@deactivate:
    lda #0
    sta g_powerup_active

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
    ; Erase 'P' from screen buffer and deactivate
    jsr powerups_erase
    lda #0
    sta g_powerup_active

    ; Re-arm natural spawn timer
    lda #<POWERUP_SPAWN_INTERVAL
    sta g_powerup_timer_lo
    lda #>POWERUP_SPAWN_INTERVAL
    sta g_powerup_timer_hi

    ; Level up player phase (max 5)
    lda g_player_phase
    cmp #5
    bcs @collect_feedback

    inc g_player_phase
    jmp @collect_feedback

@collect_feedback:
    ; Flash border white for collection
    lda #COLOR_WHITE
    sta VIC_BORDER_COLOR
    lda #8
    sta g_debug_border_timer

    ; Award 500 bonus points for collecting 'P' (5 * 100)
    lda #5
    jsr hud_add_score

@no_collision:
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

color_row_table_lo:
    !byte $00, $28, $50, $78, $a0, $c8, $f0, $18
    !byte $40, $68, $90, $b8, $e0, $08, $30, $58
    !byte $80, $a8, $d0, $f8, $20, $48, $70, $98, $c0

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
