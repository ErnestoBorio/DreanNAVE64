; ==============================================================================
; HUD.ASM - Heads-Up Display Subsystem (Phase 8: TATE Mode & Scoring)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
;
; Manages:
; - TATE Mode Rotated Status Bar on Character Row 0 ($0400-$0427, Color $D800-$D827)
; - Screen Right (Col 39) = Rotated TOP, Screen Left (Col 0) = Rotated BOTTOM
; - 1UP Indicator: Digit 1 (Char 49) + 'UP' (Char 107) in Light Blue (Cols 39..38)
; - 16-bit Score: Converted to 5 decimal digits with leading spaces + '00' bulk zeroes (Cols 37..31) in White
; - Red Heart (Char 98) in Red at Col 10
; - 10-bar Energy Gauge (Char 106) in Yellow (Cols 9..0), decreasing from left to right (2 bars per HP)
; - Saturated 16-bit score addition with enemy rank and powerup bonus points
; ==============================================================================

; ------------------------------------------------------------------------------
; HUD RAM Variables
; ------------------------------------------------------------------------------
g_score:            !word 0     ; 16-bit score integer (0..65535, displayed * 100)
s_score_val_lo:     !byte 0     ; Temporary binary-to-decimal working value low byte
s_score_val_hi:     !byte 0     ; Temporary binary-to-decimal working value high byte
s_score_digits:     !fill 5, 0  ; 5 decimal digits buffer (D4..D0)
s_bars_count:       !byte 0     ; Active energy bars count (0..10)
s_empty_count:      !byte 0     ; Depleted energy bars count (0..10)
s_bar_color:        !byte 0     ; Dynamic color for active energy bars
s_prev_hp:          !byte $ff   ; Cached player effective HP for dirty check
s_prev_score:       !word $ffff ; Cached score for dirty check

; Energy bar color table by HP remaining (0..5):
; 5, 4 HP -> Light Green; 3 HP -> Yellow; 2, 1, 0 HP -> Red
energy_color_table:
    !byte COLOR_RED, COLOR_RED, COLOR_RED, COLOR_YELLOW, COLOR_LIGHT_GREEN, COLOR_LIGHT_GREEN

; Power-of-10 table for 16-bit binary-to-decimal conversion (10000, 1000, 100, 10)
hud_pow10_hi:       !byte >10000, >1000, >100, >10
hud_pow10_lo:       !byte <10000, <1000, <100, <10

; ==============================================================================
; Subroutine: hud_init
; Purpose: Resets score, invalidates cached dirty flags, clears Row 0, and
;          draws initial static elements (1UP, Heart, full Energy bars, 000).
; ==============================================================================
hud_init:
    lda #0
    sta g_score + 0
    sta g_score + 1
    lda #$ff
    sta s_prev_hp
    sta s_prev_score + 0
    sta s_prev_score + 1

    ; Clear Row 0 ($0400..$0427) with blank spaces ($20)
    ldx #39
-   lda #$20
    sta $0400, x
    lda #COLOR_WHITE
    sta $d800, x
    dex
    bpl -

    ; Draw '1UP' at Cols 39 and 38 (Rotated Top of screen)
    ; Col 39 = '1' (Char 49) in Light Blue
    lda #49
    sta $0427
    lda #COLOR_LIGHT_BLUE
    sta $d827

    ; Col 38 = 'UP' (Char 107) in Light Blue
    lda #107
    sta $0426
    lda #COLOR_LIGHT_BLUE
    sta $d826

    ; Draw Red Heart at Col 10 (Char 98) in Red
    lda #98
    sta $040a
    lda #COLOR_RED
    sta $d80a

    ; Initial render of score and energy
    jsr hud_render_energy
    jsr hud_render_score
    rts

; ==============================================================================
; Subroutine: hud_update
; Purpose: Checks if player effective HP or score changed, and triggers redraw.
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
    ; 2. When energy is at 1 or 2 HP, flash the active energy bars and heart signaling death is near!
    lda s_prev_hp
    beq @restore_heart          ; 0 HP -> do not flash
    cmp #3
    bcs @restore_heart          ; >= 3 HP -> do not flash
    lda g_player_alive
    beq @restore_heart

    ; Flash every 8 frames (~3.1 Hz heartbeat rate) between COLOR_RED and COLOR_WHITE
    lda g_game_time_frames
    and #$08
    beq +
    lda #COLOR_WHITE
    bne ++
+   lda #COLOR_RED
++  sta $d80a                   ; Heart color (Col 10)
    ldx s_empty_count           ; Active energy bars: s_empty_count up to slot 9
-   sta $d800, x
    inx
    cpx #10
    bne -
    jmp @check_score

@restore_heart:
    lda #COLOR_RED
    sta $d80a                   ; Ensure heart is solid red when not flashing

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
; Subroutine: hud_render
; Purpose: Reserved frame hook for hud rendering / animations.
; ==============================================================================
hud_render:
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

    ; 2. Compute empty count = 10 - (s_prev_hp * 2)
    lda s_prev_hp
    asl                         ; 0..5 -> 0..10
    sta s_bars_count
    lda #10
    sec
    sbc s_bars_count
    sta s_empty_count           ; empty = 10 - (hp * 2)

    ldx #0
@energy_loop:
    cpx s_empty_count
    bcs @draw_bar

    ; Depleted slot: draw blank space ($20) in black
    lda #$20
    sta $0400, x
    lda #COLOR_BLACK
    sta $d800, x
    jmp @next_slot

@draw_bar:
    ; Active energy slot: draw Char 106 in dynamic HP color
    lda #106
    sta $0400, x
    lda s_bar_color
    sta $d800, x

@next_slot:
    inx
    cpx #10
    bne @energy_loop
    rts

; ==============================================================================
; Subroutine: hud_render_score
; Purpose: Converts 16-bit g_score to 5 decimal digits, space-pads leading zeroes,
;          writes to Cols 37..33, and appends '00' bulk zeroes to Cols 32..31.
; ==============================================================================
hud_render_score:
    ; 1. Copy 16-bit score to working registers
    lda g_score + 0
    sta s_score_val_lo
    lda g_score + 1
    sta s_score_val_hi

    ; 2. Convert 16-bit value to 5 decimal digits (D4..D0)
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

    ; 3. Space-pad leading zeroes (D4 down to D1; D0 is never suppressed)
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
    beq @write_screen
    lda s_score_digits, x
    cmp #$20
    beq +                       ; If already a space, don't add $30
    clc
    adc #$30                    ; 0..9 -> '0'..'9' ($30..$39)
    sta s_score_digits, x
+   inx
    jmp @convert_ascii_loop

@write_screen:
    ; 4. Write digits to Screen RAM (Cols 37..33) and Color RAM in COLOR_WHITE
    ; Col 37 = D4 (Ten-thousands) = $0425
    ; Col 36 = D3 (Thousands)     = $0424
    ; Col 35 = D2 (Hundreds)      = $0423
    ; Col 34 = D1 (Tens)          = $0422
    ; Col 33 = D0 (Ones)          = $0421
    lda s_score_digits + 0
    sta $0425
    lda s_score_digits + 1
    sta $0424
    lda s_score_digits + 2
    sta $0423
    lda s_score_digits + 3
    sta $0422
    lda s_score_digits + 4
    sta $0421

    ; Cols 32 and 31: Bulk double zeroes '00' (Char 48 = $30)
    lda #$30
    sta $0420
    sta $041f

    ; Set Color RAM for Cols 37..31 to COLOR_WHITE
    lda #COLOR_WHITE
    sta $d825
    sta $d824
    sta $d823
    sta $d822
    sta $d821
    sta $d820
    sta $d81f
    rts

; ==============================================================================
; Subroutine: hud_add_score
; Purpose: Adds unsigned 8-bit points in Accumulator to 16-bit g_score.
;          Saturates at $FFFF (65,535 -> 6,553,500 displayed) to prevent overflow.
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
+   rts
