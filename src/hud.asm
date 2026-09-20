; ==============================================================================
; HUD.ASM - Heads-Up Display Subsystem (Phase 8: TATE Mode & Scoring)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
;
; Manages:
; - TATE Mode Rotated Status Bar on Character Row 0 ($0400-$0427, Color $D800-$D827)
; - Screen Right (Col 39) = Rotated TOP, Screen Left (Col 0) = Rotated BOTTOM
; - 1UP Indicator: Digit 1 (Char 49) + 'UP' (Char 107) in White (Cols 39..38)
; - 16-bit Score: Converted to 5 decimal digits with leading spaces + '00' bulk zeroes (Cols 37..31) in White
; - HI Indicator: 'H' (Char 72) + 'I' (Char 73) in Light Blue (Cols 25..24)
; - 16-bit Hi-Score: Converted to 5 decimal digits + '00' bulk zeroes (Cols 23..17) in Light Blue
; - Red Heart (Char 98) in Red at Col 10
; - 10-bar Energy Gauge (Char 106) in Yellow (Cols 9..0), decreasing from left to right (2 bars per HP)
; - Dynamic High Score tracking & persistent session storage
; - Game Over display and screen cleanup
; ==============================================================================

; ------------------------------------------------------------------------------
; HUD RAM Variables
; ------------------------------------------------------------------------------
g_score:            !word 0     ; 16-bit player score (0..65535, displayed * 100)
g_high_score:       !word 0     ; 16-bit high score (persists across games, default 0 pts)
s_prev_hi_score:    !word $ffff ; Cached high score for dirty check
s_score_val_lo:     !byte 0     ; Temporary binary-to-decimal working value low byte
s_score_val_hi:     !byte 0     ; Temporary binary-to-decimal working value high byte
s_score_digits:     !fill 5, 0  ; 5 decimal digits buffer (D4..D0)
s_empty_count:      !byte 0     ; Depleted energy bars count (0..10)
s_bar_color:        !byte 0     ; Dynamic color for active energy bars
s_prev_hp:          !byte $ff   ; Cached player effective HP for dirty check
s_prev_score:       !word $ffff ; Cached player score for dirty check
s_cur_row:          !byte 0     ; Row cursor for playfield text rendering
s_char_color:       !byte COLOR_WHITE ; Current drawing color for hud_draw_char

; Energy bar color table by HP remaining (0..5):
; 5, 4 HP -> Light Green; 3 HP -> Yellow; 2, 1, 0 HP -> Red
energy_color_table:
    !byte COLOR_RED, COLOR_RED, COLOR_RED, COLOR_YELLOW, COLOR_LIGHT_GREEN, COLOR_LIGHT_GREEN

; Power-of-10 table for 16-bit binary-to-decimal conversion (10000, 1000, 100, 10)
hud_pow10_hi:       !byte >10000, >1000, >100, >10
hud_pow10_lo:       !byte <10000, <1000, <100, <10

; ==============================================================================
; Subroutine: hud_init
; Purpose: Resets score, invalidates cached dirty flags, and clears Row 0.
;          Note: g_high_score is preserved across game sessions!
; ==============================================================================
hud_init:
    lda #0
    sta g_score + 0
    sta g_score + 1
    sta g_game_over
    sta g_game_over_timer
    lda #$ff
    sta s_prev_hp
    sta s_prev_score + 0
    sta s_prev_score + 1
    sta s_prev_hi_score + 0
    sta s_prev_hi_score + 1
    jmp hud_clear

; ==============================================================================
; Subroutine: hud_clear
; Purpose: Clears character Row 0 ($0400..$0427) with blank spaces and black color.
; ==============================================================================
hud_clear:
    ldx #39
    lda #$20
-   sta $0400, x
    lda #COLOR_BLACK
    sta $d800, x
    dex
    bpl -
    rts

; ==============================================================================
; Subroutine: hud_show
; Purpose: Draws static HUD elements (1UP, HI, Heart, 000) and renders energy,
;          score, and high score to Row 0.
; ==============================================================================
hud_show:
    jsr hud_clear

    ; 1. Draw '1UP' at Cols 39 and 38 (Rotated Top of screen)
    ; Col 39 = '1' (Char 49), Col 38 = 'UP' (Char 107) in White
    lda #49
    sta $0427
    lda #107
    sta $0426
    lda #COLOR_WHITE
    sta $d827
    sta $d826

    ; Draw 1UP bulk double zeroes '00' (Char 48 = $30) at Cols 32 and 31
    lda #$30
    sta $0420
    sta $041f

    ; Set Color RAM for 1UP score digits & bulk zeroes (Cols 37..31: $D825..$D81F) in White
    lda #COLOR_WHITE
    ldx #6
-   sta $d81f, x
    dex
    bpl -

    ; 2. Draw 'HI' centered between Score (Col 31) and Energy Bar Heart (Col 10)
    ; HI-score cluster occupies Cols 25..17 (5 spaces above: Cols 30..26, 6 spaces below: Cols 16..11)
    ; Col 25 = 'H' (Char 72), Col 24 = 'I' (Char 73) in Light Blue
    lda #72
    sta $0419
    lda #73
    sta $0418
    lda #COLOR_LIGHT_BLUE
    sta $d819
    sta $d818

    ; Set Color RAM for HI score digits & bulk zeroes (Cols 23..17: $D817..$D811) in Light Blue
    lda #COLOR_LIGHT_BLUE
    ldx #6
-   sta $d811, x
    dex
    bpl -

    ; Draw HI bulk double zeroes '00' (Char 48 = $30) at Cols 18 and 17
    lda #$30
    sta $0412
    sta $0411

    ; 3. Draw Red Heart at Col 10 (Char 98) in Red
    lda #98
    sta $040a
    lda #COLOR_RED
    sta $d80a

    ; Reset dirty flags to force re-render
    lda #$ff
    sta s_prev_hp
    sta s_prev_score + 0
    sta s_prev_score + 1
    sta s_prev_hi_score + 0
    sta s_prev_hi_score + 1

    ; Initial render of score, hiscore, and energy
    jsr hud_render_energy
    jsr hud_render_score
    jsr hud_render_hiscore
    rts

; ==============================================================================
; Subroutine: hud_update
; Purpose: Checks if player effective HP, score, or hi-score changed, and triggers redraw.
; ==============================================================================
hud_update:
    ; 1. Calculate player effective HP:
    ; Shows actual player HP (0..5) across all phases (P item only advances phases, not energy)
    lda g_player_alive
    bne +
    lda #0
    beq @got_hp
+   lda g_player_hp             ; Displays actual HP (0..5) across all phases

@got_hp:
    cmp s_prev_hp
    beq @check_flash
    sta s_prev_hp
    jsr hud_render_energy

@check_flash:
    ; 2. Only flash when player is alive, in Phase 1, and at 1 or 2 HP (Phases 2+ have phase armor)
    lda g_player_alive
    beq @solid_red
    lda g_player_phase
    cmp #1
    bne @solid_red
    lda s_prev_hp
    beq @solid_red
    cmp #3
    bcs @solid_red

    ; Flash every 8 frames (~3.1 Hz heartbeat rate) between COLOR_RED and COLOR_WHITE
    lda g_game_time_frames
    and #$08
    beq @red_flash
    lda #COLOR_WHITE
    bne @apply_bar_color

@solid_red:
@red_flash:
    lda #COLOR_RED

@apply_bar_color:
    sta $d80a                   ; Heart color (Col 10)
    lda s_prev_hp
    beq @check_hi_score         ; 0 HP -> do not color bars (remain blank/black)
    cmp #3
    bcs @check_hi_score         ; 3..5 HP -> do not touch bars (already yellow/green)

    lda $d80a                   ; Reload color (WHITE or RED)
    ldx s_empty_count           ; Active energy bars: s_empty_count up to slot 9
-   sta $d800, x
    inx
    cpx #10
    bne -

@check_hi_score:
    ; Check if 16-bit high score changed
    lda g_high_score + 0
    cmp s_prev_hi_score + 0
    bne @do_hi_render
    lda g_high_score + 1
    cmp s_prev_hi_score + 1
    beq @check_score

@do_hi_render:
    lda g_high_score + 0
    sta s_prev_hi_score + 0
    lda g_high_score + 1
    sta s_prev_hi_score + 1
    jsr hud_render_hiscore

@check_score:
    ; Check if 16-bit score changed
    lda g_score + 0
    cmp s_prev_score + 0
    bne @do_score_render
    lda g_score + 1
    cmp s_prev_score + 1
    beq @update_done

@do_score_render:
    lda g_score + 0
    sta s_prev_score + 0
    lda g_score + 1
    sta s_prev_score + 1
    jsr hud_render_score

@update_done:
    rts

; ==============================================================================
; Subroutine: hud_render_energy
; Purpose: Renders 10-bar energy gauge (Cols 0..9) based on s_prev_hp (0..5).
;          Decreases from left to right: depleted slots are spaces on the left.
; ==============================================================================
hud_render_energy:
    ; 1. Lookup dynamic bar color from energy_color_table based on effective HP (0..5)
    ldy s_prev_hp
    cpy #6
    bcc +
    ldy #5                      ; Clamp to max 5
+   lda energy_color_table, y
    sta s_bar_color

    ; 2. Compute empty count = 10 - (s_prev_hp * 2) = 2 * (5 - s_prev_hp)
    lda #5
    sec
    sbc s_prev_hp
    asl
    sta s_empty_count           ; empty = 10 - (hp * 2)

    ldx #0
@energy_loop:
    lda #$20
    ldy #COLOR_BLACK
    cpx s_empty_count
    bcc +
    lda #106
    ldy s_bar_color
+   sta $0400, x
    tya
    sta $d800, x
    inx
    cpx #10
    bne @energy_loop
    rts

; ==============================================================================
; Subroutine: hud_convert_16bit_to_digits
; Purpose: Converts 16-bit integer in (s_score_val_lo, s_score_val_hi) into 5
;          decimal digits in s_score_digits (D4..D0), space-padding leading zeroes.
; ==============================================================================
hud_convert_16bit_to_digits:
    ldx #0                      ; Index into hud_pow10 tables (0..3)
@pow_loop:
    lda #0
    sta s_score_digits, x       ; Initialize digit count to 0

@sub_loop:
    ; Test if s_score_val >= pow10[x]
    lda s_score_val_lo
    sec
    sbc hud_pow10_lo, x
    tay                         ; Temp diff low in Y
    lda s_score_val_hi
    sbc hud_pow10_hi, x
    bcc @next_pow               ; Carry clear -> s_score_val < pow10[x]

    ; s_score_val >= pow10[x]: commit subtraction and increment digit count
    sta s_score_val_hi
    sty s_score_val_lo
    inc s_score_digits, x
    jmp @sub_loop

@next_pow:
    inx
    cpx #4
    bne @pow_loop

    ; Remainder in s_score_val_lo is digit 0 (ones place: 0..9)
    lda s_score_val_lo
    sta s_score_digits + 4

    ; Space-pad leading zeroes (D4 down to D1; D0 is never suppressed)
    ldx #0
@pad_loop:
    cpx #4                      ; Never suppress D0 (ones place)
    beq @done_padding
    lda s_score_digits, x
    bne @done_padding           ; Non-zero digit found: stop padding
    lda #$20                    ; Blank space
    sta s_score_digits, x
    inx
    jmp @pad_loop

@done_padding:
    ; Convert all remaining numerical digits (0..9) to screencode ($30..$39)
@convert_ascii_loop:
    cpx #5
    beq @done_conversion
    lda s_score_digits, x
    cmp #$20
    beq +                       ; If already a space, don't add $30
    clc
    adc #$30                    ; 0..9 -> '0'..'9' ($30..$39)
    sta s_score_digits, x
+   inx
    jmp @convert_ascii_loop

@done_conversion:
    rts

; ==============================================================================
; Subroutine: hud_render_score
; Purpose: Converts 16-bit g_score to 5 decimal digits, space-pads leading zeroes,
;          and writes to Cols 37..33 ($0425..$0421).
; ==============================================================================
hud_render_score:
    lda g_score + 0
    sta s_score_val_lo
    lda g_score + 1
    sta s_score_val_hi
    jsr hud_convert_16bit_to_digits

    ; Write digits to Screen RAM (Cols 37..33: $0425..$0421) and set Color to White
    ldx #0
    ldy #$25
-   lda s_score_digits, x
    sta $0400, y
    lda #COLOR_WHITE
    sta $d800, y
    dey
    inx
    cpx #5
    bne -
    rts

; ==============================================================================
; Subroutine: hud_render_hiscore
; Purpose: Converts 16-bit g_high_score to 5 decimal digits, space-pads leading zeroes,
;          and writes to Cols 23..19 ($0417..$0413).
; ==============================================================================
hud_render_hiscore:
    lda g_high_score + 0
    sta s_score_val_lo
    lda g_high_score + 1
    sta s_score_val_hi
    jsr hud_convert_16bit_to_digits

    ; Write digits to Screen RAM (Cols 23..19: $0417..$0413) and set Color to Light Blue
    ldx #0
    ldy #$17
-   lda s_score_digits, x
    sta $0400, y
    lda #COLOR_LIGHT_BLUE
    sta $d800, y
    dey
    inx
    cpx #5
    bne -
    rts

; ==============================================================================
; Subroutine: hud_add_score
; Purpose: Adds unsigned 8-bit points in Accumulator to 16-bit g_score.
;          Saturates at $FFFF (65,535 -> 6,553,500 displayed) to prevent overflow.
;          Dynamically updates g_high_score if player beats previous record!
; Arguments: A = points to add
; ==============================================================================
hud_add_score:
    clc
    adc g_score + 0
    sta g_score + 0
    bcc +
    inc g_score + 1
    bne +
    ; 16-bit saturation at $FFFF
    lda #$ff
    sta g_score + 0
    sta g_score + 1
+
    ; Dynamic High Score comparison: if g_score > g_high_score, update g_high_score
    lda g_score + 1
    cmp g_high_score + 1
    bcc @score_done
    bne @update_hi
    lda g_score + 0
    cmp g_high_score + 0
    bcc @score_done

@update_hi:
    lda g_score + 0
    sta g_high_score + 0
    lda g_score + 1
    sta g_high_score + 1

@score_done:
    rts

; ==============================================================================
; Subroutine: game_over_trigger
; Purpose: Activates Game Over state: hides all enemies, bullets, powerup,
;          missiles, stops sprites, and prints "GAME OVER" in the screen center.
; ==============================================================================
game_over_trigger:
    lda #1
    sta g_game_over

    ; 1. Despawn all active enemies and bullets
    jsr enemies_clear_all

    ; 2. Deactivate player missile, disable sprites & set black border
    lda #0
    sta g_missile_active
    sta VIC_SPR_ENABLE
    sta g_multiplexer_active
    sta VIC_RASTER
    sta VIC_BORDER_COLOR        ; COLOR_BLACK = 0

    ; 3. Erase any active grid powerup
    jsr powerups_erase

    ; 4. Clear HUD from Row 0
    jsr hud_clear

    ; 5. Ensure s_score_digits is fully refreshed with current score
    lda g_score + 0
    sta s_score_val_lo
    lda g_score + 1
    sta s_score_val_hi
    jsr hud_convert_16bit_to_digits

    ; 6. Print "GAME OVER" and "SCORE <score>" banners
    jmp hud_show_game_over

; ==============================================================================
; Subroutine: hud_show_game_over
; Purpose: Prints "GAME OVER" across Rows 8..16 at Column 20 in white.
;          2 lines below (Column 18), prints "SCORE <current_score>" in light gray.
; ==============================================================================
game_over_text:
    !byte 71, 65, 77, 69, 32, 79, 86, 69, 82 ; "GAME OVER" (ASCII codes)
score_label_text:
    !byte 83, 67, 79, 82, 69, 32             ; "SCORE " (ASCII codes)

hud_show_game_over:
    ; 1. Print "GAME OVER" at Column 20, Rows 8..16 in White
    lda #COLOR_WHITE
    sta s_char_color
    lda #8
    sta s_cur_row
    ldy #20
    ldx #0
-   lda game_over_text, x
    jsr hud_draw_char
    inx
    cpx #9
    bne -

    ; 2. Determine first non-space digit in s_score_digits (0..4)
    ldx #0
-   lda s_score_digits, x
    cmp #$20
    bne +
    inx
    cpx #4
    bne -
+
    ; 3. Center "SCORE <score>" across playfield rows: start_row = (13 + X) / 2
    txa
    clc
    adc #13
    lsr
    sta s_cur_row

    ; 4. Print "SCORE " at Column 18 in Light Gray
    txa
    pha                         ; Save first digit index on stack
    lda #COLOR_LIGHT_GRAY
    sta s_char_color
    ldy #18
    ldx #0
-   lda score_label_text, x
    jsr hud_draw_char
    inx
    cpx #6
    bne -

    ; 5. Print non-space score digits
    pla
    tax
-   lda s_score_digits, x
    jsr hud_draw_char
    inx
    cpx #5
    bne -

    ; 6. Print trailing bulk double zeroes "00"
    lda #$30
    jsr hud_draw_char
    lda #$30
    jmp hud_draw_char

; ==============================================================================
; Subroutine: hud_clear_game_over
; Purpose: Erases "GAME OVER" (Col 20) and "SCORE" (Col 18) lines from playfield.
; ==============================================================================
hud_clear_game_over:
    lda #COLOR_BLACK
    sta s_char_color

    ; Erase Column 20 (Rows 8..16: 9 characters)
    lda #8
    sta s_cur_row
    ldy #20
    ldx #9
-   lda #$20
    jsr hud_draw_char
    dex
    bne -

    ; Erase Column 18 (Rows 7..18: 12 characters)
    lda #7
    sta s_cur_row
    ldy #18
    ldx #12
-   lda #$20
    jsr hud_draw_char
    dex
    bne -
    rts

; ==============================================================================
; Subroutine: hud_draw_char
; Purpose: Draws character in A at (s_cur_row, Col Y) in s_char_color,
;          and increments s_cur_row. Preserves Y.
; ==============================================================================
hud_draw_char:
    pha
    txa
    pha
    ldx s_cur_row
    lda screen_row_table_lo, x
    sta $fb
    sta $fd                     ; screen_row_table_lo == color_row_table_lo
    lda screen_row_table_hi, x
    sta $fc
    lda color_row_table_hi, x
    sta $fe
    pla
    tax
    pla
    sta ($fb), y
    lda s_char_color
    sta ($fd), y
    inc s_cur_row
    rts
