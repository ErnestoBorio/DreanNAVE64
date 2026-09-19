; ==============================================================================
; TITLE.ASM - Attract & Title Screen Subsystem
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL, TATE Rotated Screen)
; Assembler: ACME 6502 Assembler
; ==============================================================================
; Displays:
; - "DREAN NAVE 64" centered at Column 26 (Rows 6..18) in White
; - "HIGH SCORE" centered at Column 20 (Rows 8..17) in Green
; - High score value centered at Column 18 in Green
; - Blinking "PRESS FIRE OR SPACE" at Column 12 (Rows 3..21) in Yellow
; - Background starfield scrolling
; - Detects FIRE or SPACE press to transition to STATE_READY
; ==============================================================================

; ------------------------------------------------------------------------------
; Title State RAM Variables
; ------------------------------------------------------------------------------
s_title_lockout:    !byte 0     ; Debounce safety timer on entering Title (20 frames = 0.4s)
s_title_released:   !byte 0     ; 1 = Fire & Space were released after entering Title

title_banner_text:
    !byte 68, 82, 69, 65, 78, 32, 78, 65, 86, 69, 32, 54, 52 ; "DREAN NAVE 64" (13 chars)

title_hiscore_text:
    !byte 72, 73, 71, 72, 32, 83, 67, 79, 82, 69             ; "HIGH SCORE" (10 chars)

title_prompt_text:
    !byte 80, 82, 69, 83, 83, 32, 70, 73, 82, 69, 32, 79, 82, 32, 83, 80, 65, 67, 69 ; "PRESS FIRE OR SPACE" (19 chars)

; ==============================================================================
; Subroutine: title_enter
; Purpose: Draws Title screen elements across playfield columns.
; ==============================================================================
title_enter:
    ; Reset debounce safety lockout & require fresh button release
    lda #20
    sta s_title_lockout
    lda #0
    sta s_title_released

    ; 0. Clear and reseed static starfield across Rows 1..24
    jsr starfield_init

    ; 1. Draw "DREAN NAVE 64" at Column 26, Rows 6..18 in White
    lda #COLOR_WHITE
    sta s_char_color
    lda #6
    sta s_cur_row
    ldy #26
    ldx #0
-   lda title_banner_text, x
    jsr hud_draw_char
    inx
    cpx #13
    bne -

    ; 2. Draw "HIGH SCORE" at Column 20, Rows 8..17 in Green
    lda #COLOR_GREEN
    sta s_char_color
    lda #8
    sta s_cur_row
    ldy #20
    ldx #0
-   lda title_hiscore_text, x
    jsr hud_draw_char
    inx
    cpx #10
    bne -

    ; 3. Convert and draw High Score value at Column 18 in Green
    lda g_high_score + 0
    sta s_score_val_lo
    lda g_high_score + 1
    sta s_score_val_hi
    jsr hud_convert_16bit_to_digits

    ; Find first non-space digit in s_score_digits (0..4)
    ldx #0
-   lda s_score_digits, x
    cmp #$20
    bne +
    inx
    cpx #4
    bne -
+
    ; Center digits across playfield rows:
    ; Length = 7 - X. Margin = (24 - (7 - X)) / 2 = (17 + X) / 2.
    ; Start row = Margin + 1.
    txa
    clc
    adc #17
    lsr
    clc                         ; Clear carry after lsr so adc #1 doesn't add carry!
    adc #1
    sta s_cur_row

    txa
    pha                         ; Save first digit index
    lda #COLOR_GREEN
    sta s_char_color
    ldy #18
    pla
    tax
-   lda s_score_digits, x
    jsr hud_draw_char
    inx
    cpx #5
    bne -

    ; Print trailing bulk double zeroes "00"
    lda #$30
    jsr hud_draw_char
    lda #$30
    jsr hud_draw_char

    ; 4. Initial draw of "PRESS FIRE OR SPACE"
    jmp title_draw_prompt

; ==============================================================================
; Subroutine: title_update
; Purpose: Blinks start prompt and checks for FIRE or SPACE with safety debounce.
; ==============================================================================
title_update:
    ; 1. Blink "PRESS FIRE OR SPACE" prompt:
    ; 0.5s shown (frames 0..24), 0.5s hidden (frames 25..49)
    lda g_game_time_frames
    cmp #25
    bcs @hide_prompt

    jsr title_draw_prompt
    jmp @check_input_safety

@hide_prompt:
    jsr title_hide_prompt

@check_input_safety:
    ; 2. Track button release: Fire and Space must be completely released
    lda g_input_fire
    ora g_input_start
    bne @button_held
    lda #1
    sta s_title_released
@button_held:

    ; 3. Decrement safety lockout timer
    lda s_title_lockout
    beq @check_start
    dec s_title_lockout
    rts

@check_start:
    ; 4. Require that button was released at least once on Title screen
    lda s_title_released
    beq @done

    ; 5. Check for FIRE or SPACE newly pressed
    lda g_input_fire_pressed
    ora g_input_start_pressed
    beq @done

    ; Transition to STATE_READY
    lda #STATE_READY
    jsr change_state

@done:
    rts

; ==============================================================================
; Subroutine: title_draw_prompt
; Purpose: Prints "PRESS FIRE OR SPACE" at Column 12, Rows 3..21 in Yellow.
; ==============================================================================
title_draw_prompt:
    lda #COLOR_YELLOW
    sta s_char_color
    lda #3
    sta s_cur_row
    ldy #12
    ldx #0
-   lda title_prompt_text, x
    jsr hud_draw_char
    inx
    cpx #19
    bne -
    rts

; ==============================================================================
; Subroutine: title_hide_prompt
; Purpose: Clears "PRESS FIRE OR SPACE" line at Column 12 with blank spaces.
; ==============================================================================
title_hide_prompt:
    lda #COLOR_BLACK
    sta s_char_color
    lda #3
    sta s_cur_row
    ldy #12
    ldx #19
-   lda #$20
    jsr hud_draw_char
    dex
    bne -
    rts

; ==============================================================================
; Subroutine: title_exit
; Purpose: Clears all title screen text elements from playfield.
; ==============================================================================
title_exit:
    lda #COLOR_BLACK
    sta s_char_color

    ; 1. Erase Column 26 ("DREAN NAVE 64": Rows 6..18)
    lda #6
    sta s_cur_row
    ldy #26
    ldx #13
-   lda #$20
    jsr hud_draw_char
    dex
    bne -

    ; 2. Erase Column 20 ("HIGH SCORE": Rows 8..17)
    lda #8
    sta s_cur_row
    ldy #20
    ldx #10
-   lda #$20
    jsr hud_draw_char
    dex
    bne -

    ; 3. Erase Column 18 (Score digits: Rows 7..17)
    lda #7
    sta s_cur_row
    ldy #18
    ldx #11
-   lda #$20
    jsr hud_draw_char
    dex
    bne -

    ; 4. Erase Column 12 ("PRESS FIRE OR SPACE": Rows 3..21)
    jmp title_hide_prompt
