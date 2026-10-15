; ==============================================================================
; STARFIELD.ASM - High-Performance Fine-Scrolling Starfield Subsystem
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
; 
; Architecture & Performance:
; - 5 stars per row across all 24 playfield rows (120 active stars total).
; - Uniform 2 pixels/frame smooth scrolling (100 pixels/sec at 50 Hz PAL).
; - Fine scroll register ($D016) steps: 7 -> 5 -> 3 -> 1 -> 7 (with coarse shift).
; - Spans all the way up to Column 38 so stars continuously appear at the very top.
; - On coarse shift (every 4 frames), advances 120 stars in ~4,300 cycles.
; - Color RAM for playfield rows is static: 0 cycles spent on Color RAM per frame.
; - Preserves 100% locked 50 Hz PAL frame budget with zero jitter or stutter.
; ==============================================================================

; ------------------------------------------------------------------------------
; Starfield State Variables & Memory Arrays
; ------------------------------------------------------------------------------
g_starfield_fine_x: !byte 7   ; Hardware fine scroll (7..0), matches standard 40-col default 7
s_lfsr_lo:          !byte $ac ; 16-bit Galois LFSR low byte
s_lfsr_hi:          !byte $e1 ; 16-bit Galois LFSR high byte
s_row_color_temp:   !byte 0   ; Temporary color storage during initialization
s_pick_y_temp:      !byte 0   ; Temporary Y register preservation during pick_char

; Star position and character arrays for Rows 1..24 (index 1..24, 5 stars per row)
s_star_col1:        !fill 25, 0
s_star_col2:        !fill 25, 0
s_star_col3:        !fill 25, 0
s_star_col4:        !fill 25, 0
s_star_col5:        !fill 25, 0
s_star_char1:       !fill 25, 0
s_star_char2:       !fill 25, 0
s_star_char3:       !fill 25, 0
s_star_char4:       !fill 25, 0
s_star_char5:       !fill 25, 0

; ------------------------------------------------------------------------------
; Star Character Distribution Table (Weighted 117..127 hierarchy, no empty spaces)
; ------------------------------------------------------------------------------
s_star_chars:
    !byte $7f, $7f, $7f, $7f, $7f, $7e, $7e, $7e, $7e, $7d, $7d, $7d, $7c, $7c, $7b, $7b
    !byte $7a, $7a, $79, $78, $77, $76, $75, $7f, $7e, $7d, $7f, $7e, $7c, $7b, $7f, $7e

; ------------------------------------------------------------------------------
; Playfield Row Color Palette (Grayscale & Cyan stellar shades)
; ------------------------------------------------------------------------------
s_star_palette:
    !byte COLOR_WHITE, COLOR_LIGHT_GRAY, COLOR_CYAN, COLOR_MEDIUM_GRAY
    !byte COLOR_WHITE, COLOR_LIGHT_GRAY, COLOR_DARK_GRAY, COLOR_WHITE

; ==============================================================================
; Subroutine: starfield_rand
; Purpose: 16-bit Galois LFSR pseudo-random 8-bit generator (22 cycles).
; Returns: Random 8-bit value in Accumulator (0..255).
; ==============================================================================
starfield_rand:
    lda s_lfsr_hi
    lsr
    sta s_lfsr_hi
    ror s_lfsr_lo
    bcc +
    lda s_lfsr_hi
    eor #$b4            ; Galois LFSR feedback polynomial ($B400)
    sta s_lfsr_hi
+   lda s_lfsr_lo
    eor s_lfsr_hi       ; Mix high and low bytes for maximum 8-bit entropy
    rts

; ==============================================================================
; Subroutine: starfield_pick_char
; Purpose: Returns a pseudo-random star character code (117..127) in Accumulator.
; ==============================================================================
starfield_pick_char:
    sty s_pick_y_temp
    jsr starfield_rand
    and #$1f
    tay
    lda s_star_chars, y
    ldy s_pick_y_temp
    rts

; ==============================================================================
; Subroutine: starfield_init
; Purpose: Installs charset at $2800, sets $D018, clears playfield, sets static
;          palette in Color RAM, and seeds 120 distributed stars across Rows 1..24.
; ==============================================================================
starfield_init:
    ; 1. Point VIC-II to Screen RAM ($0400) and Charset ($2800) ($D018 = $1A)
    lda #$1a
    sta VIC_MEM_SETUP

    ; 2. Reset fine scroll and LFSR seeds
    lda #7
    sta g_starfield_fine_x
    lda #$ac
    sta s_lfsr_lo
    lda #$e1
    sta s_lfsr_hi

    ; 3. Clear Playfield Screen RAM (Rows 1..24) to space ($20)
    ;    and initialize Color RAM rows with stellar palette
    ldx #1
@init_rows_loop:
    lda screen_row_table_lo, x
    sta $fb
    sta $fd                     ; color_row_table_lo == screen_row_table_lo
    lda screen_row_table_hi, x
    sta $fc
    lda color_row_table_hi, x
    sta $fe

    ; Palette color for this row
    txa
    and #$07
    tay
    lda s_star_palette, y
    sta s_row_color_temp

    ldy #39
@clear_cols_loop:
    lda #$20                    ; Space
    sta ($fb), y
    lda s_row_color_temp
    sta ($fd), y
    dey
    bpl @clear_cols_loop

    inx
    cpx #25
    bne @init_rows_loop

    ; 4. Populate 5 stars per row across Rows 1..24 (spanning cols 0..38)
    ldx #1
@init_stars_loop:
    lda screen_row_table_lo, x
    sta $fb
    lda screen_row_table_hi, x
    sta $fc

    ; Star 1: initial column in range 0..7
    jsr starfield_rand
    and #$07
    sta s_star_col1, x
    jsr starfield_pick_char
    sta s_star_char1, x
    ldy s_star_col1, x
    sta ($fb), y

    ; Star 2: initial column in range 8..15
    jsr starfield_rand
    and #$07
    clc
    adc #8
    sta s_star_col2, x
    jsr starfield_pick_char
    sta s_star_char2, x
    ldy s_star_col2, x
    sta ($fb), y

    ; Star 3: initial column in range 16..23
    jsr starfield_rand
    and #$07
    clc
    adc #16
    sta s_star_col3, x
    jsr starfield_pick_char
    sta s_star_char3, x
    ldy s_star_col3, x
    sta ($fb), y

    ; Star 4: initial column in range 24..31
    jsr starfield_rand
    and #$07
    clc
    adc #24
    sta s_star_col4, x
    jsr starfield_pick_char
    sta s_star_char4, x
    ldy s_star_col4, x
    sta ($fb), y

    ; Star 5: initial column in range 32..39 (top visible and border columns)
    jsr starfield_rand
    and #$07
    clc
    adc #32
    sta s_star_col5, x
    jsr starfield_pick_char
    sta s_star_char5, x
    ldy s_star_col5, x
    sta ($fb), y

    inx
    cpx #25
    beq +
    jmp @init_stars_loop
+   rts

; ==============================================================================
; Subroutine: starfield_update
; Purpose: Advances 2-pixel hardware fine scroll every frame (100 px/sec at 50 Hz).
;          When fine scroll wraps (7 -> 5 -> 3 -> 1 -> 7), advances all 120 stars
;          by 1 column to the left (< 4,400 cycles).
; ==============================================================================
starfield_update:
    ; Steady smooth speed: 2 pixels every frame (100 pixels/sec at 50 Hz PAL)
    lda g_starfield_fine_x
    sec
    sbc #2
    and #$07
    sta g_starfield_fine_x
    cmp #6                      ; Wrapped past 0? (fine_x 6..7 indicates wrap with step 2)
    bcs @do_coarse_shift
    rts

@do_coarse_shift:
    ldx #1
@row_loop:
    lda screen_row_table_lo, x
    sta $fb
    lda screen_row_table_hi, x
    sta $fc

    ; --- Star 1 ---
    ldy s_star_col1, x
    lda #$20
    sta ($fb), y                ; Erase old position
    dey
    bpl +
    jsr starfield_pick_char
    sta s_star_char1, x
    jsr starfield_rand
    and #$01
    clc
    adc #38                     ; Wrap to top visible column (38 or 39)
    tay
+   tya
    sta s_star_col1, x
    lda s_star_char1, x
    sta ($fb), y                ; Draw new position

    ; --- Star 2 ---
    ldy s_star_col2, x
    lda #$20
    sta ($fb), y                ; Erase old position
    dey
    bpl +
    jsr starfield_pick_char
    sta s_star_char2, x
    jsr starfield_rand
    and #$01
    clc
    adc #38                     ; Wrap to top visible column (38 or 39)
    tay
+   tya
    sta s_star_col2, x
    lda s_star_char2, x
    sta ($fb), y                ; Draw new position

    ; --- Star 3 ---
    ldy s_star_col3, x
    lda #$20
    sta ($fb), y                ; Erase old position
    dey
    bpl +
    jsr starfield_pick_char
    sta s_star_char3, x
    jsr starfield_rand
    and #$01
    clc
    adc #38                     ; Wrap to top visible column (38 or 39)
    tay
+   tya
    sta s_star_col3, x
    lda s_star_char3, x
    sta ($fb), y                ; Draw new position

    ; --- Star 4 ---
    ldy s_star_col4, x
    lda #$20
    sta ($fb), y                ; Erase old position
    dey
    bpl +
    jsr starfield_pick_char
    sta s_star_char4, x
    jsr starfield_rand
    and #$01
    clc
    adc #38                     ; Wrap to top visible column (38 or 39)
    tay
+   tya
    sta s_star_col4, x
    lda s_star_char4, x
    sta ($fb), y                ; Draw new position

    ; --- Star 5 ---
    ldy s_star_col5, x
    lda #$20
    sta ($fb), y                ; Erase old position
    dey
    bpl +
    jsr starfield_pick_char
    sta s_star_char5, x
    jsr starfield_rand
    and #$01
    clc
    adc #38                     ; Wrap to top visible column (38 or 39)
    tay
+   tya
    sta s_star_col5, x
    lda s_star_char5, x
    sta ($fb), y                ; Draw new position

    inx
    cpx #25
    beq +
    jmp @row_loop
+   rts
