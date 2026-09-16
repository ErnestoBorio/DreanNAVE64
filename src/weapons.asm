; ==============================================================================
; WEAPONS.ASM - Player Missile & Energy Color Palette Cycling Subsystem
; ==============================================================================
; Handles player missile firing, latched single-shot fire requests, ultra-high
; speed rightward movement (50 pixels per frame), playfield border recycling
; (x >= 320), 7-color Energy palette cycling sequence, and VIC-II Sprite 1 rendering.
; ==============================================================================

MAX_PLAYER_MISSILES = 1         ; Single active player missile slot
SHOT_SPRITE_BLOCK   = 138       ; Block 138 ($2280 / 64 = 138)
NUM_ENERGY_COLORS   = 7         ; 7-color Energy Palette sequence

; ------------------------------------------------------------------------------
; Energy Color Palette Sequence (Cyan, Pink, Yellow, Dark Green, Light Green, Light Blue, Light Gray)
; ------------------------------------------------------------------------------
g_energy_colors:
    !byte COLOR_CYAN            ; Color 0: Cyan (3)
    !byte COLOR_PINK            ; Color 1: Pink/Purple (4)
    !byte COLOR_YELLOW          ; Color 2: Yellow (7)
    !byte COLOR_GREEN           ; Color 3: Dark Green (5)
    !byte COLOR_LIGHT_GREEN     ; Color 4: Light Green (13)
    !byte COLOR_LIGHT_BLUE      ; Color 5: Light Blue (14)
    !byte COLOR_LIGHT_GRAY      ; Color 6: Light Gray (15)

; ------------------------------------------------------------------------------
; Player Missile RAM Variables
; ------------------------------------------------------------------------------
g_missile_x:        !word 0     ; 16-bit X-coordinate (0..320)
g_missile_y:        !byte 0     ; 8-bit Y-coordinate
g_missile_active:   !byte 0     ; 1 = Active, 0 = Inactive (despawned)
g_fire_cooldown:    !byte 0     ; Cooldown frame counter between shots
g_energy_cycle_idx: !byte 0     ; Active Energy palette color index (0..6)
g_fire_requested:   !byte 0     ; Latched single-shot request flag (1 = Requested)

; ==============================================================================
; Subroutine: weapons_init
; Purpose: Copies shot 1 sprite data into VIC-II RAM ($2280) and resets variables.
; ==============================================================================
weapons_init:
    ; 1. Copy 64 bytes of g_sprite_player_shot_1 into VIC-II Sprite RAM ($2280)
    ldx #0
@copy_loop:
    lda g_sprite_player_shot_1, x
    sta $2280, x
    inx
    cpx #64
    bne @copy_loop

    ; 2. Reset missile variables
    lda #0
    sta g_missile_x
    sta g_missile_x + 1
    sta g_missile_y
    sta g_missile_active
    sta g_fire_cooldown
    sta g_energy_cycle_idx
    sta g_fire_requested
    rts

; ==============================================================================
; Subroutine: weapons_fire
; Purpose: Spawns a new player missile aligned with ship nose (X+22, Y+3) if slot free.
; ==============================================================================
weapons_fire:
    ; Check if fire cooldown is active or player is dead
    lda g_fire_cooldown
    bne @fire_done
    lda g_player_alive
    beq @fire_done

    ; Check if missile is already active
    lda g_missile_active
    bne @fire_done

    ; Activate missile
    lda #1
    sta g_missile_active

    ; Set missile spawn position: X = player_x + 22, Y = player_y + 3
    lda g_player_x
    clc
    adc #22
    sta g_missile_x
    lda g_player_x + 1
    adc #0
    sta g_missile_x + 1

    lda g_player_y
    clc
    adc #3
    sta g_missile_y

    ; Set fire cooldown = 6 frames (~10 shots/sec max rate)
    lda #6
    sta g_fire_cooldown

    ; Consume latched single-shot request
    lda #0
    sta g_fire_requested

@fire_done:
    rts

; ==============================================================================
; Subroutine: weapons_update
; Purpose: Cycles Energy color palette, advances active missile by 50 ppf,
;          recycles missile when X >= 320, and processes latched fire requests.
; ==============================================================================
weapons_update:
    ; 1. Advance Energy palette index each frame (0..6)
    inc g_energy_cycle_idx
    lda g_energy_cycle_idx
    cmp #NUM_ENERGY_COLORS
    bcc +
    lda #0
    sta g_energy_cycle_idx
+

    ; 2. Decrement fire cooldown counter if active
    lda g_fire_cooldown
    beq +
    dec g_fire_cooldown
+

    ; 3. Move existing active missile rightward BEFORE spawning new ones
    lda g_missile_active
    beq @check_fire_request

    ; Add 50 pixels to 16-bit missile X-coordinate
    lda g_missile_x
    clc
    adc #50
    sta g_missile_x
    lda g_missile_x + 1
    adc #0
    sta g_missile_x + 1

    ; Check if missile reached or exited right playfield border (X >= 320 -> MSB=1, LSB >= 64)
    lda g_missile_x + 1
    cmp #1
    bcc @check_fire_request     ; If MSB == 0, X < 256, still active
    lda g_missile_x
    cmp #64                     ; 320 - 256 = 64
    bcc @check_fire_request
    
    ; Despawn missile when reaching right border
    lda #0
    sta g_missile_active

@check_fire_request:
    ; 4. Latch new keydown single-shot event
    lda g_input_fire_pressed
    beq +
    lda #1
    sta g_fire_requested
+

    ; 5. Execute latched fire request if available and missile slot is free
    lda g_fire_requested
    beq @update_done
    jsr weapons_fire

@update_done:
    rts

; ==============================================================================
; Subroutine: weapons_render
; Purpose: Configures Sprite 1 registers (pointer, monochrome mode, active Energy color, X/Y coordinates, MSB).
; ==============================================================================
weapons_render:
    ; Keep Sprite 0 enabled by default
    lda VIC_SPR_ENABLE
    and #$01
    sta VIC_SPR_ENABLE

    ; If missile is inactive, return
    lda g_missile_active
    beq @render_done

    ; 1. Enable Sprite 1 in VIC-II Enable Register ($D015)
    lda VIC_SPR_ENABLE
    ora #$02
    sta VIC_SPR_ENABLE

    ; 2. Set Sprite 1 pointer at $07F9 to block 138 ($2280 / 64 = 138)
    lda #SHOT_SPRITE_BLOCK
    sta SPRITE_PTRS + 1

    ; 3. Clear Sprite 1 Multicolor Bit ($D01C) for hi-res monochrome rendering
    lda VIC_SPR_MULTICOLOR
    and #$fd
    sta VIC_SPR_MULTICOLOR

    ; 4. Set Sprite 1 color from current Energy Palette cycling index
    ldx g_energy_cycle_idx
    lda g_energy_colors, x
    sta VIC_SPR1_COLOR

    ; 5. Write Sprite 1 X low byte ($D002) and Y byte ($D003)
    lda g_missile_x
    sta VIC_SPR1_X
    lda g_missile_y
    sta VIC_SPR1_Y

    ; 6. Set or Clear Bit 1 of VIC_SPR_MSB ($D010) based on missile 16-bit X-coordinate
    lda g_missile_x + 1
    beq @clear_msb1
    lda VIC_SPR_MSB
    ora #$02                    ; Set MSB Bit 1 (X >= 256)
    sta VIC_SPR_MSB
    jmp @render_done

@clear_msb1:
    lda VIC_SPR_MSB
    and #$fd                    ; Clear MSB Bit 1 (X < 256)
    sta VIC_SPR_MSB

@render_done:
    rts
