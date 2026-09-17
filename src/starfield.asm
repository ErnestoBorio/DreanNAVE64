; ==============================================================================
; STARFIELD.ASM - High-Speed Multi-Layer Parallax Starfield Subsystem (Phase 4)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
; 
; Features:
; - 2048-byte custom character set loaded to VIC-II RAM at $2800-$2FFF
; - VIC-II memory configuration ($D018 = $1A: Screen $0400, Charset $2800)
; - User-specified star character probability hierarchy (Chars 117-127, rare to frequent)
; - 16-bit Galois LFSR pseudo-random generator (65,535 cycle period)
; - 3-layer parallax row shifting (Fast: every 2 frames, Med: every 4, Slow: every 8)
; - Deterministic CPU budget (~7,000 cycles/frame max, leaving 12,000+ for game entities)
; ==============================================================================

; ------------------------------------------------------------------------------
; Starfield RAM State Variables
; ------------------------------------------------------------------------------
g_starfield_frame:  !byte 0   ; Frame counter for multi-speed parallax cadence
s_lfsr_lo:          !byte $ac ; 16-bit Galois LFSR low byte
s_lfsr_hi:          !byte $e1 ; 16-bit Galois LFSR high byte

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
; Subroutine: starfield_init
; Purpose: Installs charset at $2800, sets $D018, and seeds initial starfield.
; ==============================================================================
starfield_init:
    ; 1. Copy 2,048 bytes (8 pages) of g_custom_charset to $2800-$2FFF
    ldx #0
@copy_charset_loop:
    lda g_custom_charset + 0, x
    sta $2800 + 0, x
    lda g_custom_charset + 256, x
    sta $2800 + 256, x
    lda g_custom_charset + 512, x
    sta $2800 + 512, x
    lda g_custom_charset + 768, x
    sta $2800 + 768, x
    lda g_custom_charset + 1024, x
    sta $2800 + 1024, x
    lda g_custom_charset + 1280, x
    sta $2800 + 1280, x
    lda g_custom_charset + 1536, x
    sta $2800 + 1536, x
    lda g_custom_charset + 1792, x
    sta $2800 + 1792, x
    inx
    bne @copy_charset_loop

    ; 2. Point VIC-II to Screen RAM ($0400) and Charset ($2800) ($D018 = $1A)
    lda #$1a
    sta VIC_MEM_SETUP

    ; 3. Reset frame counter & seed
    lda #0
    sta g_starfield_frame
    lda #$ac
    sta s_lfsr_lo
    lda #$e1
    sta s_lfsr_hi

    ; 4. Populate initial playfield stars across Rows 1..24 (960 characters)
    ; Page 1 of playfield: $0428 to $0527 (256 bytes)
    ldx #0
@seed_page0:
    jsr starfield_rand
    tay
    lda g_star_prob_table, y
    sta $0428, x
    lda g_star_color_table, y
    sta $d828, x
    inx
    bne @seed_page0

    ; Page 2 of playfield: $0528 to $0627 (256 bytes)
@seed_page1:
    jsr starfield_rand
    tay
    lda g_star_prob_table, y
    sta $0528, x
    lda g_star_color_table, y
    sta $d928, x
    inx
    bne @seed_page1

    ; Page 3 of playfield: $0628 to $0727 (256 bytes)
@seed_page2:
    jsr starfield_rand
    tay
    lda g_star_prob_table, y
    sta $0628, x
    lda g_star_color_table, y
    sta $da28, x
    inx
    bne @seed_page2

    ; Remaining 192 bytes of playfield: $0728 to $07E7
@seed_page3:
    jsr starfield_rand
    tay
    lda g_star_prob_table, y
    sta $0728, x
    lda g_star_color_table, y
    sta $db28, x
    inx
    cpx #192
    bne @seed_page3
    rts

; ==============================================================================
; Macro: SHIFT_ROW
; Shifts a 40-character row left by 1 column and generates a star at column 39.
; ==============================================================================
!macro SHIFT_ROW .screen_addr, .color_addr {
    ldx #0
.shift_loop:
    lda .screen_addr + 1, x
    sta .screen_addr + 0, x
    lda .color_addr + 1, x
    sta .color_addr + 0, x
    inx
    cpx #39
    bne .shift_loop

    jsr starfield_rand
    tax
    lda g_star_prob_table, x
    sta .screen_addr + 39
    lda g_star_color_table, x
    sta .color_addr + 39
}

; ==============================================================================
; Subroutine: starfield_update
; Purpose: Shifts parallax starfield layers on alternating frames.
; ==============================================================================
starfield_update:
    inc g_starfield_frame

    ; Fast Layer: Shift every 2 frames (when Bit 0 == 0)
    lda g_starfield_frame
    and #$01
    bne @check_med
    jsr @shift_fast_rows
    rts

@check_med:
    ; Medium Layer: Shift every 4 frames (when Frame % 4 == 1)
    lda g_starfield_frame
    and #$03
    cmp #$01
    bne @check_slow
    jsr @shift_med_rows
    rts

@check_slow:
    ; Slow Layer: Shift every 8 frames (when Frame % 8 == 3)
    lda g_starfield_frame
    and #$07
    cmp #$03
    bne @done_shift
    jsr @shift_slow_rows
@done_shift:
    rts

@shift_fast_rows:
    +SHIFT_ROW $0428, $d828
    +SHIFT_ROW $04a0, $d8a0
    +SHIFT_ROW $0518, $d918
    +SHIFT_ROW $0590, $d990
    +SHIFT_ROW $0608, $da08
    +SHIFT_ROW $0680, $da80
    +SHIFT_ROW $06f8, $daf8
    +SHIFT_ROW $0770, $db70
    rts

@shift_med_rows:
    +SHIFT_ROW $0450, $d850
    +SHIFT_ROW $04c8, $d8c8
    +SHIFT_ROW $0540, $d940
    +SHIFT_ROW $05b8, $d9b8
    +SHIFT_ROW $0630, $da30
    +SHIFT_ROW $06a8, $daa8
    +SHIFT_ROW $0720, $db20
    +SHIFT_ROW $0798, $db98
    rts

@shift_slow_rows:
    +SHIFT_ROW $0478, $d878
    +SHIFT_ROW $04f0, $d8f0
    +SHIFT_ROW $0568, $d968
    +SHIFT_ROW $05e0, $d9e0
    +SHIFT_ROW $0658, $da58
    +SHIFT_ROW $06d0, $dad0
    +SHIFT_ROW $0748, $db48
    +SHIFT_ROW $07c0, $dbc0
    rts

; ==============================================================================
; Star Probability Distribution Table (256 entries)
; Characters 117 to 127 ordered from least probable to most probable:
; - 117 ($75): 1 entry  (0.39%) [Rarest 2-pixel bright star]
; - 118 ($76): 1 entry  (0.39%) [Rare 2-pixel star]
; - 119 ($77): 1 entry  (0.39%) [Rare 2-pixel star]
; - 120 ($78): 2 entries (0.78%) [Cross cluster]
; - 121 ($79): 2 entries (0.78%) [Bright 4-point star]
; - 122 ($7A): 3 entries (1.17%) [Triple dot]
; - 123 ($7B): 3 entries (1.17%) [Dual dot]
; - 124 ($7C): 4 entries (1.56%) [Dual dot]
; - 125 ($7D): 4 entries (1.56%) [Single dot]
; - 126 ($7E): 5 entries (1.95%) [Single dot]
; - 127 ($7F): 5 entries (1.95%) [Most frequent single center dot]
; -  32 ($20): 225 entries (87.89%) [Empty space / Black void]
; ==============================================================================
g_star_prob_table:
    !byte $75, $20, $7b, $20, $7d, $20, $7f, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $7a, $20, $7d, $20, $7f
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $78, $20, $7c, $20, $7e, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $76, $20, $7b
    !byte $20, $7e, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $7a, $20, $7d, $20, $7f, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $79, $20, $7c, $20, $7e, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $77, $20, $7b, $20, $7e, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $7a, $20, $7d, $20, $7f, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $79, $20
    !byte $7c, $20, $7f, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $78, $20, $7c, $20, $7e, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

; ==============================================================================
; Star Color Mapping Table (256 entries, 1-to-1 matching g_star_prob_table)
; ==============================================================================
g_star_color_table:
    !byte COLOR_WHITE, COLOR_BLACK, COLOR_LIGHT_GRAY, COLOR_BLACK, COLOR_MEDIUM_GRAY, COLOR_BLACK, COLOR_DARK_GRAY, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_LIGHT_BLUE, COLOR_BLACK, COLOR_MEDIUM_GRAY, COLOR_BLACK, COLOR_DARK_GRAY
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_WHITE, COLOR_BLACK, COLOR_LIGHT_BLUE, COLOR_BLACK, COLOR_MEDIUM_GRAY, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_CYAN, COLOR_BLACK, COLOR_LIGHT_GRAY
    !byte COLOR_BLACK, COLOR_MEDIUM_GRAY, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_LIGHT_BLUE, COLOR_BLACK, COLOR_MEDIUM_GRAY, COLOR_BLACK, COLOR_DARK_GRAY, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_YELLOW, COLOR_BLACK, COLOR_LIGHT_BLUE, COLOR_BLACK, COLOR_MEDIUM_GRAY, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_YELLOW, COLOR_BLACK, COLOR_LIGHT_GRAY, COLOR_BLACK, COLOR_MEDIUM_GRAY, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_LIGHT_BLUE, COLOR_BLACK, COLOR_MEDIUM_GRAY, COLOR_BLACK, COLOR_DARK_GRAY, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_YELLOW, COLOR_BLACK
    !byte COLOR_LIGHT_BLUE, COLOR_BLACK, COLOR_DARK_GRAY, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_WHITE, COLOR_BLACK, COLOR_LIGHT_BLUE, COLOR_BLACK, COLOR_MEDIUM_GRAY, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK
    !byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK

