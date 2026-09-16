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

    ; 4. Point RAM NMI vector ($0318) to a safe RTI stub (prevents RESTORE crashes)
    lda #<nmi_isr
    sta NMI_VECTOR + 0
    lda #>nmi_isr
    sta NMI_VECTOR + 1

    ; 5. Set screen border and background to high-contrast black
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
; Main 50 Hz PAL Game Loop (Hardware Scanline 240 VBLANK Synchronization)
; ==============================================================================
main_loop:
    ; 1. Synchronize to VIC-II scanline 240 (Beginning of VBLANK period)
@wait_vblank:
    lda VIC_RASTER
    cmp #240
    bne @wait_vblank
@wait_line_end:
    lda VIC_RASTER
    cmp #240
    beq @wait_line_end

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
; Safe NMI Interrupt Handler (Safely ignores RESTORE key and CIA2 NMIs)
; ==============================================================================
nmi_isr:
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
