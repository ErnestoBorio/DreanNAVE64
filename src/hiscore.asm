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

