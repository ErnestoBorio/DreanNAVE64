; ==============================================================================
; HISCORE.ASM - Top 10 High Scores & Name Entry Subsystem
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL, TATE Rotated Screen)
; Assembler: ACME 6502 Assembler
; ==============================================================================
; Manages:
; - Persistent Top 10 High Score Table (10 entries: 3 initials + 16-bit score)
; - Top 10 Hall of Fame Text Display in rotated TATE orientation (Cols 39..0, Rows 0..24)
; - Attract Mode blinking "PRESS FIRE TO START"
; - Dedicated Full-Keyboard Matrix Scanner (Single-stroke edge-triggered debounce)
; - STATE_NAME_ENTRY: 3-initials keyboard entry after Game Over
; - Top 10 Insertion and Rank Shifting
; ==============================================================================

NUM_TOP_SCORES = 10

; ------------------------------------------------------------------------------
; Top 10 RAM Data Storage
; ------------------------------------------------------------------------------
top10_initials:
    !text "NDO"                 ; Rank 1:  50,000 pts (Videogamo creator)
    !text "ERN"                 ; Rank 2:  40,000 pts (DreanNAVE64 creator)
    !text "PET"                 ; Rank 3:  30,000 pts (Petruza)
    !text "VID"                 ; Rank 4:  25,000 pts
    !text "GAM"                 ; Rank 5:  20,000 pts
    !text "DRN"                 ; Rank 6:  15,000 pts
    !text "C64"                 ; Rank 7:  10,000 pts
    !text "NAV"                 ; Rank 8:   8,000 pts
    !text "ACE"                 ; Rank 9:   5,000 pts
    !text "BOB"                 ; Rank 10:  2,000 pts

top10_scores_lo:
    !byte <500, <400, <300, <250, <200, <150, <100, <80, <50, <20
top10_scores_hi:
    !byte >500, >400, >300, >250, >200, >150, >100, >80, >50, >20

; ------------------------------------------------------------------------------
; High Score Subsystem RAM Variables
; ------------------------------------------------------------------------------
s_qualify_rank:         !byte $ff   ; Achieved rank (0..9) for qualifying score ($FF = none)
s_highlight_rank:       !byte $ff   ; Rank index to highlight on Top 10 screen ($FF = none)
s_entry_initials:       !byte $20, $20, $20 ; Player's typed initials buffer
s_entry_cursor:         !byte 0     ; Current character position (0..2)
s_entry_blink_timer:    !byte 0     ; Cursor blink timer
s_kbd_prev_char:        !byte 0     ; Previously held key ASCII for edge-detection
s_top10_prompt_visible: !byte 1     ; Blinking prompt visible flag for Top 10 screen
s_hiscore_draw_row:     !byte 0     ; Row cursor for score formatting

; ------------------------------------------------------------------------------
; CIA1 Keyboard Matrix Scan Table (64 bytes: 8 Columns x 8 Rows)
; ------------------------------------------------------------------------------
kbd_col_masks:
    !byte $fe, $fd, $fb, $f7, $ef, $df, $bf, $7f

kbd_matrix_ascii:
    ; Col 0 ($FE): DEL ($08), RETURN ($0D), CRSR_RIGHT, F7, F1, F3, F5, CRSR_DOWN
    !byte $08, $0d, 0, 0, 0, 0, 0, 0
    ; Col 1 ($FD): '3', 'W', 'A', '4', 'Z', 'S', 'E', Left-Shift
    !byte '3', 'W', 'A', '4', 'Z', 'S', 'E', 0
    ; Col 2 ($FB): '5', 'R', 'D', '6', 'C', 'F', 'T', 'X'
    !byte '5', 'R', 'D', '6', 'C', 'F', 'T', 'X'
    ; Col 3 ($F7): '7', 'Y', 'G', '8', 'B', 'H', 'U', 'V'
    !byte '7', 'Y', 'G', '8', 'B', 'H', 'U', 'V'
    ; Col 4 ($EF): '9', 'I', 'J', '0', 'M', 'K', 'O', 'N'
    !byte '9', 'I', 'J', '0', 'M', 'K', 'O', 'N'
    ; Col 5 ($DF): '+', 'P', 'L', '-', '.', ':', '@', ','
    !byte '+', 'P', 'L', '-', '.', ':', 0, 0
    ; Col 6 ($BF): Pound, '*', ';', HOME, Right-Shift, '=', '^', '/'
    !byte 0, 0, 0, 0, 0, 0, 0, 0
    ; Col 7 ($7F): '1', Left-Arrow, CTRL, '2', SPACE ($20), CBM, 'Q', RUN/STOP
    !byte '1', 0, 0, '2', $20, 0, 'Q', 0

; Rank colors: Rank 1 (Yellow), Rank 2 (White), Rank 3 (Light Red), 4..10 (Light Blue/Cyan)
top10_rank_colors:
    !byte COLOR_YELLOW, COLOR_WHITE, COLOR_LIGHT_RED, COLOR_CYAN
    !byte COLOR_LIGHT_BLUE, COLOR_GREEN, COLOR_CYAN, COLOR_LIGHT_BLUE
    !byte COLOR_GREEN, COLOR_LIGHT_BLUE

; Text Banners for Top 10 Screen
top10_title_text:
    !text "TOP 10 PILOTS"       ; 13 chars
top10_header_text:
    !text "RNK  NAME    SCORE"   ; 18 chars
top10_divider_text:
    !text "-------------------" ; 19 chars
top10_prompt_text:
    !text "PRESS FIRE TO START" ; 19 chars

; Text Banners for Name Entry Screen
name_entry_congrats:
    !text "CONGRATULATIONS!"   ; 16 chars
name_entry_rank_label:
    !text "RANK #"              ; 6 chars
name_entry_score_label:
    !text "SCORE:"              ; 6 chars
name_entry_prompt_text:
    !text "ENTER YOUR INITIALS" ; 19 chars
name_entry_keys_text:
    !text "KEYBOARD: A-Z"       ; 13 chars
name_entry_del_text:
    !text "DEL: ERASE"          ; 10 chars
name_entry_confirm_text:
    !text "PRESS RETURN OR FIRE"; 20 chars

; ==============================================================================
; Subroutine: hiscore_init
; Purpose: Initializes session high score tracking from Rank 1 score.
; ==============================================================================
hiscore_init:
    lda top10_scores_lo + 0
    sta g_high_score + 0
    lda top10_scores_hi + 0
    sta g_high_score + 1
    lda #$ff
    sta s_qualify_rank
    sta s_highlight_rank
    lda #0
    sta s_kbd_prev_char
    rts

; ==============================================================================
; Subroutine: hiscore_qualifies
; Purpose: Checks if g_score qualifies for the Top 10 table (>= Rank 10 score).
; Returns: Carry Set if qualified, Carry Clear if not.
;          If qualified, s_qualify_rank contains target rank index (0..9).
; ==============================================================================
hiscore_qualifies:
    ; 1. Compare g_score against Rank 10 score (index 9)
    lda g_score + 1
    cmp top10_scores_hi + 9
    bcc @does_not_qualify
    bne @find_rank
    lda g_score + 0
    cmp top10_scores_lo + 9
    bcc @does_not_qualify

@find_rank:
    ; 2. Find insertion rank R (0..9) where g_score >= top10_score[R]
    ldx #0
@rank_loop:
    lda g_score + 1
    cmp top10_scores_hi, x
    bcc @next_rank
    bne @rank_found
    lda g_score + 0
    cmp top10_scores_lo, x
    bcs @rank_found
@next_rank:
    inx
    cpx #NUM_TOP_SCORES
    bne @rank_loop

@rank_found:
    stx s_qualify_rank
    sec                         ; Carry Set = Qualified
    rts

@does_not_qualify:
    lda #$ff
    sta s_qualify_rank
    clc                         ; Carry Clear = Did not qualify
    rts

; ==============================================================================
; Subroutine: hiscore_screen_show
; Purpose: Switches to Text Mode (Bank 0) and renders the Top 10 Hall of Fame.
; ==============================================================================
hiscore_screen_show:
    ; 1. Configure standard Bank 0 Text Mode
    lda #$1b
    sta VIC_CTRL1
    lda #$c8
    sta VIC_CTRL2
    lda #$1a                    ; Screen at $0400, Charset at $2800
    sta VIC_MEM_SETUP
    lda CIA2_DATA_A
    ora #$03                    ; Bank 0 (%11)
    sta CIA2_DATA_A
    lda #$37
    sta $0001                   ; Standard C64 memory config

    ; 2. Clear Screen RAM with space ($20) and Color RAM with Black ($00)
    ldx #0
    lda #$20
-   sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $06e8, x
    dex
    bne -

    ldx #0
    lda #COLOR_BLACK
-   sta $d800, x
    sta $d900, x
    sta $da00, x
    sta $dae8, x
    dex
    bne -

    ; 3. Draw Title: "TOP 10 PILOTS" at Col 36, Rows 6..18 in Yellow
    lda #COLOR_YELLOW
    sta s_char_color
    lda #6
    sta s_cur_row
    ldy #36
    ldx #0
-   lda top10_title_text, x
    jsr hud_draw_char
    inx
    cpx #13
    bne -

    ; 4. Draw Header: "RNK  NAME    SCORE" at Col 33, Rows 3..20 in Cyan
    lda #COLOR_CYAN
    sta s_char_color
    lda #3
    sta s_cur_row
    ldy #33
    ldx #0
-   lda top10_header_text, x
    jsr hud_draw_char
    inx
    cpx #18
    bne -

    ; 5. Draw Divider: 19 dashes at Col 31, Rows 3..21 in Dark Gray
    lda #COLOR_DARK_GRAY
    sta s_char_color
    lda #3
    sta s_cur_row
    ldy #31
    ldx #0
-   lda top10_divider_text, x
    jsr hud_draw_char
    inx
    cpx #19
    bne -

    ; 6. Draw 10 High Score Entries on Columns 28 down to 10
    ldx #0                      ; X = Rank (0..9)
@entry_loop:
    txa
    pha                         ; Save rank index

    ; Determine column: Col = 28 - (Rank * 2)
    txa
    asl
    sta $02                     ; Rank * 2
    lda #28
    sec
    sbc $02
    tay                         ; Y = Column for this rank

    ; Determine text color
    pla
    pha
    tax
    cpx s_highlight_rank
    bne +
    lda #COLOR_WHITE            ; Highlight newly entered score in bright white
    jmp ++
+   lda top10_rank_colors, x
++  sta s_char_color

    ; Print Rank Number at Rows 3..5 (e.g. " 1.", "10.")
    lda #3
    sta s_cur_row
    pla
    pha
    tax
    cpx #9
    bne @single_digit_rank
    lda #'1'
    jsr hud_draw_char
    lda #'0'
    jsr hud_draw_char
    lda #'.'
    jsr hud_draw_char
    jmp @print_initials

@single_digit_rank:
    lda #' '
    jsr hud_draw_char
    pla
    pha
    clc
    adc #'1'
    jsr hud_draw_char
    lda #'.'
    jsr hud_draw_char

@print_initials:
    ; Spacing: Rows 6..7 = spaces
    lda #' '
    jsr hud_draw_char
    lda #' '
    jsr hud_draw_char

    ; Print 3 Initials at Rows 8..10
    pla
    pha
    sta $02
    asl
    clc
    adc $02
    tax                         ; X = Rank * 3
    lda top10_initials + 0, x
    jsr hud_draw_char
    lda top10_initials + 1, x
    jsr hud_draw_char
    lda top10_initials + 2, x
    jsr hud_draw_char

    ; Spacing: Rows 11..13 = spaces
    lda #' '
    jsr hud_draw_char
    lda #' '
    jsr hud_draw_char
    lda #' '
    jsr hud_draw_char

    ; Format 16-bit score into decimal digits
    pla
    pha
    tax
    lda top10_scores_lo, x
    sta s_score_val_lo
    lda top10_scores_hi, x
    sta s_score_val_hi
    jsr hud_convert_16bit_to_digits

    ; Print 5 decimal digits (leading spaces preserved)
    ldx #0
-   lda s_score_digits, x
    jsr hud_draw_char
    inx
    cpx #5
    bne -

    ; Print trailing bulk double zeroes "00"
    lda #'0'
    jsr hud_draw_char
    lda #'0'
    jsr hud_draw_char

    ; Next rank
    pla
    tax
    inx
    cpx #NUM_TOP_SCORES
    beq @all_entries_done
    jmp @entry_loop
@all_entries_done:

    ; 7. Draw initial "PRESS FIRE TO START" at Col 4, Rows 3..21 in White
    lda #COLOR_WHITE
    sta s_char_color
    lda #3
    sta s_cur_row
    ldy #4
    ldx #0
-   lda top10_prompt_text, x
    jsr hud_draw_char
    inx
    cpx #19
    bne -
    lda #1
    sta s_top10_prompt_visible
    rts

; ==============================================================================
; Subroutine: hiscore_screen_update
; Purpose: Blinks "PRESS FIRE TO START" prompt at Col 4 at 1 Hz (0.5s rate).
; ==============================================================================
hiscore_screen_update:
    ; Blink prompt: visible when frames < 25, hidden when frames >= 25
    lda g_game_time_frames
    cmp #25
    bcc @show_prompt
    lda #COLOR_BLACK
    bne @apply_color
@show_prompt:
    lda #COLOR_WHITE
@apply_color:
    ldx #18
    ldy #4
-   sta $d800 + 3, x            ; Update Color RAM at Row X+3, Col 4
    ; Since Col 4 starts at offset 4, cell address = screen_row_table + 4
    ; Use color_row_table
    pha
    txa
    pha
    clc
    adc #3
    tax                         ; Row 3..21
    lda color_row_table_lo, x
    sta $fb
    lda color_row_table_hi, x
    sta $fc
    pla
    tax
    pla
    ldy #4
    sta ($fb), y
    dex
    bpl -
    rts

; ==============================================================================
; Subroutine: hiscore_screen_hide
; Purpose: Clears Screen RAM and Color RAM.
; ==============================================================================
hiscore_screen_hide:
    ldx #0
    lda #$20
-   sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $06e8, x
    lda #COLOR_BLACK
    sta $d800, x
    sta $d900, x
    sta $da00, x
    sta $dae8, x
    dex
    bne -
    rts

; ==============================================================================
; Subroutine: hiscore_scan_keyboard
; Purpose: Scans CIA1 keyboard matrix with single-stroke edge detection.
; Returns: A = ASCII character code (A..Z, 0..9, $08=DEL, $0D=RETURN, $20=SPACE)
;          or 0 if no new keypress edge detected.
; ==============================================================================
hiscore_scan_keyboard:
    ; 1. Configure CIA1 Port A as outputs ($FF) and Port B as inputs ($00)
    lda #$ff
    sta CIA1_DIR_A
    lda #$00
    sta CIA1_DIR_B

    ; 2. Iterate through 8 column masks
    ldx #0
@col_loop:
    lda kbd_col_masks, x
    sta CIA1_DATA_A             ; Pull column low
    lda CIA1_DATA_B             ; Read rows
    cmp #$ff
    beq @next_col               ; No key pressed in this column

    ; A key is pressed! Find row bit (0..7) that is 0
    sta $02                     ; Save Port B reading
    ldy #0
@row_loop:
    lsr $02
    bcc @key_found              ; Bit shifted out was 0 -> key found!
    iny
    cpy #8
    bne @row_loop
    jmp @next_col

@key_found:
    ; Key identified at Column X, Row Y. Calculate index = X * 8 + Y
    txa
    asl
    asl
    asl
    sta $03
    tya
    clc
    adc $03
    tax
    lda kbd_matrix_ascii, x
    beq @next_col               ; If unmapped key, continue searching

    ; Key has valid ASCII code in A!
    ; Check edge trigger against s_kbd_prev_char
    cmp s_kbd_prev_char
    beq @key_held               ; Same key held across frames -> return 0
    sta s_kbd_prev_char         ; New key edge!
    pha
    jsr @restore_cia1
    pla
    rts

@key_held:
    jsr @restore_cia1
    lda #0
    rts

@next_col:
    inx
    cpx #8
    bne @col_loop

    ; No keys active across entire matrix -> clear held key
    lda #0
    sta s_kbd_prev_char
    jsr @restore_cia1
    lda #0
    rts

@restore_cia1:
    lda #$ff
    sta CIA1_DATA_A
    lda #$00
    sta CIA1_DIR_A
    sta CIA1_DIR_B
    rts

; ==============================================================================
; STATE 5: STATE_NAME_ENTRY Handlers
; ==============================================================================

; ------------------------------------------------------------------------------
; Subroutine: state_name_entry_enter
; Purpose: Prepares Name Entry screen, shifts Top 10 entries down, stores score.
; ------------------------------------------------------------------------------
state_name_entry_enter:
    ; 1. Disable sprites & multiplexer
    lda #0
    sta VIC_SPR_ENABLE
    sta g_multiplexer_active
    sta g_missile_active
    sta VIC_BORDER_COLOR

    ; 2. Shift Top 10 entries 8 down to s_qualify_rank down by 1 position
    ldx #8
@shift_loop:
    cpx s_qualify_rank
    bcc @shift_done
    ; Shift score: top10[x+1] = top10[x]
    lda top10_scores_lo, x
    sta top10_scores_lo + 1, x
    lda top10_scores_hi, x
    sta top10_scores_hi + 1, x

    ; Shift initials: top10_initials[(x+1)*3] = top10_initials[x*3]
    txa
    sta $02
    asl
    clc
    adc $02                     ; X * 3
    tay                         ; Y = source initials index
    lda top10_initials + 0, y
    sta top10_initials + 3, y
    lda top10_initials + 1, y
    sta top10_initials + 4, y
    lda top10_initials + 2, y
    sta top10_initials + 5, y
    dex
    bpl @shift_loop

@shift_done:
    ; Store g_score into newly vacated rank slot
    ldx s_qualify_rank
    lda g_score + 0
    sta top10_scores_lo, x
    lda g_score + 1
    sta top10_scores_hi, x

    ; If rank is #1 (0), update session g_high_score
    cpx #0
    bne +
    lda g_score + 0
    sta g_high_score + 0
    lda g_score + 1
    sta g_high_score + 1
+
    ; Set highlight rank
    stx s_highlight_rank

    ; 3. Initialize initials entry buffer: "___"
    lda #'_'
    sta s_entry_initials + 0
    sta s_entry_initials + 1
    sta s_entry_initials + 2
    lda #0
    sta s_entry_cursor
    sta s_entry_blink_timer
    sta s_kbd_prev_char

    ; 4. Set up standard Bank 0 Text Mode
    lda #$1b
    sta VIC_CTRL1
    lda #$c8
    sta VIC_CTRL2
    lda #$1a
    sta VIC_MEM_SETUP
    lda CIA2_DATA_A
    ora #$03
    sta CIA2_DATA_A
    lda #$37
    sta $0001

    ; 5. Clear Screen RAM with spaces and Color RAM with Black
    ldx #0
    lda #$20
-   sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $06e8, x
    lda #COLOR_BLACK
    sta $d800, x
    sta $d900, x
    sta $da00, x
    sta $dae8, x
    dex
    bne -

    ; 6. Render Name Entry Screen Elements
    ; "CONGRATULATIONS!" at Col 32, Rows 4..19 in Yellow
    lda #COLOR_YELLOW
    sta s_char_color
    lda #4
    sta s_cur_row
    ldy #32
    ldx #0
-   lda name_entry_congrats, x
    jsr hud_draw_char
    inx
    cpx #16
    bne -

    ; "RANK #<X>   SCORE: <score>" at Col 28, Rows 2..22 in White
    lda #COLOR_WHITE
    sta s_char_color
    lda #2
    sta s_cur_row
    ldy #28
    ldx #0
-   lda name_entry_rank_label, x
    jsr hud_draw_char
    inx
    cpx #6
    bne -

    ; Rank number
    lda s_qualify_rank
    cmp #9
    bne @single_rank_num
    lda #'1'
    jsr hud_draw_char
    lda #'0'
    jsr hud_draw_char
    jmp @after_rank_num
@single_rank_num:
    clc
    adc #'1'
    jsr hud_draw_char
    lda #' '
    jsr hud_draw_char
@after_rank_num:
    lda #' '
    jsr hud_draw_char
    lda #' '
    jsr hud_draw_char

    ; "SCORE: "
    ldx #0
-   lda name_entry_score_label, x
    jsr hud_draw_char
    inx
    cpx #6
    bne -

    ; Formatted score digits
    lda g_score + 0
    sta s_score_val_lo
    lda g_score + 1
    sta s_score_val_hi
    jsr hud_convert_16bit_to_digits
    ldx #0
-   lda s_score_digits, x
    jsr hud_draw_char
    inx
    cpx #5
    bne -
    lda #'0'
    jsr hud_draw_char
    lda #'0'
    jsr hud_draw_char

    ; "ENTER YOUR INITIALS" at Col 23, Rows 3..21 in Cyan
    lda #COLOR_CYAN
    sta s_char_color
    lda #3
    sta s_cur_row
    ldy #23
    ldx #0
-   lda name_entry_prompt_text, x
    jsr hud_draw_char
    inx
    cpx #19
    bne -

    ; Draw Initials Entry Box: "[ _ _ _ ]" at Col 18
    ; Bracket '[' at Row 9
    lda #COLOR_WHITE
    sta s_char_color
    lda #9
    sta s_cur_row
    ldy #18
    lda #'['
    jsr hud_draw_char

    ; Initial 1 at Row 11
    lda #COLOR_YELLOW
    sta s_char_color
    lda #11
    sta s_cur_row
    ldy #18
    lda s_entry_initials + 0
    jsr hud_draw_char

    ; Initial 2 at Row 12
    lda #12
    sta s_cur_row
    lda s_entry_initials + 1
    jsr hud_draw_char

    ; Initial 3 at Row 13
    lda #13
    sta s_cur_row
    lda s_entry_initials + 2
    jsr hud_draw_char

    ; Bracket ']' at Row 15
    lda #COLOR_WHITE
    sta s_char_color
    lda #15
    sta s_cur_row
    ldy #18
    lda #']'
    jsr hud_draw_char

    ; Instructions at Col 12: "KEYBOARD: A-Z" in Light Gray
    lda #COLOR_LIGHT_GRAY
    sta s_char_color
    lda #6
    sta s_cur_row
    ldy #12
    ldx #0
-   lda name_entry_keys_text, x
    jsr hud_draw_char
    inx
    cpx #13
    bne -

    ; Instructions at Col 9: "DEL: ERASE" in Light Gray
    lda #COLOR_LIGHT_GRAY
    sta s_char_color
    lda #7
    sta s_cur_row
    ldy #9
    ldx #0
-   lda name_entry_del_text, x
    jsr hud_draw_char
    inx
    cpx #10
    bne -

    ; Confirm Prompt at Col 5: "PRESS RETURN OR FIRE" in Light Green
    lda #COLOR_LIGHT_GREEN
    sta s_char_color
    lda #2
    sta s_cur_row
    ldy #5
    ldx #0
-   lda name_entry_confirm_text, x
    jsr hud_draw_char
    inx
    cpx #20
    bne -
    rts

; ------------------------------------------------------------------------------
; Subroutine: state_name_entry_update
; Purpose: Scans keyboard, handles character input, DEL, and RETURN/FIRE commit.
; ------------------------------------------------------------------------------
state_name_entry_update:
    ; 1. Check for Joystick Fire or Space pressed to commit early
    lda g_input_fire_pressed
    ora g_input_start_pressed
    beq +
    jmp @commit_entry
+
    ; 2. Scan keyboard matrix
    jsr hiscore_scan_keyboard
    beq @update_cursor_blink    ; No key pressed

    ; Key pressed in A!
    cmp #$0d                    ; RETURN key
    bne +
    jmp @commit_entry
+
    cmp #$08                    ; DEL key
    bne +
    jmp @handle_del
+

    ; Check if key is a letter ('A'..'Z') or digit ('0'..'9')
    cmp #'0'
    bcc @update_cursor_blink
    cmp #'9' + 1
    bcc @is_valid_char
    cmp #'A'
    bcc @update_cursor_blink
    cmp #'Z' + 1
    bcs @update_cursor_blink

@is_valid_char:
    ; Store character at current cursor position (0..2)
    pha
    ldx s_entry_cursor
    cpx #3
    bcc +
    ldx #2                      ; Clamp to position 2
+   pla
    sta s_entry_initials, x

    ; Immediately draw character in Yellow on screen at Row (11 + X), Col 18
    pha
    txa
    clc
    adc #11
    sta s_cur_row
    lda #COLOR_YELLOW
    sta s_char_color
    ldy #18
    pla
    jsr hud_draw_char

    ; Advance cursor
    ldx s_entry_cursor
    cpx #2
    bcs +
    inc s_entry_cursor
+   jmp @update_cursor_blink

@handle_del:
    ldx s_entry_cursor
    ; If character at cursor is '_', move back one position first
    lda s_entry_initials, x
    cmp #'_'
    bne @erase_char
    cpx #0
    beq @update_cursor_blink
    dec s_entry_cursor
    ldx s_entry_cursor

@erase_char:
    lda #'_'
    sta s_entry_initials, x

    ; Redraw '_' on screen at Row (11 + X), Col 18 in White
    txa
    clc
    adc #11
    sta s_cur_row
    lda #COLOR_WHITE
    sta s_char_color
    ldy #18
    lda #'_'
    jsr hud_draw_char

@update_cursor_blink:
    ; Blink cursor at active character position: Row (11 + s_entry_cursor), Col 18
    inc s_entry_blink_timer
    lda s_entry_blink_timer
    and #$10                    ; 16-frame blink rate
    beq @cursor_on

    ; Cursor phase off: draw blank/space
    lda s_entry_cursor
    clc
    adc #11
    sta s_cur_row
    lda #COLOR_BLACK
    sta s_char_color
    ldy #18
    lda #$20
    jsr hud_draw_char
    rts

@cursor_on:
    ; Cursor phase on: draw current character or '_'
    ldx s_entry_cursor
    lda s_entry_initials, x
    pha
    txa
    clc
    adc #11
    sta s_cur_row
    lda #COLOR_YELLOW
    sta s_char_color
    ldy #18
    pla
    jsr hud_draw_char
    rts

@commit_entry:
    ; Replace any remaining '_' with space ($20)
    ldx #0
-   lda s_entry_initials, x
    cmp #'_'
    bne +
    lda #$20
    sta s_entry_initials, x
+   inx
    cpx #3
    bne -

    ; If player entered 3 spaces, default to "AAA"
    lda s_entry_initials + 0
    cmp #$20
    bne @write_top10
    lda s_entry_initials + 1
    cmp #$20
    bne @write_top10
    lda s_entry_initials + 2
    cmp #$20
    bne @write_top10
    lda #'A'
    sta s_entry_initials + 0
    sta s_entry_initials + 1
    sta s_entry_initials + 2

@write_top10:
    ; Copy 3 initials into top10_initials[s_qualify_rank * 3]
    lda s_qualify_rank
    sta $02
    asl
    clc
    adc $02
    tax                         ; X = s_qualify_rank * 3
    lda s_entry_initials + 0
    sta top10_initials + 0, x
    lda s_entry_initials + 1
    sta top10_initials + 1, x
    lda s_entry_initials + 2
    sta top10_initials + 2, x

    ; Set attract page to 1 so Top 10 Screen is shown first with new entry
    lda #1
    sta s_attract_page

    ; Transition to STATE_TITLE
    lda #STATE_TITLE
    jsr change_state
    rts

; ------------------------------------------------------------------------------
; Subroutine: state_name_entry_exit
; Purpose: Erases Name Entry screen.
; ------------------------------------------------------------------------------
state_name_entry_exit:
    jmp hiscore_screen_hide
