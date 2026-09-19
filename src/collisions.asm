; ==============================================================================
; COLLISIONS.ASM - Collision Detection Subsystem (Phase 6)
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
;
; Manages:
; - Player missile vs Enemy ship bounding box sweep collision (50 px/frame sweep)
; - Multi-hit HP damage and white damage flash feedback
; - 3-frame multicolor explosion sequencing on destruction
; - Enemy slot recycling
; ==============================================================================

s_coll_diff_lo:     !byte 0

; ==============================================================================
; Subroutine: collisions_init
; Purpose: Resets collision subsystem state variables.
; ==============================================================================
collisions_init:
    lda #0
    sta s_coll_diff_lo
    rts

; ==============================================================================
; Subroutine: collisions_check
; Purpose: Tests active player missile against all 9 enemy slots using continuous
;          horizontal swept-box intersection to prevent high-speed tunneling.
; Called every frame in main game loop directly after enemies_update.
; ==============================================================================
collisions_check:
    ; Quick exit if no player missile is currently in flight
    lda g_missile_active
    cmp #1                      ; 1 = Missile in flight
    beq +
    rts
+
    ldx #0
@check_enemy_loop:
    ; 1. Check if enemy slot is active and not already exploding
    lda g_enemy_active, x
    beq @next_enemy
    lda g_enemy_exploding, x
    bne @next_enemy

    ; 2. Vertical Range Check:
    ; Enemy sprite height = 21 pixels (Y to Y + 20).
    ; Check if missile_y + 2 - enemy_y < 25
    lda g_missile_y
    clc
    adc #2
    sec
    sbc g_enemy_y, x
    cmp #25
    bcs @next_enemy

    ; 3. Horizontal Swept Check (50 px/frame sweep vs 24 px wide enemy):
    ; Condition for hit during this frame: 0 <= (X_missile - X_enemy) <= 73
    lda g_missile_x + 0
    sec
    sbc g_enemy_x_lo, x
    sta s_coll_diff_lo
    lda g_missile_x + 1
    sbc g_enemy_x_hi, x
    bne @next_enemy             ; If MSB != 0, out of range (either negative or > 255)

    lda s_coll_diff_lo
    cmp #74                     ; 0 <= diff <= 73
    bcs @next_enemy

    ; --------------------------------------------------------------------------
    ; Direct Hit Confirmed!
    ; --------------------------------------------------------------------------
    ; Decrement enemy HP
    dec g_enemy_hp, x
    beq @enemy_destroyed

    ; Enemy damaged but alive (HP > 0): Trigger white flash for 3 frames
    lda #3
    sta g_enemy_flash, x
    lda #COLOR_WHITE
    sta g_enemy_color, x

    ; Trigger hit spark on Sprite 1 (4 frames)
    lda #4
    sta g_missile_active

    ; Position spark in front of enemy nose (enemy faces left at g_enemy_x)
    lda g_enemy_x_lo, x
    sec
    sbc #8
    sta g_missile_x + 0
    lda g_enemy_x_hi, x
    sbc #0
    sta g_missile_x + 1

    lda g_enemy_y, x
    sta g_missile_y

    ; Pick a random energy color for the hit spark
    jsr starfield_rand
    and #$07
    tay
    lda g_energy_colors, y
    sta g_spark_color
    rts

@enemy_destroyed:
    ; Enemy destroyed (HP == 0): Deactivate missile and trigger 12-frame explosion
    lda #0
    sta g_missile_active
    lda #12
    sta g_enemy_exploding, x
    lda #SPRITE_PTR_EXPLOSION_1
    sta g_enemy_type, x
    rts

@next_enemy:
    inx
    cpx #MAX_ENEMIES
    bne @check_enemy_loop
    rts
