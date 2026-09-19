; ==============================================================================
; PLAYER.ASM - Player Ship Entity & Hardware Sprite Subsystem (Phase 2)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
;
; Manages the player ship state, 8-way directional motion, screen boundary
; clamping, and VIC-II Hardware Sprite 0 configuration in multicolor mode.
; ==============================================================================

PLAYER_SPRITE_BLOCK = 192       ; Base sprite block in VIC-II RAM ($3000 / 64 = 192)
PLAYER_SPEED        = 3         ; Player movement speed (pixels per frame at 50 Hz PAL)

; ------------------------------------------------------------------------------
; Player Entity Data RAM Variables
; ------------------------------------------------------------------------------
g_player_x:         !word 60    ; 16-bit X coordinate in VIC-II raster space (24..320)
g_player_y:         !byte 120   ; 8-bit Y coordinate in VIC-II raster space (50..240)
g_player_alive:     !byte 1     ; Player life state (1 = Alive, 0 = Destroyed)
g_player_exploding: !byte 0     ; Player explosion countdown timer (0 = Inactive)
g_player_phase:     !byte 1     ; Ship evolution phase (1..5, starts at 1)
g_player_hp:        !byte 5     ; Player health points in Phase 1 (0..5, starts at 5)
g_player_invuln_timer: !byte 0  ; Invulnerability frames remaining (0 = vulnerable)

; ==============================================================================
; Subroutine: player_init
; Purpose: Initializes player state, copies sprite data to VIC-II RAM ($3000),
;          and configures VIC-II Hardware Sprite 0 registers.
; ==============================================================================
player_init:
    ; 1. Initialize player state variables
    lda #0
    sta g_player_x + 1
    sta g_player_invuln_timer
    sta g_player_exploding
    lda #60
    sta g_player_x + 0
    lda #120
    sta g_player_y
    lda #1
    sta g_player_alive
    sta g_player_phase
    lda #5
    sta g_player_hp

    ; 2. Set Sprite 0 pointer at $07F8 to point to Player Ship Stage 1 (Block 192)
    ;    (Sprite data is assembled directly at VIC-II Sprite RAM $3000 - $34FF)
    lda #PLAYER_SPRITE_BLOCK
    sta SPRITE_PTRS + 0

    ; 4. Enable Hardware Sprite 0 in VIC-II ($D015)
    lda VIC_SPR_ENABLE
    ora #$01
    sta VIC_SPR_ENABLE

    ; 5. Enable Multicolor mode for Sprite 0 ($D01C)
    lda VIC_SPR_MULTICOLOR
    ora #$01
    sta VIC_SPR_MULTICOLOR

    ; 6. Disable X and Y expansion for Sprite 0 ($D017, $D01D)
    lda VIC_SPR_EXP_X
    and #$fe
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    and #$fe
    sta VIC_SPR_EXP_Y

    ; 7. Set Sprite 0 priority in front of background ($D01B)
    lda VIC_SPR_PRIORITY
    and #$fe
    sta VIC_SPR_PRIORITY

    ; 8. Configure VIC-II Sprite Colors:
    ;    %10 (Individual Color) = Cyan ($03)
    ;    %01 (Shared MC0 Color) = White ($01)
    ;    %11 (Shared MC1 Color) = Medium Gray ($0C)
    lda #COLOR_CYAN
    sta VIC_SPR0_COLOR
    lda #COLOR_WHITE
    sta VIC_SPR_MC0
    lda #COLOR_MEDIUM_GRAY
    sta VIC_SPR_MC1

    rts

; ==============================================================================
; Subroutine: player_update
; Purpose: Applies 8-way directional input vectors to player coordinates
;          and enforces strict playfield screen boundaries.
; ==============================================================================
player_update:
    ; If player is dead, update explosion countdown and skip motion
    lda g_player_alive
    bne +
    lda g_player_exploding
    beq @dead_done
    dec g_player_exploding
@dead_done:
    rts
+
    ; Decrement invulnerability countdown
    lda g_player_invuln_timer
    beq +
    dec g_player_invuln_timer
+
    ; Movement speed: PLAYER_SPEED pixels per frame (smooth 50 Hz arcade motion)

    ; --------------------------------------------------------------------------
    ; Check Move Up (Y decrements towards top border: SPRITE_MIN_Y = 50)
    ; --------------------------------------------------------------------------
    lda g_input_up
    beq @check_down
    lda g_player_y
    sec
    sbc #PLAYER_SPEED
    cmp #SPRITE_MIN_Y
    bcs +
    lda #SPRITE_MIN_Y           ; Clamp to top visible border
+   sta g_player_y

@check_down:
    ; --------------------------------------------------------------------------
    ; Check Move Down (Y increments towards bottom border: clamped by phase)
    ; --------------------------------------------------------------------------
    lda g_input_down
    beq @check_left
    lda g_player_y
    clc
    adc #PLAYER_SPEED
    ldx g_player_phase
    dex
    cmp player_max_y_table, x
    bcc +
    lda player_max_y_table, x   ; Clamp to bottom visible border
+   sta g_player_y

@check_left:
    ; --------------------------------------------------------------------------
    ; Check Move Left (16-bit X decrements towards left border: SPRITE_MIN_X = 24)
    ; --------------------------------------------------------------------------
    lda g_input_left
    beq @check_right
    lda g_player_x + 0
    sec
    sbc #PLAYER_SPEED
    sta g_player_x + 0
    lda g_player_x + 1
    sbc #0
    sta g_player_x + 1

    ; Clamp to left boundary: if MSB == 0 and LSB < 24, clamp to 24
    lda g_player_x + 1
    bne @check_right            ; If MSB > 0, X >= 256 (safe)
    lda g_player_x + 0
    cmp #SPRITE_MIN_X
    bcs @check_right
    lda #SPRITE_MIN_X
    sta g_player_x + 0
    lda #0
    sta g_player_x + 1

@check_right:
    ; --------------------------------------------------------------------------
    ; Check Move Right (16-bit X increments towards right border: clamped by phase)
    ; --------------------------------------------------------------------------
    lda g_input_right
    beq @update_done
    lda g_player_x + 0
    clc
    adc #PLAYER_SPEED
    sta g_player_x + 0
    lda g_player_x + 1
    adc #0
    sta g_player_x + 1

    ; Clamp to right boundary
    lda g_player_x + 1
    cmp #1
    bcc @update_done            ; If MSB == 0, X < 256 (safe)
    ldx g_player_phase
    dex
    lda g_player_x + 0
    cmp player_max_x_lo_table, x
    bcc @update_done
    lda player_max_x_lo_table, x
    sta g_player_x + 0
    lda #1
    sta g_player_x + 1

@update_done:
    rts

; ==============================================================================
; Subroutine: player_render
; Purpose: Updates Sprite 0 hardware registers (X, Y, MSB, Pointer, Scaling).
; ==============================================================================
player_render:
    ; 1. Check player life state
    lda g_player_alive
    bne @check_flicker

    ; Player dead: check if currently exploding
    lda g_player_exploding
    beq @player_hidden

    ; --- Player Death Explosion Rendering ---
    sei
    ; Ensure Hardware Sprite 0 is enabled
    lda VIC_SPR_ENABLE
    ora #$01
    sta VIC_SPR_ENABLE

    ; Switch Sprite 0 to Hi-Res Monochrome for explosion frames
    lda VIC_SPR_MULTICOLOR
    and #$fe
    sta VIC_SPR_MULTICOLOR

    ; Ensure Sprite 0 is unscaled
    lda VIC_SPR_EXP_X
    and #$fe
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    and #$fe
    sta VIC_SPR_EXP_Y
    cli

    ; Select explosion frame: 24 frames total (8 frames per explosion frame)
    lda #SPRITE_PTR_EXPLOSION_1
    ldx g_player_exploding
    cpx #16
    bcs +
    lda #SPRITE_PTR_EXPLOSION_2
    cpx #8
    bcs +
    lda #SPRITE_PTR_EXPLOSION_3
+   sta SPRITE_PTRS + 0

    ; Cycle energy color one per frame during explosion
    ldx g_energy_cycle_idx
    lda g_energy_colors, x
    sta VIC_SPR0_COLOR

    ; Anchor explosion at the exact coordinates where player died
    jmp @write_coords

@player_hidden:
    ; Player destroyed and explosion finished: disable Hardware Sprite 0
    sei
    lda VIC_SPR_ENABLE
    and #$fe
    sta VIC_SPR_ENABLE
    cli
    rts

@check_flicker:
    ; Invulnerability flicker (blinks off every 2 frames)
    lda g_player_invuln_timer
    beq @render_active
    and #$02
    beq @render_active

    ; Blink off this frame
    sei
    lda VIC_SPR_ENABLE
    and #$fe
    sta VIC_SPR_ENABLE
    cli
    rts

@render_active:
    ; Ensure Hardware Sprite 0 is enabled and in Multicolor mode
    sei
    lda VIC_SPR_ENABLE
    ora #$01
    sta VIC_SPR_ENABLE
    lda VIC_SPR_MULTICOLOR
    ora #$01
    sta VIC_SPR_MULTICOLOR
    cli

    ; Restore Sprite 0 Individual Color (Cyan)
    lda #COLOR_CYAN
    sta VIC_SPR0_COLOR

    ; 2. Select Sprite 0 Pointer based on player phase (1..5 -> 0..4)
    ldx g_player_phase
    dex
    lda player_phase_ship_sprite, x
    sta SPRITE_PTRS + 0

    ; 3. Configure Hardware Scaling (X/Y Expansion) for Sprite 0
    lda player_phase_scaled, x
    beq @unscaled_ship

    sei
    lda VIC_SPR_EXP_X
    ora #$01
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    ora #$01
    sta VIC_SPR_EXP_Y
    cli
    jmp @write_coords

@unscaled_ship:
    sei
    lda VIC_SPR_EXP_X
    and #$fe
    sta VIC_SPR_EXP_X
    lda VIC_SPR_EXP_Y
    and #$fe
    sta VIC_SPR_EXP_Y
    cli

@write_coords:
    ; 4. Write X coordinate low byte to VIC-II Sprite 0 X Register ($D000)
    lda g_player_x + 0
    sta VIC_SPR0_X

    ; 5. Write Y coordinate byte to VIC-II Sprite 0 Y Register ($D001)
    lda g_player_y
    sta VIC_SPR0_Y

    ; 6. Set or clear Bit 0 of VIC_SPR_MSB ($D010) based on 16-bit X MSB
    lda g_player_x + 1
    beq @clear_msb

    ; Set Bit 0 (X >= 256)
    sei
    lda VIC_SPR_MSB
    ora #$01
    sta VIC_SPR_MSB
    cli
    rts

@clear_msb:
    ; Clear Bit 0 (X < 256)
    sei
    lda VIC_SPR_MSB
    and #$fe
    sta VIC_SPR_MSB
    cli
    rts

; ------------------------------------------------------------------------------
; Player Phase Evolution Tables (Phases 1..5)
; ------------------------------------------------------------------------------
player_phase_ship_sprite:
    !byte SPRITE_PTR_PLAYER_SHIP_1 ; Phase 1: Sprite 1 (Block 192)
    !byte SPRITE_PTR_PLAYER_SHIP_2 ; Phase 2: Sprite 2 (Block 193)
    !byte SPRITE_PTR_PLAYER_SHIP_3 ; Phase 3: Sprite 3 (Block 194)
    !byte SPRITE_PTR_PLAYER_SHIP_2 ; Phase 4: Sprite 2 (Block 193) Scaled
    !byte SPRITE_PTR_PLAYER_SHIP_3 ; Phase 5: Sprite 3 (Block 194) Scaled

player_phase_shot_sprite:
    !byte SPRITE_PTR_PLAYER_SHOT_1 ; Phase 1: Sprite 12 (Block 203)
    !byte SPRITE_PTR_PLAYER_SHOT_2 ; Phase 2: Sprite 13 (Block 204)
    !byte SPRITE_PTR_PLAYER_SHOT_3 ; Phase 3: Sprite 14 (Block 205)
    !byte SPRITE_PTR_PLAYER_SHOT_2 ; Phase 4: Sprite 13 (Block 204) Scaled
    !byte SPRITE_PTR_PLAYER_SHOT_3 ; Phase 5: Sprite 14 (Block 205) Scaled

player_phase_scaled:
    !byte 0, 0, 0, 1, 1            ; 0 = Normal 24x21, 1 = 2x Expanded (48x42)

player_max_y_table:
    !byte 240, 240, 240, 218, 218

player_max_x_lo_table:
    !byte 64,  64,  64,  40,  40

