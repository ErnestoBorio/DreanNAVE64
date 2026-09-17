; ==============================================================================
; MAIN.ASM - Drean NAVE 64 Main Entry Point & Core Frame Loop
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
; Output: bin/drean_nave_64.prg
; ==============================================================================

!to "bin/drean_nave_64.prg", cbm

* = $0801

; ------------------------------------------------------------------------------
; Standard Commodore 64 BASIC Header Stub: 10 SYS 2064 ($0810)
; ------------------------------------------------------------------------------
    !byte $0b, $08, $0a, $00, $9e, $32, $30, $36, $34, $00, $00, $00

; ==============================================================================
; Main Entry Point ($0810 = 2064)
; ==============================================================================
* = $0810

start:
    ; 1. Disable 6502 Maskable Interrupts during all setup
    sei

    ; Ensure standard C64 Memory Configuration ($0001 = $37: KERNAL ROM + BASIC + I/O)
    lda #$37
    sta $0001

    ; 2. Stop CIA Timers
    lda #$00
    sta CIA1_CRA
    sta CIA1_CRB
    sta CIA2_CRA
    sta CIA2_CRB

    ; 3. Disable CIA1 IRQs and CIA2 NMIs
    lda #$7f
    sta CIA1_ICR
    sta CIA2_ICR
    bit CIA1_ICR                ; Acknowledge any pending CIA1 IRQs
    bit CIA2_ICR                ; Acknowledge any pending CIA2 NMIs

    ; 4. Disable all VIC-II hardware interrupts and acknowledge flags
    lda #$00
    sta VIC_IRQ_ENABLE          ; Disable raster, sprite-sprite, sprite-bg interrupts ($D01A = 0)
    lda #$ff
    sta VIC_IRQ_FLAGS           ; Acknowledge any pending VIC-II IRQ flags ($D019 = $FF)
    bit VIC_SPR_COLL_SPR        ; Clear Sprite-Sprite collision latch ($D01E)
    bit VIC_SPR_COLL_BG         ; Clear Sprite-Background collision latch ($D01F)

    ; 5. Point RAM IRQ ($0314) and NMI ($0318) vectors to safe stubs
    lda #<safe_irq
    sta IRQ_VECTOR + 0
    lda #>safe_irq
    sta IRQ_VECTOR + 1

    lda #<safe_nmi
    sta NMI_VECTOR + 0
    lda #>safe_nmi
    sta NMI_VECTOR + 1

    ; 6. Set screen border and background to high-contrast black
    lda #COLOR_BLACK
    sta VIC_BORDER_COLOR
    sta VIC_BG_COLOR0

    ; 6. Clear Screen RAM ($0400) with space ($20) and Color RAM ($D800) with White
    ldx #0
@clear_screen_loop:
    lda #$20                    ; Space character ($20 = blank)
    sta SCREEN_RAM + 0, x
    sta SCREEN_RAM + 256, x
    sta SCREEN_RAM + 512, x
    sta SCREEN_RAM + 744, x
    lda #COLOR_WHITE
    sta COLOR_RAM + 0, x
    sta COLOR_RAM + 256, x
    sta COLOR_RAM + 512, x
    sta COLOR_RAM + 744, x
    inx
    bne @clear_screen_loop

    ; 7. Initialize all game subsystems
    jsr input_init
    jsr starfield_init
    jsr player_init
    jsr weapons_init
    jsr enemies_init
    jsr collisions_init
    jsr hud_init

; ==============================================================================
; Main 50 Hz PAL Game Loop (Hardware Vertical Blank Synchronization)
; ==============================================================================
main_loop:
    ; Synchronize to the start of Vertical Blank (Scanline 256 / Bottom Border)
    ; Step 1: Wait for any remaining VBLANK/bottom border lines (256..311) from previous frame to wrap
@wait_top:
    lda VIC_CTRL1
    bmi @wait_top       ; Loop while Bit 7 = 1 (lines 256..311)

    ; Step 2: Wait until raster reaches line 256 (Bit 7 becomes 1, bottom border start)
@wait_bottom:
    lda VIC_CTRL1
    bpl @wait_bottom    ; Loop while Bit 7 = 0 (lines 0..255)

    ; 2. Read & Update Input
    jsr input_update

    ; 3. Update Game Entities & World Motion
    jsr player_update
    jsr weapons_update
    jsr starfield_update
    jsr enemies_update
    jsr collisions_check
    jsr hud_update

    ; 4. Render Graphics & Hardware Sprites
    jsr player_render
    jsr weapons_render
    jsr enemies_render
    jsr hud_render

    jmp main_loop

; ==============================================================================
; Safe Interrupt Handlers
; ==============================================================================
; safe_irq: Handled via RAM vector ($0314). Kernal $FF48 entry automatically pushes
; A, X, Y onto stack before calling ($0314). We must pull Y, X, A to keep stack
; perfectly balanced before RTI.
safe_irq:
    pla
    tay
    pla
    tax
    pla
    rti

; safe_nmi: Handled via RAM vector ($0318). Kernal $FE43 jumps directly to ($0318)
; without pushing registers. We acknowledge CIA2 ICR ($DD0D) and return via RTI.
safe_nmi:
    bit CIA2_ICR
    rti

; ==============================================================================
; Include Subsystem Assembly Source Files
; ==============================================================================
!src "src/c64_hardware.asm"
!src "src/sprites_data.asm"
!src "src/charset_data.asm"
!src "src/input.asm"
!src "src/player.asm"
!src "src/weapons.asm"
!src "src/starfield.asm"
!src "src/enemies.asm"
!src "src/collisions.asm"
!src "src/hud.asm"
