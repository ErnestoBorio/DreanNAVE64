; ==============================================================================
; STARFIELD.ASM - High-Speed Multi-Layer Parallax Starfield Subsystem (Phase 4)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
; 
; Features:
; - 2048-byte custom character set loaded to VIC-II RAM at $2800-$2FFF
; - VIC-II memory configuration ($D018 = $1A: Screen $0400, Charset $2800)
; - Sparse star density (~4.7% = ~40 stars across 960 playfield characters)
; - User-specified star character hierarchy (Chars 117-127, rare to frequent)
; - Dynamic randomized White & Gray shades (White, Light Gray, Med Gray, Dark Gray)
; - 16-bit Galois LFSR pseudo-random generator (65,535 cycle period)
; - 3-layer parallax row shifting (Fast: every 2 frames, Med: every 4, Slow: every 8)
; ==============================================================================

; ------------------------------------------------------------------------------
; Starfield RAM State Variables
; ------------------------------------------------------------------------------
g_starfield_frame:  !byte 0   ; Frame counter for multi-speed parallax cadence
s_lfsr_lo:          !byte $ac ; 16-bit Galois LFSR low byte
s_lfsr_hi:          !byte $e1 ; 16-bit Galois LFSR high byte

; ------------------------------------------------------------------------------
; Star Gray & White Palette Shades (4 shades)
; ------------------------------------------------------------------------------
g_star_gray_shades:
    !byte COLOR_DARK_GRAY     ; 11 ($0B) - Faint distant star
    !byte COLOR_MEDIUM_GRAY   ; 12 ($0C) - Mid-distance star
    !byte COLOR_LIGHT_GRAY    ; 15 ($0F) - Bright near star
    !byte COLOR_WHITE         ; 1  ($01) - Brilliant foreground star

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
; Subroutine: starfield_gen_star
; Purpose: Generates a random star tile with random White or Gray shade.
; Returns: Character code in A, Color RAM value in Y.
; ==============================================================================
starfield_gen_star:
    jsr starfield_rand
    tax
    lda g_star_prob_table, x
    cmp #32             ; Empty space ($20)?
    beq .is_space

    ; It IS a star (Chars 117-127): select random White or Gray shade
    ldy s_lfsr_hi
    tya
    and #$03            ; 2 random bits -> index 0..3
    tay
    lda g_star_gray_shades, y
    tay                 ; Y = random shade (Dark Gray, Med Gray, Light Gray, White)
    lda g_star_prob_table, x ; A = star character code (117..127)
    rts

.is_space:
    ldy #COLOR_BLACK    ; Empty space color is black
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
    jsr starfield_gen_star
    sta $0428, x
    tya
    sta $d828, x
    inx
    bne @seed_page0

    ; Page 2 of playfield: $0528 to $0627 (256 bytes)
@seed_page1:
    jsr starfield_gen_star
    sta $0528, x
    tya
    sta $d928, x
    inx
    bne @seed_page1

    ; Page 3 of playfield: $0628 to $0727 (256 bytes)
@seed_page2:
    jsr starfield_gen_star
    sta $0628, x
    tya
    sta $da28, x
    inx
    bne @seed_page2

    ; Remaining 192 bytes of playfield: $0728 to $07E7
@seed_page3:
    jsr starfield_gen_star
    sta $0728, x
    tya
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

    jsr starfield_gen_star
    sta .screen_addr + 39
    tya
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
; Sparse density (~4.7% stars, 95.3% empty space).
; Characters 117 to 127 ordered from least probable to most probable:
; - 117 ($75): 1 entry  (0.39%) [Rarest 2-pixel bright star]
; - 118 ($76): 1 entry  (0.39%) [Rare 2-pixel star]
; - 119 ($77): 1 entry  (0.39%) [Rare 2-pixel star]
; - 120 ($78): 1 entry  (0.39%) [Cross cluster]
; - 121 ($79): 1 entry  (0.39%) [Bright 4-point star]
; - 122 ($7A): 1 entry  (0.39%) [Triple dot]
; - 123 ($7B): 1 entry  (0.39%) [Dual dot]
; - 124 ($7C): 1 entry  (0.39%) [Dual dot]
; - 125 ($7D): 1 entry  (0.39%) [Single dot]
; - 126 ($7E): 1 entry  (0.39%) [Single dot]
; - 127 ($7F): 2 entries (0.78%) [Most frequent single center dot]
; -  32 ($20): 244 entries (95.31%) [Empty space / Black void]
; ==============================================================================
g_star_prob_table:
    !byte $75, $20, $7f, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $7c, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $79, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $76, $20, $7f
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $7d, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $7a, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $77, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $7e, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $7b, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $78, $20, $20, $20, $20, $20, $20, $20, $20
    !byte $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20

