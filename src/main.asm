; ==============================================================================
; MAIN.ASM - Drean NAVE 64 Main Entry Point & Hardware Raster IRQ Loop
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
    ; 1. Disable 6502 Maskable Interrupts during hardware setup
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

    ; 4. Point RAM NMI vector ($0318) to Kernal NMI exit routine ($FEBC) to safely restore registers
    lda #$bc
    sta NMI_VECTOR + 0
    lda #$fe
    sta NMI_VECTOR + 1

    ; 5. Configure VIC-II Hardware Raster Interrupt at scanline 240 (Start of VBLANK)
    lda VIC_CTRL1
    and #$7f                    ; Clear Bit 7 (Raster Bit 8 = 0 for line 240)
    sta VIC_CTRL1

    lda #240                    ; Scanline 240
    sta VIC_RASTER

    ; Enable VIC-II Raster Interrupts ($D01A)
    lda #$01
    sta VIC_IRQ_ENABLE

    ; Point Hardware IRQ Vector ($0314) to our custom raster_isr routine
    lda #<raster_isr
    sta IRQ_VECTOR + 0
    lda #>raster_isr
    sta IRQ_VECTOR + 1

    ; 6. Re-enable 6502 Maskable Interrupts
    cli

    ; 7. Set screen border and background to high-contrast black
    lda #COLOR_BLACK
    sta VIC_BORDER_COLOR
    sta VIC_BG_COLOR0

    ; 8. Initialize all game subsystems
    jsr input_init
    jsr starfield_init
    jsr player_init
    jsr weapons_init
    jsr enemies_init
    jsr collisions_init
    jsr hud_init

    ; Flag indicating VBLANK raster IRQ occurred (1 = process frame)
    lda #0
    sta g_vsync_flag

; ==============================================================================
; Main 50 Hz Game Loop
; ==============================================================================
main_loop:
    ; Wait for hardware Raster IRQ to set g_vsync_flag = 1
    lda g_vsync_flag
    beq main_loop

    ; Clear vsync flag for next frame
    lda #0
    sta g_vsync_flag

    ; 1. Read & Update Input (Joystick 2, R-D-F-G, U-H-J-K, Left/Right Shift, Spacebar)
    jsr input_update

    ; 2. Update Game Entities & World Motion
    jsr player_update
    jsr weapons_update
    jsr starfield_update
    jsr enemies_update
    jsr collisions_check
    jsr hud_update

    ; 3. Render Graphics & Hardware Sprites
    jsr player_render
    jsr weapons_render
    jsr enemies_render
    jsr hud_render

    jmp main_loop

; ==============================================================================
; Hardware Interrupt Service Routine: raster_isr
; ==============================================================================
; Fires automatically at VIC-II scanline 240 (50 times per second on PAL C64).
; Sets g_vsync_flag = 1 and acknowledges the VIC-II interrupt.
; ==============================================================================
g_vsync_flag: !byte 0

raster_isr:
    pha                         ; Save Accumulator on stack
    txa
    pha                         ; Save X register on stack
    tya
    pha                         ; Save Y register on stack

    ; Check if VIC-II Raster IRQ triggered
    lda VIC_IRQ_FLAGS
    and #$01
    beq @exit_isr

    ; Set vsync flag to signal main loop
    lda #1
    sta g_vsync_flag

    ; Acknowledge VIC-II Raster Interrupt by writing 1 to Bit 0 of $D019
    lda #$01
    sta VIC_IRQ_FLAGS

@exit_isr:
    pla
    tay                         ; Restore Y register from stack
    pla
    tax                         ; Restore X register from stack
    pla                         ; Restore Accumulator from stack
    jmp $ea31                    ; Return via Kernal IRQ handler / RTI

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
