; ==============================================================================
; HISCORE.ASM - Top 10 High Scores Table & C64 Directory Display Subsystem
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL, TATE Rotated Screen)
; Assembler: ACME 6502 Assembler
; ==============================================================================
; Features:
; - Persistent Top 10 High Scores table (scores & 3-letter initials)
; - Displays formatted as an authentic Commodore 64 Disk Directory:
;     Line 0 (Col 35): 0 "TOP 10 PILOTS"   NV 2A (Header in reverse video)
;     Lines 1..10 (Cols 33..24): Rank #1..#10, initials in quotes, scores right-aligned
;     Line 11 (Col 22): 64 BLOCKS FREE.
;     Line 12 (Col 20): READY.
;     Line 13 (Col 19): Solid block blinking cursor
; - Color scheme: Blue background (COLOR_BLUE = 6), Light Blue text & border (COLOR_LIGHT_BLUE = 14)
; - Zero-stack screen rendering (uses static variables to guarantee zero stack corruption)
; ==============================================================================

; ------------------------------------------------------------------------------
; Top 10 Table Persistent Data (10 entries)
; Stored as 16-bit values (displayed multiplied by 100 on screen)
; ------------------------------------------------------------------------------
top10_scores_lo:
    !byte <12, <11, <10, <7, <6, <5, <4, <3, <2, <1

top10_scores_hi:
    !byte >12, >11, >10, >7, >6, >5, >4, >3, >2, >1

top10_initials:
    !text "NAV" ; 1: 1,200 pts
    !text "HRS" ; 2: 1,100 pts
    !text "MXB" ; 3: 1,000 pts
    !text "CBM" ; 4:   700 pts
    !text "PTZ" ; 5:   600 pts
    !text "C64" ; 6:   500 pts
    !text "ASS" ; 7:   400 pts
    !text "DRN" ; 8:   300 pts
    !text "SEX" ; 9:   200 pts
    !text "ETC" ; 10:  100 pts

; ------------------------------------------------------------------------------
; Directory Screen Text Data
; ------------------------------------------------------------------------------
; Header line: All reverse from end to end (25 bytes across TATE Row 0..24):
; TOP 10 NAVE PILOTS     2A
; Reverse chars from custom charset:
; 108: Rev Space
; 181: Rev 'T', 176: Rev 'O', 177: Rev 'P', 146: Rev '1', 145: Rev '0'
; 175: Rev 'N', 162: Rev 'A', 183: Rev 'V', 166: Rev 'E'
; 177: Rev 'P', 170: Rev 'I', 173: Rev 'L', 176: Rev 'O', 181: Rev 'T', 180: Rev 'S'
; 147: Rev '2', 162: Rev 'A'
hiscore_header_text:
    !byte 181, 176, 177, 108, 146, 145, 108
    !byte 175, 162, 183, 166, 108
    !byte 177, 170, 173, 176, 181, 180
    !byte 108, 108, 108, 108, 108
    !byte 147, 162

text_blocks_free:
    !text "64 BLOCKS FREE." ; 15 characters

text_ready:
    !text "READY."          ; 6 characters

; ------------------------------------------------------------------------------
; Static Working Variables (Guarantees Zero Stack Usage)
; ------------------------------------------------------------------------------
s_hisc_idx:         !byte 0     ; Rank loop index (0..9)
s_hisc_col:         !byte 0     ; Current column on screen (0..39)
s_hisc_row:         !byte 0     ; Current character row on line (0..24)
s_hisc_char:        !byte 0     ; Temporary char byte
s_cursor_blink:     !byte 25    ; Cursor blink countdown (25 frames = 0.5s)
s_cursor_vis:       !byte 1     ; Cursor visibility flag (1 = visible, 0 = hidden)
s_str_len:          !byte 0     ; Length of string to draw

; ==============================================================================
; Subroutine: hiscore_init
; Purpose: Initializes high score from Top 10 rank 1 score.
; ==============================================================================
hiscore_init:
    lda top10_scores_lo + 0
    sta g_high_score + 0
    lda top10_scores_hi + 0
    sta g_high_score + 1
    rts

; ==============================================================================
; Subroutine: hiscore_draw_char
; Purpose: Writes character in A to (s_hisc_row, s_hisc_col) in Screen RAM.
;          Increments s_hisc_row. Preserves X and Y.
; ==============================================================================
hiscore_draw_char:
    sta s_hisc_char
    stx s_hiscore_saved_x
    sty s_hiscore_saved_y

    ldx s_hisc_row
    lda screen_row_table_lo, x
    sta $fb
    lda screen_row_table_hi, x
    sta $fc
    ldy s_hisc_col
    lda s_hisc_char
    sta ($fb), y

    inc s_hisc_row
    ldx s_hiscore_saved_x
    ldy s_hiscore_saved_y
    rts

s_hiscore_saved_x: !byte 0
s_hiscore_saved_y: !byte 0

; ==============================================================================
; Subroutine: hiscore_screen_show
; Purpose: Configures VIC-II for C64 Directory screen (Bank 0, Text mode, Blue bg,
;          Light Blue border & text) and draws full directory listing.
; ==============================================================================
hiscore_screen_show:
    ; 1. Ensure CIA2 Port A bits 0-1 are outputs, then switch to Bank 0 (%11)
    lda CIA2_DIR_A
    ora #$03
    sta CIA2_DIR_A
    lda CIA2_DATA_A
    ora #$03
    sta CIA2_DATA_A

    ; 2. Ensure I/O registers mapped at $D000 ($0001 = $36)
    lda #$36
    sta $0001

    ; 3. Setup VIC-II Text Mode: Screen at $0400, Charset at $2800
    ; $D018: Screen = %0001 ($0400), Charset = %1010 ($2800) -> $1A
    lda #$1a
    sta VIC_MEM_SETUP

    ; VIC_CTRL1: BMM = 0 (Text mode), 25 rows, display enable -> $1B
    lda #$1b
    sta VIC_CTRL1

    ; VIC_CTRL2: 40 columns, MCM = 0 -> $C8
    lda #$c8
    sta VIC_CTRL2

    ; 4. Colors: Light Blue border & text, Blue background
    lda #COLOR_LIGHT_BLUE
    sta VIC_BORDER_COLOR
    lda #COLOR_BLUE
    sta VIC_BG_COLOR0

    ; 5. Fast clear Screen RAM ($0400..$07E7) with blank spaces ($20)
    lda #$20
    ldx #0
-   sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $06e8, x
    inx
    bne -

    ; 6. Fast clear Color RAM ($D800..$DBE7) with COLOR_LIGHT_BLUE
    lda #COLOR_LIGHT_BLUE
    ldx #0
-   sta $d800, x
    sta $d900, x
    sta $da00, x
    sta $dae8, x
    inx
    bne -

    ; --------------------------------------------------------------------------
    ; Draw Header Line: 0 TOP 10 PILOTS     NV 2A at Col 35
    ; --------------------------------------------------------------------------
    lda #35
    sta s_hisc_col
    lda #0
    sta s_hisc_row
    ldx #0
@draw_header_loop:
    lda hiscore_header_text, x
    jsr hiscore_draw_char
    inx
    cpx #25
    bne @draw_header_loop

    ; --------------------------------------------------------------------------
    ; Draw 10 Rank Entries: Cols 34 down to 25 (immediately below Header at Col 35)
    ; Format: 1    NAV            1200
    ; --------------------------------------------------------------------------
    lda #0
    sta s_hisc_idx

@rank_loop:
    ; Calculate column: Col = 34 - s_hisc_idx
    lda #34
    sec
    sbc s_hisc_idx
    sta s_hisc_col
    lda #0
    sta s_hisc_row

    ; 1. Draw rank number (Row 0..4, left-aligned)
    lda s_hisc_idx
    cmp #9
    beq @rank_10

    ; Ranks 1..9: '1' + idx at Row 0, then 4 spaces (Rows 1..4)
    clc
    adc #49                     ; '1' = 49
    jsr hiscore_draw_char

    ldx #4
-   lda #$20
    jsr hiscore_draw_char
    dex
    bne -
    jmp @rank_num_done

@rank_10:
    ; Rank 10: '1' at Row 0, '0' at Row 1, then 3 spaces (Rows 2..4)
    lda #49                     ; '1'
    jsr hiscore_draw_char
    lda #48                     ; '0'
    jsr hiscore_draw_char

    ldx #3
-   lda #$20
    jsr hiscore_draw_char
    dex
    bne -

@rank_num_done:

    ; 3. Draw 3 initials (Row 5..7, no quotes)
    lda s_hisc_idx
    asl                         ; * 2
    clc
    adc s_hisc_idx              ; * 3
    tax
    lda top10_initials + 0, x
    jsr hiscore_draw_char
    lda top10_initials + 1, x
    jsr hiscore_draw_char
    lda top10_initials + 2, x
    jsr hiscore_draw_char

    ; 4. Draw 10 spaces (Row 8..17)
    ldx #10
-   lda #$20
    jsr hiscore_draw_char
    dex
    bne -

    ; 5. Convert score to 5 decimal digits
    ldx s_hisc_idx
    lda top10_scores_lo, x
    sta s_score_val_lo
    lda top10_scores_hi, x
    sta s_score_val_hi
    jsr hud_convert_16bit_to_digits

    ; 6. Draw 6 score characters (Row 18..23): D1, D2, D3, D4, '0', '0'
    lda s_score_digits + 1      ; D1 (ten-thousands if >= 100,000)
    jsr hiscore_draw_char
    lda s_score_digits + 2      ; D2
    jsr hiscore_draw_char
    lda s_score_digits + 3      ; D3
    jsr hiscore_draw_char
    lda s_score_digits + 4      ; D4
    jsr hiscore_draw_char
    lda #48                     ; '0'
    jsr hiscore_draw_char
    lda #48                     ; '0'
    jsr hiscore_draw_char

    ; 7. Draw trailing space (Row 24)
    lda #$20
    jsr hiscore_draw_char

    ; Advance rank index
    inc s_hisc_idx
    lda s_hisc_idx
    cmp #10
    beq @all_ranks_done
    jmp @rank_loop

@all_ranks_done:
    ; --------------------------------------------------------------------------
    ; Draw "64 BLOCKS FREE." at Col 24 (immediately below Rank 10 at Col 25)
    ; --------------------------------------------------------------------------
    lda #24
    sta s_hisc_col
    lda #0
    sta s_hisc_row
    ldx #0
-   lda text_blocks_free, x
    jsr hiscore_draw_char
    inx
    cpx #15
    bne -

    ; --------------------------------------------------------------------------
    ; Draw "READY." at Col 23 (immediately below BLOCKS FREE)
    ; --------------------------------------------------------------------------
    lda #23
    sta s_hisc_col
    lda #0
    sta s_hisc_row
    ldx #0
-   lda text_ready, x
    jsr hiscore_draw_char
    inx
    cpx #6
    bne -

    ; --------------------------------------------------------------------------
    ; Draw Cursor Block at Col 22, Row 0 (immediately below READY.)
    ; --------------------------------------------------------------------------
    lda #22
    sta s_hisc_col
    lda #0
    sta s_hisc_row
    lda #108                    ; Solid cursor block
    jsr hiscore_draw_char

    ; Initialize cursor blink timer
    lda #25
    sta s_cursor_blink
    lda #1
    sta s_cursor_vis
    rts

; ==============================================================================
; Subroutine: hiscore_screen_update
; Purpose: Blinks the solid block cursor at Col 22, Row 0 every 25 frames.
; ==============================================================================
hiscore_screen_update:
    dec s_cursor_blink
    bne @done

    lda #25
    sta s_cursor_blink

    lda #0
    sta s_hisc_row
    lda #22
    sta s_hisc_col

    lda s_cursor_vis
    eor #$01
    sta s_cursor_vis
    beq @hide_cursor

    ; Show solid cursor block (char 108)
    lda #108
    bne @do_draw

@hide_cursor:
    ; Hide cursor (write blank space $20)
    lda #$20

@do_draw:
    jsr hiscore_draw_char

@done:
    rts

; ==============================================================================
; Top 10 Initials Entry & High Score Subsystem
; ==============================================================================

type_your_name_text:
    !byte 84, 89, 80, 69, 32, 89, 79, 85, 82, 32, 78, 65, 77, 69 ; "TYPE YOUR NAME"

col_scan_table:
    !byte $fe, $fd, $fb, $f7, $ef, $df, $bf, $7f

; 64-Byte Keyboard Matrix Mapping: Unshifted
hiscore_matrix_unshifted:
    ; Col 0 ($FE): DEL, RETURN, CRSR L/R, F7, F1, F3, F5, CRSR U/D
    !byte $08, $0d,   0,   0,   0,   0,   0,   0
    ; Col 1 ($FD): '3', 'W', 'A', '4', 'Z', 'S', 'E', L-Shift
    !byte  51,  87,  65,  52,  90,  83,  69,   0
    ; Col 2 ($FB): '5', 'R', 'D', '6', 'C', 'F', 'T', 'X'
    !byte  53,  82,  68,  54,  67,  70,  84,  88
    ; Col 3 ($F7): '7', 'Y', 'G', '8', 'B', 'H', 'U', 'V'
    !byte  55,  89,  71,  56,  66,  72,  85,  86
    ; Col 4 ($EF): '9', 'I', 'J', '0', 'M', 'K', 'O', 'N'
    !byte  57,  73,  74,  48,  77,  75,  79,  78
    ; Col 5 ($DF): '+', 'P', 'L', '-', '.', ':', '@', ','
    !byte   0,  80,  76,   0,   0,   0,  64,   0
    ; Col 6 ($BF): '£', '*', ';', HOME, R-Shift, '=', '↑' (nave), '/'
    !byte   0,  42,   0,   0,   0,   0,  92,   0
    ; Col 7 ($7F): '1', '←' (heart), CTRL, '2', SPACE, C=, 'Q', RUN/STOP
    !byte  49,  98,   0,  50,  32,   0,  81,   0

; 64-Byte Keyboard Matrix Mapping: Shifted
hiscore_matrix_shifted:
    ; Col 0 ($FE)
    !byte $08, $0d,   0,   0,   0,   0,   0,   0
    ; Col 1 ($FD): Shift+3 = '#'(35), W, A, Shift+4 = '$'(36), Z, S, E, L-Shift
    !byte  35,  87,  65,  36,  90,  83,  69,   0
    ; Col 2 ($FB): Shift+5 = '%'(37), R, D, Shift+6 = '&'(38), C, F, T, X
    !byte  37,  82,  68,  38,  67,  70,  84,  88
    ; Col 3 ($F7): Shift+7 = '\''(39), Y, G, Shift+8 = '('(40), B, H, U, V
    !byte  39,  89,  71,  40,  66,  72,  85,  86
    ; Col 4 ($EF): Shift+9 = ')'(41), I, J, '0', M, K, O, N
    !byte  41,  73,  74,  48,  77,  75,  79,  78
    ; Col 5 ($DF): '+', 'P', 'L', '-', '.', ':', '@'(64), ','
    !byte   0,  80,  76,   0,   0,   0,  64,   0
    ; Col 6 ($BF): '£', '*'(42), ';', HOME, R-Shift, '=', '↑'(92), '/'
    !byte   0,  42,   0,   0,   0,   0,  92,   0
    ; Col 7 ($7F): Shift+1 = '!'(33), '←'(98), CTRL, Shift+2 = '"'(34), SPACE, C=, 'Q', RUN/STOP
    !byte  33,  98,   0,  34,  32,   0,  81,   0

; Initials Entry RAM Variables
s_initials_buf:         !byte 95, 95, 95    ; 3 characters ('_' = 95)
s_initials_pos:         !byte 0             ; 0..3 (current input slot)
s_entry_blink:          !byte 25            ; Cursor blink timer
s_entry_cursor_vis:     !byte 1             ; 1 = cursor visible (108), 0 = '_' (95)
s_last_matrix_code:     !byte $ff           ; Debounce edge-trigger code ($FF = no key)
s_key_is_shifted:       !byte 0             ; 1 = Shift active, 0 = unshifted
s_insert_rank:          !byte 0             ; Target insertion index (0..9)
s_shift_y_save:         !byte 0             ; Loop math scratch
s_scan_temp_row:        !byte 0             ; Row scan scratch
s_entry_timeout_lo:     !byte <500          ; Inactivity countdown (500 frames = 10.0s)
s_entry_timeout_hi:     !byte >500

; ==============================================================================
; Subroutine: hiscore_check_qualify
; Purpose: Checks if g_score is high enough to enter Top 10 high score table.
; Returns: Carry = 1 if qualified (score > 0 and >= top10_scores[9]), Carry = 0 if not.
; ==============================================================================
hiscore_check_qualify:
    ; Score of 0 never qualifies
    lda g_score + 0
    ora g_score + 1
    beq @not_qualified

    lda g_score + 1
    cmp top10_scores_hi + 9
    bcc @not_qualified
    bne @qualified
    lda g_score + 0
    cmp top10_scores_lo + 9
    bcc @not_qualified

@qualified:
    sec
    rts

@not_qualified:
    clc
    rts

; ==============================================================================
; Subroutine: hiscore_entry_init
; Purpose: Sets up initials entry on Game Over screen: prints "TYPE YOUR NAME"
;          in White, 3 underscores in Cyan, and arms cursor blink timer.
; ==============================================================================
hiscore_entry_init:
    ; 1. Reset entry state
    lda #0
    sta s_initials_pos
    lda #25
    sta s_entry_blink
    lda #1
    sta s_entry_cursor_vis
    lda #$ff
    sta s_last_matrix_code
    lda #<500
    sta s_entry_timeout_lo
    lda #>500
    sta s_entry_timeout_hi

    lda #95                     ; '_'
    sta s_initials_buf + 0
    sta s_initials_buf + 1
    sta s_initials_buf + 2

    ; 2. Print "TYPE YOUR NAME" at Column 16, Rows 5..18 in White
    lda #COLOR_WHITE
    sta s_char_color
    lda #5
    sta s_cur_row
    ldy #16
    ldx #0
-   lda type_your_name_text, x
    jsr hud_draw_char
    inx
    cpx #14
    bne -

    ; 3. Render 3 slots at Column 14 (Rows 11..13)
    jsr hiscore_render_initials_slots
    rts

; ==============================================================================
; Subroutine: hiscore_render_slot
; Purpose: Draws character in A at slot X (0..2 -> Rows 11..13, Col 14) in Cyan.
; ==============================================================================
hiscore_render_slot:
    pha
    txa
    clc
    adc #11
    tay                         ; Y = row (11..13)
    lda screen_row_table_lo, y
    sta $fb
    sta $fd
    lda screen_row_table_hi, y
    sta $fc
    lda color_row_table_hi, y
    sta $fe
    pla
    ldy #14                     ; Column 14
    sta ($fb), y
    lda #COLOR_CYAN
    sta ($fd), y
    rts

; ==============================================================================
; Subroutine: hiscore_render_initials_slots
; Purpose: Redraws all 3 slots based on s_initials_buf, s_initials_pos, and cursor.
; ==============================================================================
hiscore_render_initials_slots:
    ldx #0
@slot_loop:
    cpx s_initials_pos
    bne @draw_buf_char
    ; This is the active cursor slot (if s_initials_pos < 3)
    cpx #3
    beq @draw_buf_char
    lda s_entry_cursor_vis
    beq @draw_buf_char          ; Blink off phase: show underscore
    lda #108                    ; Solid cursor block
    bne @do_render

@draw_buf_char:
    lda s_initials_buf, x

@do_render:
    jsr hiscore_render_slot
    inx
    cpx #3
    bne @slot_loop
    rts

; ==============================================================================
; Subroutine: hiscore_scan_key
; Purpose: Scans CIA1 keyboard matrix with edge detection and Shift handling.
; Returns: A = key character/code (0 = none, $0D = RETURN, $08 = DEL, 32..98 = char)
; ==============================================================================
hiscore_scan_key:
    ; Configure Port A as outputs, Port B as inputs
    lda #$ff
    sta CIA1_DIR_A
    lda #$00
    sta CIA1_DIR_B

    ; 1. Check Shift state (Left Shift: Col 1 PB7; Right Shift: Col 6 PB4)
    lda #$fd                    ; Column 1
    sta CIA1_DATA_A
    lda CIA1_DATA_B
    bpl @shift_active           ; Bit 7 = 0 -> Left Shift down

    lda #$bf                    ; Column 6
    sta CIA1_DATA_A
    lda CIA1_DATA_B
    and #$10                    ; Bit 4 = 0 -> Right Shift down
    beq @shift_active
    lda #0
    sta s_key_is_shifted
    jmp @scan_columns

@shift_active:
    lda #1
    sta s_key_is_shifted

@scan_columns:
    ldx #0
@col_loop:
    lda col_scan_table, x
    sta CIA1_DATA_A
    lda CIA1_DATA_B
    ; Mask out Shift bits so holding Shift doesn't block character keys
    cpx #1                      ; Col 1?
    bne +
    ora #$80                    ; Mask out PB7 (Left Shift)
+   cpx #6                      ; Col 6?
    bne +
    ora #$10                    ; Mask out PB4 (Right Shift)
+   cmp #$ff
    bne @found_key_in_col
    inx
    cpx #8
    bne @col_loop

    ; No keyboard key pressed!
    ; Check Joystick Port 2 Fire button
    lda #$00
    sta CIA1_DIR_A              ; Port A = inputs
    lda CIA1_DATA_A             ; Read Joystick 2
    and #$10                    ; Bit 4 = Fire (0 = pressed)
    beq @joy_fire_detected

    ; No key and no joystick fire: reset edge-trigger latch
    lda #$ff
    sta s_last_matrix_code
    lda #0
    rts

@joy_fire_detected:
    lda s_last_matrix_code
    cmp #$fe                    ; Code $FE for Joystick Fire
    beq @no_new_key
    lda #$fe
    sta s_last_matrix_code
    lda #$0d                    ; Treat Joystick Fire as RETURN ($0D)
    rts

@no_new_key:
    lda #0
    rts

@found_key_in_col:
    ; Find which bit (0..7) is 0
    ldy #0
-   lsr
    bcc @got_row
    iny
    cpy #8
    bne -
    lda #0
    rts

@got_row:
    sty s_scan_temp_row
    ; Matrix index = X * 8 + Y (0..63)
    txa
    asl
    asl
    asl
    clc
    adc s_scan_temp_row

    ; Edge detection: ignore if identical to previous frame
    cmp s_last_matrix_code
    beq @no_new_key
    sta s_last_matrix_code

    ; Translate matrix index to character
    tay
    lda s_key_is_shifted
    bne +
    lda hiscore_matrix_unshifted, y
    rts
+   lda hiscore_matrix_shifted, y
    rts

; ==============================================================================
; Subroutine: hiscore_entry_update
; Purpose: Frame update for initials entry during STATE_GAME_OVER.
; ==============================================================================
hiscore_entry_update:
    ; 1. Inactivity timeout (500 frames = 10.0s @ 50 Hz PAL)
    lda s_entry_timeout_lo
    bne +
    dec s_entry_timeout_hi
+   dec s_entry_timeout_lo
    lda s_entry_timeout_lo
    ora s_entry_timeout_hi
    beq @commit_entry           ; 10s of inactivity: record current name and go to Top 10 screen

    ; 2. Blink cursor (25 frames on, 25 frames off)
    dec s_entry_blink
    bne @check_keys
    lda #25
    sta s_entry_blink
    lda s_entry_cursor_vis
    eor #$01
    sta s_entry_cursor_vis
    jsr hiscore_render_initials_slots

@check_keys:
    ; 3. Scan for keypress
    jsr hiscore_scan_key
    tax                         ; X = key code
    bne +
    rts                         ; No key pressed

+   ; Key pressed! Reset 10-second inactivity countdown
    lda #<500
    sta s_entry_timeout_lo
    lda #>500
    sta s_entry_timeout_hi

    ; Check for RETURN ($0D)
    cpx #$0d
    beq @commit_entry

    ; Check for INST DEL ($08)
    cpx #$08
    beq @handle_del

    ; It's a character! Check if we can enter it (s_initials_pos < 3)
    lda s_initials_pos
    cmp #3
    bcc +
    rts                         ; Buffer full, ignore

+   ; Store character into buffer
    ldy s_initials_pos
    txa
    sta s_initials_buf, y
    inc s_initials_pos

    ; Reset cursor blink to visible for new position
    lda #25
    sta s_entry_blink
    lda #1
    sta s_entry_cursor_vis
    jsr hiscore_render_initials_slots

    ; Play typewriter click sound
    lda #SFX_KEY_CLICK
    jsr sound_play_sfx
    rts

@handle_del:
    ; [INST DEL]: back up one position and replace with '_'
    lda s_initials_pos
    beq @done                   ; At 0: nothing to delete

    dec s_initials_pos
    ldy s_initials_pos
    lda #95                     ; '_'
    sta s_initials_buf, y

    lda #25
    sta s_entry_blink
    lda #1
    sta s_entry_cursor_vis
    jsr hiscore_render_initials_slots

    ; Play typewriter click sound
    lda #SFX_KEY_CLICK
    jsr sound_play_sfx
    rts

@commit_entry:
    ; Return or Fire pressed!
    ; Pad any remaining '_' with space ($20)
    ldx #0
-   lda s_initials_buf, x
    cmp #95
    bne +
    lda #$20
    sta s_initials_buf, x
+   inx
    cpx #3
    bne -

    ; Insert score into Top 10 table
    jsr hiscore_insert_score

    ; Play bonus chime for submitting score
    lda #SFX_BONUS
    jsr sound_play_sfx

    ; Erase game over screen elements
    jsr hud_clear_game_over

    ; Set flag to start attract mode directly on Top 10 Directory screen
    lda #1
    sta g_title_show_hiscore_first

    ; Transition to STATE_TITLE
    lda #STATE_TITLE
    jsr change_state

@done:
    rts

; ==============================================================================
; Subroutine: hiscore_insert_score
; Purpose: Inserts g_score and s_initials_buf into Top 10 table, shifts lower
;          entries down, and updates g_high_score.
; ==============================================================================
hiscore_insert_score:
    ; 1. Find target insertion rank (0..9)
    ldx #0
@find_rank_loop:
    lda g_score + 1
    cmp top10_scores_hi, x
    bcc @next_rank
    bne @found_rank
    lda g_score + 0
    cmp top10_scores_lo, x
    bcc @next_rank
    jmp @found_rank

@next_rank:
    inx
    cpx #10
    bne @find_rank_loop
    rts                         ; Did not qualify (safeguard)

@found_rank:
    stx s_insert_rank           ; Target rank 0..9

    ; 2. Shift lower ranks down from 8 down to s_insert_rank
    ldy #8
@shift_loop:
    cpy s_insert_rank
    bcc @do_insert

    ; Shift scores: top10_scores[Y+1] = top10_scores[Y]
    lda top10_scores_lo, y
    sta top10_scores_lo + 1, y
    lda top10_scores_hi, y
    sta top10_scores_hi + 1, y

    ; Shift initials: 3 bytes at Y * 3 -> (Y+1) * 3
    sty s_shift_y_save
    tya
    asl                         ; * 2
    clc
    adc s_shift_y_save          ; * 3
    tax                         ; X = Y * 3
    lda top10_initials + 0, x
    sta top10_initials + 3, x
    lda top10_initials + 1, x
    sta top10_initials + 4, x
    lda top10_initials + 2, x
    sta top10_initials + 5, x

    ldy s_shift_y_save
    dey
    bpl @shift_loop

@do_insert:
    ; 3. Insert new score at s_insert_rank
    ldx s_insert_rank
    lda g_score + 0
    sta top10_scores_lo, x
    lda g_score + 1
    sta top10_scores_hi, x

    ; Insert initials: dest = s_insert_rank * 3
    txa
    asl
    clc
    adc s_insert_rank
    tax
    lda s_initials_buf + 0
    sta top10_initials + 0, x
    lda s_initials_buf + 1
    sta top10_initials + 1, x
    lda s_initials_buf + 2
    sta top10_initials + 2, x

    ; 4. Update g_high_score to rank 1 score
    lda top10_scores_lo + 0
    sta g_high_score + 0
    lda top10_scores_hi + 0
    sta g_high_score + 1
    rts


