; ==============================================================================
; STARFIELD.ASM - High-Speed Arcade Parallax Starfield Subsystem
; ==============================================================================
; Manages 40x25 text-mode starfield scrolling (4 pixels per frame), custom charset
; memory setup ($2800), fine scroll hardware register ($D016), and 16-bit Galois
; LFSR pseudo-random star generator with weighted probability distribution.
; ==============================================================================

CHARSET_RAM_ADDR = $2800        ; Custom charset location in VIC-II RAM bank 0

; ------------------------------------------------------------------------------
; Starfield Weighted Frequency Table (64 entries)
; ------------------------------------------------------------------------------
g_star_weighted_table:
    ; Tier 1 - Most frequent (Chars $7E & $7F, 32 entries / 50%)
    !byte $7e, $7e, $7e, $7e, $7e, $7e, $7e, $7e, $7e, $7e, $7e, $7e, $7e, $7e, $7e, $7e
    !byte $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f, $7f
    ; Tier 2 - Medium-high frequency (Chars $7B, $7C, $7D, 18 entries / 28.1%)
    !byte $7b, $7b, $7b, $7b, $7b, $7b
    !byte $7c, $7c, $7c, $7c, $7c, $7c
    !byte $7d, $7d, $7d, $7d, $7d, $7d
    ; Tier 3 - Medium-low frequency (Chars $75, $76, $77, $7A, 12 entries / 18.75%)
    !byte $75, $75, $75
    !byte $76, $76, $76
    !byte $77, $77, $77
    !byte $7a, $7a, $7a
    ; Tier 4 - Lowest frequency (Chars $78, $79, 2 entries / 3.125%)
    !byte $78, $79

; ------------------------------------------------------------------------------
; Starfield RAM Variables
; ------------------------------------------------------------------------------
g_xscroll:       !byte 7        ; Fine scroll X-offset (7..0)
g_scroll_speed:  !byte 4        ; Scroll speed (4 pixels per frame)
g_lfsr16:        !word $ace1    ; 16-bit Galois LFSR state variable

; ==============================================================================
; Subroutine: starfield_init
; Purpose: Copies custom charset to RAM ($2800), configures $D018 / $D016, and
;          populates initial Screen RAM ($0400) and Color RAM ($D800).
; ==============================================================================
starfield_init:
    ; 1. Copy 2048 bytes of g_custom_charset into RAM at $2800
    ; Using 8 pages of 256 bytes (8 * 256 = 2048)
    lda #<g_custom_charset
    sta $fb
    lda #>g_custom_charset
    sta $fc

    lda #<$2800
    sta $fd
    lda #>$2800
    sta $fe

    ldy #0
    ldx #8                      ; 8 pages of 256 bytes
@copy_page_loop:
    lda ($fb), y
    sta ($fd), y
    iny
    bne @copy_page_loop

    inc $fc                     ; Advance source page
    inc $fe                     ; Advance destination page
    dex
    bne @copy_page_loop

    ; 2. Configure VIC-II Memory Setup ($D018): Screen RAM @ $0400, Charset RAM @ $2800 ($1A)
    lda #$1a
    sta VIC_MEM_SETUP

    ; 3. Initialize fine scroll position (7) & enable 38-column window mode in VIC_CTRL2 ($D016)
    lda #7
    sta g_xscroll
    lda #4
    sta g_scroll_speed

    lda VIC_CTRL2
    and #$f0
    ora #$07
    sta VIC_CTRL2

    ; 4. Clear Screen RAM ($0400) with white text color and initial star distribution
    lda #$ace1 & $ff
    sta g_lfsr16
    lda #($ace1 >> 8) & $ff
    sta g_lfsr16 + 1

    ; Set Color RAM ($D800..$DBE7) to White (1)
    ldx #0
@color_loop:
    lda #COLOR_WHITE
    sta COLOR_RAM + 0, x
    sta COLOR_RAM + 256, x
    sta COLOR_RAM + 512, x
    sta COLOR_RAM + 744, x
    inx
    bne @color_loop

    ; Populate Screen RAM rows (25 rows x 40 cols)
    lda #<$0400
    sta $fb
    lda #>$0400
    sta $fc

    ldx #0                      ; Row counter (0..24)
@row_init_loop:
    ldy #0                      ; Column counter (0..39)
@col_init_loop:
    txa
    pha
    tya
    pha
    txa                         ; Pass row index in A
    jsr get_next_star           ; Returns char code in A
    sta $02                     ; Save generated star char
    pla
    tay
    pla
    tax

    lda $02
    sta ($fb), y
    iny
    cpy #40
    bne @col_init_loop

    ; Advance pointer by 40 bytes (1 row)
    lda $fb
    clc
    adc #40
    sta $fb
    lda $fc
    adc #0
    sta $fc

    inx
    cpx #25
    bne @row_init_loop
    rts

; ==============================================================================
; Subroutine: get_next_star
; Input:  A = Row index (0..24)
; Output: A = Selected star character code (or $20 space for blank background)
; ==============================================================================
get_next_star:
    sta $03                     ; Save row index in $03

    ; 16-bit Galois LFSR pseudo-random generator
    lda g_lfsr16
    lsr                         ; Shift LSB into Carry
    ror g_lfsr16 + 1
    ror g_lfsr16
    bcc +
    ; Feedback polynomial XOR $B400
    lda g_lfsr16 + 1
    eor #$b4
    sta g_lfsr16 + 1
+
    ; Inject spatial row variance: val = g_lfsr16 ^ (row * 0x45 + 0x17)
    lda $03
    sta $04
    asl $04                     ; row * 2
    asl $04                     ; row * 4
    asl $04                     ; row * 8
    asl $04                     ; row * 16
    asl $04                     ; row * 32
    clc
    adc $04                     ; row + (row * 32)
    clc
    adc #$17
    eor g_lfsr16

    ; Spawning density check: ~3.1% chance ((val & 0x1F) == 0)
    and #$1f
    bne @spawn_space

    ; Select star character from 64-entry weighted table using bits 5..10
    lda g_lfsr16
    lsr
    lsr
    lsr
    and #$3f                    ; 64-entry table index mask ($3F)
    tax
    lda g_star_weighted_table, x
    rts

@spawn_space:
    lda #$20                    ; Space character ($20 = blank)
    rts

; ==============================================================================
; Subroutine: starfield_update
; Purpose: Advances fine scroll position by g_scroll_speed. When fine scroll
;          underflows below 0, shifts Screen RAM ($0400) 1 column left.
; ==============================================================================
starfield_update:
    ; Check if upcoming scroll step will underflow below 0 (g_xscroll < g_scroll_speed)
    lda g_xscroll
    cmp g_scroll_speed
    bcs @no_screen_shift

    ; Shift SCREEN_RAM ($0400) 1 column left BEFORE fine scroll wraps around 8
    ; Loop 25 rows: copy cols 1..39 to 0..38, and generate new star for col 39
    lda #<$0400
    sta $fb                     ; Destination pointer (col 0)
    lda #>$0400
    sta $fc

    lda #<$0401
    sta $fd                     ; Source pointer (col 1)
    lda #>$0401
    sta $fe

    ldx #0                      ; Row counter (0..24)
@row_shift_loop:
    ldy #0                      ; Column counter (0..38)
@col_shift_loop:
    lda ($fd), y                ; Read char from col 1..39
    sta ($fb), y                ; Write char to col 0..38
    iny
    cpy #39
    bne @col_shift_loop

    ; Generate new star character for col 39 at end of row
    txa
    pha
    txa                         ; Pass row index in A
    jsr get_next_star
    sta $02
    pla
    tax

    lda $02
    ldy #39
    sta ($fb), y                ; Write new star at col 39

    ; Advance destination and source pointers by 40 bytes (1 row)
    lda $fb
    clc
    adc #40
    sta $fb
    lda $fc
    adc #0
    sta $fc

    lda $fd
    clc
    adc #40
    sta $fd
    lda $fe
    adc #0
    sta $fe

    inx
    cpx #25
    bne @row_shift_loop

    ; Fine scroll wraps around +8
    lda g_xscroll
    clc
    adc #8
    sta g_xscroll

@no_screen_shift:
    ; Advance fine scroll position by g_scroll_speed
    lda g_xscroll
    sec
    sbc g_scroll_speed
    sta g_xscroll

    ; Write VIC_CTRL2 ($D016) immediately in VBLANK (100% synchronized)
    lda VIC_CTRL2
    and #$f0
    ora g_xscroll
    sta VIC_CTRL2
    rts
