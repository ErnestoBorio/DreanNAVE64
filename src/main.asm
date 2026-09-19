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

    ; 5. Point RAM IRQ ($0314) and NMI ($0318) vectors
    lda #<raster_irq
    sta IRQ_VECTOR + 0
    lda #>raster_irq
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
    jsr game_timer_init
    jsr input_init
    jsr starfield_init
    jsr player_init
    jsr weapons_init
    jsr enemies_init
    jsr collisions_init
    jsr powerups_init
    jsr hud_init

    ; 8. Setup VIC-II Raster Interrupt for 3-lane enemy multiplexer
    sei                         ; Ensure interrupts are masked during setup

    ; Point Hardware IRQ Vector ($0314) to raster_irq
    lda #<raster_irq
    sta IRQ_VECTOR + 0
    lda #>raster_irq
    sta IRQ_VECTOR + 1

    ; Configure VIC-II Raster IRQ
    lda VIC_CTRL1
    and #$7f                    ; Clear raster compare line bit 8 (Line 0 < 256)
    sta VIC_CTRL1

    lda #0                      ; First raster trigger at scanline 0 (Top border)
    sta VIC_RASTER

    lda #$01
    sta VIC_IRQ_ENABLE          ; Enable VIC-II Raster IRQ ($D01A Bit 0 = 1)

    lda #$ff
    sta VIC_IRQ_FLAGS           ; Acknowledge any pending VIC-II IRQ flags

    cli                         ; Enable 6502 maskable interrupts

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

    ; 3. Update Game Elapsed Time Counter (50 Hz PAL)
    jsr game_timer_update

    ; 4. Update Game Entities & World Motion
    jsr player_update
    jsr weapons_update
    jsr starfield_update
    jsr powerups_update
    jsr enemies_update
    jsr collisions_check
    jsr collisions_check_player
    jsr powerups_check_collision
    jsr hud_update

    ; 4. Render Graphics & Hardware Sprites
    jsr player_render
    jsr weapons_render
    jsr enemies_render
    jsr hud_render

    jmp main_loop

; ==============================================================================
; Raster Interrupt Handler: Dynamic Y-Sorted Sprite Multiplexer
; ==============================================================================
; Called via KERNAL IRQ vector ($0314). Kernal $FF48 entry automatically pushes
; A, X, Y onto stack before calling ($0314).
; Dynamically re-arms Hardware Sprites 2..7 at each sprite scanline completion.
; ==============================================================================
raster_irq:
    ; Verify that interrupt was generated by VIC-II Raster IRQ
    lda VIC_IRQ_FLAGS
    and #$01
    beq @not_vic_raster

    ; Acknowledge VIC-II Raster IRQ
    lda #$01
    sta VIC_IRQ_FLAGS

    ; Execute dynamic multiplexer IRQ step
    jsr multiplexer_irq_step

@irq_exit:
@not_vic_raster:
    ; Pull registers pushed by KERNAL ($FF48 entry) and return
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
; Subroutine: game_timer_init
; Purpose: Resets frame counter and elapsed time registers at game start.
; ==============================================================================
game_timer_init:
    lda #0
    sta g_game_time_frames
    sta g_game_time_sec
    sta g_game_time_min
    sta g_game_time_total_sec + 0
    sta g_game_time_total_sec + 1
    rts

; ==============================================================================
; Subroutine: game_timer_update
; Purpose: Advances 50 Hz PAL frame counter and updates elapsed MM:SS / total seconds.
; ==============================================================================
game_timer_update:
    inc g_game_time_frames
    lda g_game_time_frames
    cmp #50                     ; 50 frames = 1 second in PAL (50 Hz)
    bne @timer_done
    lda #0
    sta g_game_time_frames

    ; Increment 16-bit total elapsed seconds
    inc g_game_time_total_sec + 0
    bne +
    inc g_game_time_total_sec + 1

+   ; Increment seconds (0..59)
    inc g_game_time_sec
    lda g_game_time_sec
    cmp #60
    bne @timer_done
    lda #0
    sta g_game_time_sec

    ; Increment minutes (0..255)
    inc g_game_time_min

@timer_done:
    rts

; ------------------------------------------------------------------------------
; Game Elapsed Time State Variables
; ------------------------------------------------------------------------------
g_game_time_frames:     !byte 0 ; Current second frame fraction (0..49)
g_game_time_sec:        !byte 0 ; Elapsed seconds of current minute (0..59)
g_game_time_min:        !byte 0 ; Elapsed minutes of current session (0..255)
g_game_time_total_sec:  !word 0 ; Total elapsed seconds (0..65535, ~18.2 hours)

; ==============================================================================
; Include Subsystem Assembly Source Files
; ==============================================================================
!src "src/c64_hardware.asm"
!src "src/input.asm"
!src "src/player.asm"
!src "src/weapons.asm"
!src "src/starfield.asm"
!src "src/powerups.asm"
!src "src/enemies.asm"
!src "src/collisions.asm"
!src "src/hud.asm"

; Assert that all executable code and variables fit safely below Charset RAM ($2800)
!if * > $2800 {
    !error "Fatal: Code exceeded $2800! Charset RAM collision."
}

; ------------------------------------------------------------------------------
; VIC-II Custom Starfield Charset Data (2,048 bytes: $2800 - $2FFF)
; ------------------------------------------------------------------------------
* = $2800
!src "src/charset_data.asm"

; Assert that charset data fits safely below Sprite RAM ($3000)
!if * > $3000 {
    !error "Fatal: Charset data exceeded $3000! Sprite RAM collision."
}

; ------------------------------------------------------------------------------
; VIC-II Hardware Sprite Data (20 blocks x 64 bytes = 1,280 bytes: $3000 - $34FF)
; ------------------------------------------------------------------------------
* = $3000
!src "src/sprites_data.asm"

; Assert that all sprite data fits safely within VIC Bank 0 ($3800)
!if * > $3800 {
    !error "Fatal: Sprite data exceeded $3800! Bank 0 collision."
}

