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
s_title_lockout:    !byte 0     ; Debounce safety timer on entering Title (20 frames = 0.4s)
s_title_released:   !byte 0     ; 1 = Fire & Space were released after entering Title
s_prompt_state:     !byte 0     ; Current color byte of prompt ($10 = visible, $00 = hidden, $FF = dirty)
s_hiscore_row:      !byte 0     ; Dynamic cursor row for stamping high score digits
s_digit_idx:        !byte 0     ; Digit buffer index during high score stamping
s_attract_screen:   !byte 0     ; 0 = Title Bitmap screen, 1 = Top 10 Directory screen
s_attract_timer_lo: !byte <500  ; Attract mode alternation countdown (500 frames = 10.0s)
s_attract_timer_hi: !byte >500
g_title_show_hiscore_first: !byte 0 ; 1 = jump directly to Top 10 Directory screen

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
; Purpose: Sets up Title state, initializes attract mode timer, and displays
;          Title Bitmap screen.
; ==============================================================================
title_enter:
    ; 1. Reset debounce safety lockout & require fresh button release
    lda #20
    sta s_title_lockout
    lda #0
    sta s_title_released
    lda #<500
    sta s_attract_timer_lo      ; 500 frames = 10.0s
    lda #>500
    sta s_attract_timer_hi

    lda g_title_show_hiscore_first
    beq +
    lda #0
    sta g_title_show_hiscore_first
    lda #1
    sta s_attract_screen
    jmp hiscore_screen_show

+   lda #0
    sta s_attract_screen        ; 0 = Title Bitmap screen
    ; Fall through to title_enter_bitmap

; ==============================================================================
; Subroutine: title_enter_bitmap
; Purpose: Sets up VIC-II Bank 2 Hi-Res Bitmap mode, copies pre-baked bitmap,
;          stamps dynamic high score, initializes colors, and enables display.
; ==============================================================================
title_enter_bitmap:
    lda #$ff
    sta s_prompt_state          ; Force dirty refresh on first frame

    ; Ensure black border and background
    lda #COLOR_BLACK
    sta VIC_BORDER_COLOR
    sta VIC_BG_COLOR0

    ; 2. Bank out BASIC ROM ($0001 = $36) so $A000..$BF3F is RAM
    lda #$36
    sta $0001

    ; 3. Fast copy 8,000-byte pre-baked title bitmap from title_bitmap_data to $A000
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

    ; 4. Dynamically stamp current g_high_score into Column 23
    jsr title_stamp_hiscore

    ; 5. Initialize Screen RAM ($8000..$83E7) to $10 (White on Black)
    lda #$10
    ldx #0
-   sta $8000, x
    sta $8100, x
    sta $8200, x
    sta $82e8, x                ; Fills $82E8..$83E7 (256 bytes)
    inx
    bne -

    ; 6. Switch VIC-II to Bank 2 ($8000..$BFFF) Hi-Res Bitmap Mode
    ; Ensure CIA2 Port A bits 0-1 are configured as outputs
    lda CIA2_DIR_A
    ora #$03
    sta CIA2_DIR_A

    ; Select VIC-II Bank 2 (%01)
    lda CIA2_DATA_A
    and #$fc
    ora #$01
    sta CIA2_DATA_A

    ; Set Screen RAM at offset $0000 ($8000) and Bitmap at offset $2000 ($A000)
    ; $D018: Bits 7..4 = %0000 ($0000), Bit 3 = 1 ($2000) -> $08
    lda #$08
    sta VIC_MEM_SETUP

    ; Set Hi-Res Bitmap Mode (BMM = 1, 25 rows, display enable)
    lda #$3b
    sta VIC_CTRL1

    ; Ensure Multi-Color Mode is disabled (MCM = 0, 40 cols)
    lda #$c8
    sta VIC_CTRL2

    ; Initial prompt state: visible ($10)
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
; Purpose: Blinks start prompt or directory cursor, alternates between screens
;          every 5 seconds, and checks for FIRE or SPACE to start game.
; ==============================================================================
title_update:
    ; --------------------------------------------------------------------------
    ; 1. Input Check: Check for Fire or Space newly pressed to start game
    ; --------------------------------------------------------------------------
    ; Track button release: Fire must be completely released first
    lda g_input_fire
    bne @button_held
    lda #1
    sta s_title_released
@button_held:

    ; Decrement safety lockout timer
    lda s_title_lockout
    beq @check_start
    dec s_title_lockout
    jmp @update_screens

@check_start:
    ; Require that button was released at least once on Title screen
    lda s_title_released
    beq @update_screens

    ; Check for FIRE newly pressed
    lda g_input_fire_pressed
    beq @update_screens

    ; Transition to STATE_READY
    lda #STATE_READY
    jsr change_state
    rts

    ; --------------------------------------------------------------------------
    ; 2. Screen-specific Update
    ; --------------------------------------------------------------------------
@update_screens:
    lda s_attract_screen
    bne @update_hiscore

    ; Mode 0: Title Bitmap Screen -> Blink "PRESS FIRE TO START" prompt
    lda g_game_time_frames
    cmp #25
    bcc @show_prompt
    lda #$00                    ; Black on Black ($00) -> Hidden
    beq @apply_color
@show_prompt:
    lda #$10                    ; White on Black ($10) -> Visible
@apply_color:
    cmp s_prompt_state
    beq @tick_attract_timer
    sta s_prompt_state
    jsr title_set_prompt_color
    jmp @tick_attract_timer

@update_hiscore:
    ; Mode 1: Top 10 Directory Screen -> Blink cursor
    jsr hiscore_screen_update

    ; --------------------------------------------------------------------------
    ; 3. Attract Mode 7-second Alternation Timer (350 frames @ 50 Hz PAL)
    ; --------------------------------------------------------------------------
@tick_attract_timer:
    lda s_attract_timer_lo
    bne +
    dec s_attract_timer_hi
+   dec s_attract_timer_lo
    lda s_attract_timer_lo
    ora s_attract_timer_hi
    bne @done

    ; Timer expired: Reset to 500 frames (10.0s) and toggle screen
    lda #<500
    sta s_attract_timer_lo
    lda #>500
    sta s_attract_timer_hi

    lda s_attract_screen
    eor #$01
    sta s_attract_screen
    beq @switch_to_bitmap

    ; Switch to Top 10 Directory Screen
    jsr hiscore_screen_show
    rts

@switch_to_bitmap:
    ; Switch to Title Bitmap Screen
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
;          re-enables BASIC ROM, sets black border/bg, and reseeds starfield.
; ==============================================================================
title_exit:
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

    ; 4. Restore Black border and background
    lda #COLOR_BLACK
    sta VIC_BORDER_COLOR
    sta VIC_BG_COLOR0

    ; 5. Re-initialize and seed starfield across Rows 1..24 ($0428..$07E7)
    jsr starfield_init

    ; 6. Clear Row 0 HUD
    jmp hud_clear
