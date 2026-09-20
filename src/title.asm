; ==============================================================================
; TITLE.ASM - Attract & Title Screen Subsystem (Hi-Res Monochrome Bitmap Mode)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL, TATE Rotated Screen)
; Assembler: ACME 6502 Assembler
; ==============================================================================
; Displays:
; - NAVE Logo: 83x194 monochrome 1-bit bitmap at top of TATE screen (Cols 29..39)
; - "HIGH SCORE": Centered at Column 25 (Rows 7..16)
; - High score value: Dynamically stamped into Column 23, centered
; - "(C)2012 VIDEOGAMO INC": Centered at Column 17 (Rows 3..21)
; - "(D)2026 DREAN64": Centered at Column 15 (Rows 6..18)
; - Blinking "PRESS FIRE TO START": At Column 8 (Rows 3..21)
;   Blinking achieved by toggling Screen RAM cell colors between $10 (White on Black)
;   and $00 (Black on Black).
; - Press FIRE or SPACE (with double-skip debounce protection) to transition to STATE_READY.
; ==============================================================================

; ------------------------------------------------------------------------------
; Title State RAM Variables
; ------------------------------------------------------------------------------
s_attract_page:     !byte 0     ; 0 = Title Bitmap screen, 1 = Top 10 Screen
s_attract_timer:    !byte 250   ; 5.0 seconds at 50 Hz PAL (250 frames)
s_title_lockout:    !byte 0     ; Debounce safety timer on entering Title (20 frames = 0.4s)
s_title_released:   !byte 0     ; 1 = Fire & Space were released after entering Title
s_prompt_state:     !byte 0     ; Current color byte of prompt ($10 = visible, $00 = hidden, $FF = dirty)
s_hiscore_row:      !byte 0     ; Dynamic cursor row for stamping high score digits
s_digit_idx:        !byte 0     ; Digit buffer index during high score stamping

; ------------------------------------------------------------------------------
; Screen RAM cell addresses for Column 8, Rows 3..21 (19 cells: $8000 + R * 40 + 8)
; ------------------------------------------------------------------------------
prompt_cells_lo:
    !byte <$8080, <$80a8, <$80d0, <$80f8, <$8120, <$8148, <$8170, <$8198
    !byte <$81c0, <$81e8, <$8210, <$8238, <$8260, <$8288, <$82b0, <$82d8
    !byte <$8300, <$8328, <$8350

prompt_cells_hi:
    !byte >$8080, >$80a8, >$80d0, >$80f8, >$8120, >$8148, >$8170, >$8198
    !byte >$81c0, >$81e8, >$8210, >$8238, >$8260, >$8288, >$82b0, >$82d8
    !byte >$8300, >$8328, >$8350

; ------------------------------------------------------------------------------
; Bitmap RAM cell addresses for Column 23, Rows 0..24 ($A000 + R * 320 + 184)
; ------------------------------------------------------------------------------
col23_bitmap_lo:
    !byte <$a0b8, <$a1f8, <$a338, <$a478, <$a5b8, <$a6f8, <$a838, <$a978
    !byte <$aab8, <$abf8, <$ad38, <$ae78, <$afb8, <$b0f8, <$b238, <$b378
    !byte <$b4b8, <$b5f8, <$b738, <$b878, <$b9b8, <$baf8, <$bc38, <$bd78
    !byte <$beb8

col23_bitmap_hi:
    !byte >$a0b8, >$a1f8, >$a338, >$a478, >$a5b8, >$a6f8, >$a838, >$a978
    !byte >$aab8, >$abf8, >$ad38, >$ae78, >$afb8, >$b0f8, >$b238, >$b378
    !byte >$b4b8, >$b5f8, >$b738, >$b878, >$b9b8, >$baf8, >$bc38, >$bd78
    !byte >$beb8

; ==============================================================================
; Subroutine: title_enter
; Purpose: Sets up debounce timers and dispatches to active attract page
;          (0 = Title Bitmap screen, 1 = Top 10 Screen).
; ==============================================================================
title_enter:
    ; 1. Reset debounce safety lockout & require fresh button release
    lda #20
    sta s_title_lockout
    lda #0
    sta s_title_released
    lda #$ff
    sta s_prompt_state          ; Force dirty refresh on first frame
    lda #250
    sta s_attract_timer

    ; 2. Dispatch to active page
    lda s_attract_page
    beq title_enter_bitmap
    jmp hiscore_screen_show

title_enter_bitmap:
    ; 1. Bank out BASIC ROM ($0001 = $36) so $A000..$BF3F is RAM
    lda #$36
    sta $0001

    ; 2. Fast copy 8,000-byte pre-baked title bitmap from title_bitmap_data to $A000
    lda #<title_bitmap_data
    sta $fb
    lda #>title_bitmap_data
    sta $fc
    lda #<$a000
    sta $fd
    lda #>$a000
    sta $fe

    ; Copy 31 full pages (7,936 bytes)
    ldx #31
@page_loop:
    ldy #0
-   lda ($fb), y
    sta ($fd), y
    iny
    bne -
    inc $fc
    inc $fe
    dex
    bne @page_loop

    ; Copy remaining 64 bytes (8000 - 7936 = 64)
    ldy #63
-   lda ($fb), y
    sta ($fd), y
    dey
    bpl -

    ; 3. Dynamically stamp current g_high_score into Column 23
    jsr title_stamp_hiscore

    ; 4. Initialize Screen RAM ($8000..$83E7) to $10 (White on Black)
    lda #$10
    ldx #0
-   sta $8000, x
    sta $8100, x
    sta $8200, x
    sta $82e8, x                ; Fills $82E8..$83E7 (256 bytes)
    inx
    bne -

    ; 5. Switch VIC-II to Bank 2 ($8000..$BFFF) Hi-Res Bitmap Mode
    lda CIA2_DIR_A
    ora #$03
    sta CIA2_DIR_A

    lda CIA2_DATA_A
    and #$fc
    ora #$01
    sta CIA2_DATA_A

    ; Set Screen RAM at offset $0000 ($8000) and Bitmap at offset $2000 ($A000)
    lda #$08
    sta VIC_MEM_SETUP

    ; Set Hi-Res Bitmap Mode
    lda #$3b
    sta VIC_CTRL1

    lda #$c8
    sta VIC_CTRL2

    lda #$10
    sta s_prompt_state
    rts

; ==============================================================================
; Subroutine: title_stamp_hiscore
; Purpose: Clears Column 23 rows 7..17 and stamps formatted g_high_score + "00".
; ==============================================================================
title_stamp_hiscore:
    ; 1. Clear Column 23 rows 7..17 in bitmap (fill with 8 bytes of 0 per row)
    ldx #7
@clear_loop:
    lda col23_bitmap_lo, x
    sta $fb
    lda col23_bitmap_hi, x
    sta $fc
    lda #0
    ldy #7
-   sta ($fb), y
    dey
    bpl -
    inx
    cpx #18
    bne @clear_loop

    ; 2. Convert 16-bit g_high_score to decimal digits
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
    stx s_digit_idx

    ; Calculate centered starting row:
    ; Length = (5 - X) + 2 = 7 - X digits.
    ; Margin = (24 - (7 - X)) / 2 = (17 + X) / 2.
    ; Start row = Margin + 1.
    txa
    clc
    adc #17
    lsr
    clc
    adc #1
    sta s_hiscore_row

    ; 3. Stamp decimal digits from s_digit_idx to 4
@stamp_digits:
    ldx s_digit_idx
    lda s_score_digits, x
    ldx s_hiscore_row
    jsr title_stamp_col23_char
    inc s_hiscore_row
    inc s_digit_idx
    lda s_digit_idx
    cmp #5
    bne @stamp_digits

    ; 4. Stamp trailing bulk double zeroes "00"
    ldx s_hiscore_row
    lda #$30                    ; Char '0'
    jsr title_stamp_col23_char
    inc s_hiscore_row

    ldx s_hiscore_row
    lda #$30                    ; Char '0'
    jsr title_stamp_col23_char
    rts

; ==============================================================================
; Subroutine: title_stamp_col23_char
; Purpose: Copies 8x8 glyph for Char A from g_custom_charset ($2800) into
;          Column 23, Row X of Bitmap RAM ($A000).
; Arguments: A = character code, X = row (0..24)
; ==============================================================================
title_stamp_col23_char:
    pha
    lda col23_bitmap_lo, x
    sta $fb
    lda col23_bitmap_hi, x
    sta $fc
    pla

    ; Calculate source glyph address: $2800 + A * 8
    sta $fd
    lda #0
    sta $fe
    asl $fd
    rol $fe
    asl $fd
    rol $fe
    asl $fd
    rol $fe
    lda $fe
    clc
    adc #>$2800
    sta $fe

    ; Copy 8 scanlines
    ldy #7
-   lda ($fd), y
    sta ($fb), y
    dey
    bpl -
    rts

; ==============================================================================
; Subroutine: title_update
; Purpose: Blinks active page prompt, alternates between Title Bitmap (5s) and
;          Top 10 Screen (5s), and checks for FIRE or SPACE to start game.
; ==============================================================================
title_update:
    ; 1. Track button release: Fire and Space must be completely released
    lda g_input_fire
    ora g_input_start
    bne @button_held
    lda #1
    sta s_title_released
@button_held:

    ; 2. Decrement safety lockout timer
    lda s_title_lockout
    beq @check_start
    dec s_title_lockout
    rts

@check_start:
    ; 3. Check for FIRE or SPACE newly pressed to start the game
    lda s_title_released
    beq @update_page
    lda g_input_fire_pressed
    ora g_input_start_pressed
    beq @update_page

    ; Button pressed! Transition to STATE_READY immediately
    lda #STATE_READY
    jmp change_state

@update_page:
    ; 4. Update active page animations
    lda s_attract_page
    bne @update_top10

    ; Page 0: Title Bitmap prompt blink
    lda g_game_time_frames
    cmp #25
    bcc @show_prompt
    lda #$00                    ; Black on Black ($00) -> Hidden
    beq @apply_color
@show_prompt:
    lda #$10                    ; White on Black ($10) -> Visible
@apply_color:
    cmp s_prompt_state
    beq @check_timer
    sta s_prompt_state
    jsr title_set_prompt_color
    jmp @check_timer

@update_top10:
    ; Page 1: Top 10 text prompt blink
    jsr hiscore_screen_update

@check_timer:
    ; 5. Decrement 5.0-second attract alternation timer (250 frames)
    dec s_attract_timer
    bne @done

    ; Timer expired: Switch page!
    lda #250
    sta s_attract_timer
    lda s_attract_page
    bne @switch_to_bitmap

    ; Currently on Bitmap (0): switch to Top 10 (1)
    jsr title_exit_bitmap_only
    lda #1
    sta s_attract_page
    jsr hiscore_screen_show
    rts

@switch_to_bitmap:
    ; Currently on Top 10 (1): switch to Bitmap (0)
    jsr hiscore_screen_hide
    lda #0
    sta s_attract_page
    jsr title_enter_bitmap

@done:
    rts

; ==============================================================================
; Subroutine: title_set_prompt_color
; Purpose: Sets Screen RAM color byte for Column 8, Rows 3..21 to s_prompt_state.
; ==============================================================================
title_set_prompt_color:
    ldx #18
-   lda prompt_cells_lo, x
    sta $fb
    lda prompt_cells_hi, x
    sta $fc
    lda s_prompt_state
    ldy #0
    sta ($fb), y
    dex
    bpl -
    rts

; ==============================================================================
; Subroutine: title_exit
; Purpose: Restores Bank 0, Text Mode, Screen RAM $0400, Charset $2800,
;          re-enables BASIC ROM, and reseeds the playfield starfield.
; ==============================================================================
title_exit:
    ; If on bitmap page, restore text mode settings
    lda s_attract_page
    bne @exit_text_page

    jsr title_exit_bitmap_only
    jmp @common_exit

@exit_text_page:
    jsr hiscore_screen_hide

@common_exit:
    ; Clear highlight rank
    lda #$ff
    sta s_highlight_rank

    ; Re-initialize and seed starfield across Rows 1..24 ($0428..$07E7)
    jsr starfield_init

    ; Clear Row 0 HUD
    jmp hud_clear

; ==============================================================================
; Subroutine: title_exit_bitmap_only
; Purpose: Restores standard VIC-II settings from Bank 2 Bitmap to Bank 0 Text.
; ==============================================================================
title_exit_bitmap_only:
    ; 1. Restore standard VIC-II settings: Text Mode, Screen $0400, Charset $2800
    lda #$1b
    sta VIC_CTRL1

    lda #$c8
    sta VIC_CTRL2

    lda #$1a
    sta VIC_MEM_SETUP

    ; 2. Restore VIC-II Bank 0 (%11)
    lda CIA2_DATA_A
    ora #$03
    sta CIA2_DATA_A

    ; 3. Restore standard C64 memory configuration ($0001 = $37: BASIC ROM enabled)
    lda #$37
    sta $0001
    rts
