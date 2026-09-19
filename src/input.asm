; ==============================================================================
; INPUT.ASM - CIA1 Joystick Port 2 & Keyboard Matrix Scanning Subsystem
; ==============================================================================
; Target: Commodore 64
; Assembler: ACME 6502 Assembler
; ==============================================================================
; INPUT MAPPINGS SUPPORTED:
; 1. Joystick Port 2 ($DC00): Up, Down, Left, Right, Fire button
; 2. Horizontal Mode Key Set (R-D-F-G):
;    - R = Move Up   (Column 2, Row PB1)
;    - D = Move Left (Column 2, Row PB2)
;    - F = Move Down (Column 2, Row PB5)
;    - G = Move Right (Column 3, Row PB2)
; 3. TATE Mode Key Set (U-H-J-K):
;    - H = Move Up   (Column 3, Row PB5)
;    - J = Move Left (Column 4, Row PB2)
;    - K = Move Down (Column 4, Row PB5)
;    - U = Move Right (Column 3, Row PB6)
; 4. Fire Keys (Left & Right Handed Controls):
;    - 'Z' (Column 1, Row PB4) - Left side (pairs naturally with right hand steering U-H-J-K)
;    - 'P' (Column 5, Row PB1) - Right side (pairs naturally with left hand steering R-D-F-G)
;
; SINGLE-SHOT (EDGE-DETECTION) FIRING LOGIC:
; - g_input_fire: Level-triggered (1 as long as fire key/button is held down)
; - g_input_fire_pressed: Edge-triggered (1 ONLY on initial keydown frame)
;   Evaluated as: g_input_fire_pressed = current_fire AND (NOT previous_fire)
; ==============================================================================

; ------------------------------------------------------------------------------
; Input State RAM Variables
; ------------------------------------------------------------------------------
g_input_up:           !byte 0   ; 1 = Move Up active, 0 = Inactive
g_input_down:         !byte 0   ; 1 = Move Down active, 0 = Inactive
g_input_left:         !byte 0   ; 1 = Move Left active, 0 = Inactive
g_input_right:        !byte 0   ; 1 = Move Right active, 0 = Inactive
g_input_fire:         !byte 0   ; 1 = Fire button held down (level-triggered)
g_input_fire_pressed: !byte 0   ; 1 = Fire button newly pressed (edge-triggered)
s_prev_fire:          !byte 0   ; Previous frame fire state (used for edge-detection)
s_col2_active:        !byte 0   ; 1 = Horizontal Column 2 active (R, D, F)
s_col4_active:        !byte 0   ; 1 = TATE Column 4 active (J, K)

; In-Game Debug Hotkey State Variables (SHIFT + Keys 1..8, C)
g_debug_border_timer: !byte 0   ; Countdown frames for border flash feedback
s_shift_held:         !byte 0   ; 1 = SHIFT held down, 0 = SHIFT not pressed
s_current_debug_key:  !byte 0   ; Digit key active in current frame (0 = none, 1..8, 9=C)
s_prev_debug_key:     !byte 0   ; Digit key active in previous frame (edge detector)
s_scan_portb:         !byte 0   ; Saved Port B reading to prevent register clobbering

g_debug_enemy_colors:
    !byte COLOR_LIGHT_RED       ; 0: Enemy 1
    !byte COLOR_GREEN           ; 1: Enemy 2
    !byte COLOR_PURPLE          ; 2: Enemy 3
    !byte COLOR_YELLOW          ; 3: Enemy 4
    !byte COLOR_CYAN            ; 4: Enemy 5
    !byte COLOR_ORANGE          ; 5: Enemy 6
    !byte COLOR_LIGHT_BLUE      ; 6: Enemy 7
    !byte COLOR_WHITE           ; 7: Enemy 8

; ==============================================================================
; Subroutine: input_init
; Purpose: Initializes CIA1 I/O port direction registers and resets state variables.
; ==============================================================================
input_init:
    lda #$00
    sta CIA1_DIR_A      ; Port A = Input mode
    sta CIA1_DIR_B      ; Port B = Input mode

    sta g_input_up
    sta g_input_down
    sta g_input_left
    sta g_input_right
    sta g_input_fire
    sta g_input_fire_pressed
    sta s_prev_fire
    sta s_col2_active
    sta s_col4_active

    sta g_debug_border_timer
    sta s_shift_held
    sta s_current_debug_key
    sta s_prev_debug_key
    rts

; ==============================================================================
; Subroutine: input_update
; Purpose: Scans keyboard matrix supporting simultaneous Horizontal (RDFG) and
;          TATE (UHJK) key sets with hardware matrix de-ghosting, isolates
;          Joystick Port 2 from crosstalk, and evaluates single-shot fire.
; ==============================================================================
input_update:
    ; Update debug border flash timer
    lda g_debug_border_timer
    beq +
    dec g_debug_border_timer
    bne +
    lda #COLOR_BLACK
    sta VIC_BORDER_COLOR
+
    ; 1. Reset frame input flags to 0 (inactive)
    lda #$00
    sta g_input_up
    sta g_input_down
    sta g_input_left
    sta g_input_right
    sta g_input_fire
    sta g_input_fire_pressed
    sta s_col2_active
    sta s_col4_active
    sta s_shift_held
    sta s_current_debug_key

    ; --------------------------------------------------------------------------
    ; Step 1: Scan Keyboard Matrix (Supports Full 8-Way Diagonals & De-Ghosting)
    ; --------------------------------------------------------------------------
    ; Configure Port A as outputs ($FF) to drive columns and Port B as inputs ($00)
    lda #$ff
    sta CIA1_DIR_A
    lda #$00
    sta CIA1_DIR_B

    ; --- Shift Key Detection (Left Shift: Col 1, PB7; Right Shift: Col 6, PB4) ---
    lda #$fd            ; Column 1 ($FD = %11111101)
    sta CIA1_DATA_A
    lda CIA1_DATA_B
    bpl +               ; Bit 7 = 0 -> Left Shift pressed!

    lda #$bf            ; Column 6 ($BF = %10111111)
    sta CIA1_DATA_A
    lda CIA1_DATA_B
    and #$10            ; Bit 4 = 0 -> Right Shift pressed!
    bne @no_shift
+   inc s_shift_held
@no_shift:

    ; --- Column 7 ($7F = %01111111): Debug Keys '1' (PB0) and '2' (PB3) ---
    lda #$7f
    sta CIA1_DATA_A     ; Pull Column 7 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    sta s_scan_portb

    ; When Shift is held, scan debug keys '1' (PB0) and '2' (PB3)
    lda s_shift_held
    beq @col7_debug_done
    lda s_scan_portb
    and #$01            ; Bit 0: '1' (0 = pressed)
    bne +
    lda #1
    sta s_current_debug_key
+   lda s_scan_portb
    and #$08            ; Bit 3: '2' (0 = pressed)
    bne @col7_debug_done
    lda #2
    sta s_current_debug_key
@col7_debug_done:

    ; --- Column 2 ($FB = %11111011): 'R' (PB1), 'D' (PB2), 'F' (PB5), Debug '5' (PB0), '6' (PB3), 'C' (PB4) ---
    lda #$fb
    sta CIA1_DATA_A     ; Pull Column 2 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    sta s_scan_portb

    ; Check 'R' (PB1)
    and #$02            ; Bit 1: 'R' (Move Up: 0 = pressed)
    bne +
    inc g_input_up
    inc s_col2_active   ; Flag Column 2 active
+   lda s_scan_portb
    and #$04            ; Bit 2: 'D' (Move Left: 0 = pressed)
    bne +
    inc g_input_left
    inc s_col2_active   ; Flag Column 2 active
+   lda s_scan_portb
    and #$20            ; Bit 5: 'F' (Move Down: 0 = pressed)
    bne +
    inc g_input_down
    inc s_col2_active   ; Flag Column 2 active
+
    ; Debug Keys '5' (PB0), '6' (PB3), 'C' (PB4) - only scanned if Shift held
    lda s_shift_held
    beq @col2_debug_done
    lda s_scan_portb
    and #$01            ; Bit 0: Debug Key '5' (0 = pressed)
    bne +
    lda #5
    sta s_current_debug_key
+   lda s_scan_portb
    and #$08            ; Bit 3: Debug Key '6' (0 = pressed)
    bne +
    lda #6
    sta s_current_debug_key
+   lda s_scan_portb
    and #$10            ; Bit 4: Debug Key 'C' (Clear all enemies)
    bne @col2_debug_done
    lda #9
    sta s_current_debug_key
@col2_debug_done:

    ; --- Column 4 ($EF = %11101111): TATE Keys 'J' (PB2), 'K' (PB5), Debug '0' (PB3) ---
    lda #$ef
    sta CIA1_DATA_A     ; Pull Column 4 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    sta s_scan_portb
    and #$04            ; Bit 2: 'J' (TATE Move Left: 0 = pressed)
    bne +
    inc g_input_left
    inc s_col4_active   ; Flag Column 4 active
+   lda s_scan_portb
    and #$20            ; Bit 5: 'K' (TATE Move Down: 0 = pressed)
    bne +
    inc g_input_down
    inc s_col4_active   ; Flag Column 4 active
+
    lda s_shift_held
    beq @col4_debug_done
    lda s_scan_portb
    and #$08            ; Bit 3: Debug Key '0' (0 = pressed) -> Reset to Tier 0 (Enemy 1 at 0s)
    bne @col4_debug_done
    lda #1
    sta s_current_debug_key
@col4_debug_done:

    ; --- Column 3 ($F7 = %11110111): Shared 'G', 'H', 'U', Debug '7' (PB0), '8' (PB3) ---
    ; De-ghosting:
    ; 1) 'G' (Horizontal Right) is suppressed if Column 4 (J, K) is active,
    ;    preventing H+J+K in TATE mode from ghosting G and freezing controls.
    ; 2) 'H' (TATE Up) and 'U' (TATE Right) are suppressed if Column 2 (R, D, F) is active,
    ;    preventing D+F+G in Horizontal mode from ghosting H and freezing controls.
    lda #$f7
    sta CIA1_DATA_A     ; Pull Column 3 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    sta s_scan_portb

    ; Check Key 'G': Move Right (Row PB2)
    and #$04            ; Bit 2: 'G' (0 = pressed)
    bne +
    lda s_col4_active   ; If TATE keys (J/K) active, suppress ghost 'G'
    bne +
    inc g_input_right
+   lda s_scan_portb
    ; Check Key 'H': TATE Move Up (Row PB5)
    and #$20            ; Bit 5: 'H' (0 = pressed)
    bne +
    lda s_col2_active   ; If Horizontal keys (R/D/F) active, suppress ghost 'H'
    bne +
    inc g_input_up
+   lda s_scan_portb
    ; Check Key 'U': TATE Move Right (Row PB6)
    and #$40            ; Bit 6: 'U' (0 = pressed)
    bne +
    lda s_col2_active   ; If Horizontal keys (R/D/F) active, suppress 'U'
    bne +
    inc g_input_right
+
    ; Debug Keys '7' (PB0) and '8' (PB3) - only scanned if Shift held
    lda s_shift_held
    beq @col3_debug_done
    lda s_scan_portb
    and #$01            ; Bit 0: '7' (0 = pressed)
    bne +
    lda #7
    sta s_current_debug_key
+   lda s_scan_portb
    and #$08            ; Bit 3: '8' (0 = pressed)
    bne @col3_debug_done
    lda #8
    sta s_current_debug_key
@col3_debug_done:

    ; --- Column 1 ($FD = %11111101): Fire 'Z' (PB4), Debug '3' (PB0), '4' (PB3) ---
    lda #$fd
    sta CIA1_DATA_A     ; Pull Column 1 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    sta s_scan_portb
    and #$10            ; Bit 4: Key 'Z' (0 = pressed)
    bne +
    inc g_input_fire
+
    ; Debug Keys '3' (PB0) and '4' (PB3) - only scanned if Shift held
    lda s_shift_held
    beq @col1_debug_done
    lda s_scan_portb
    and #$01            ; Bit 0: Key '3' (0 = pressed)
    bne +
    lda #3
    sta s_current_debug_key
+   lda s_scan_portb
    and #$08            ; Bit 3: Key '4' (0 = pressed)
    bne @col1_debug_done
    lda #4
    sta s_current_debug_key
@col1_debug_done:

    ; --- Column 5 ($DF = %11011111): Fire Key 'P' (Row PB1) [Right Side Fire] ---
    lda #$df
    sta CIA1_DATA_A     ; Pull Column 5 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    and #$02            ; Bit 1: Key 'P' (0 = pressed)
    bne +
    inc g_input_fire
+

    ; Release all column drivers and restore Port A & B to all-inputs
    lda #$ff
    sta CIA1_DATA_A     ; Release driven lines high
    lda #$00
    sta CIA1_DIR_A      ; Port A = all inputs
    sta CIA1_DIR_B      ; Port B = all inputs

    ; --------------------------------------------------------------------------
    ; Step 2: Read Joystick Port 2 ($DC00) - Only if no keyboard keys are active
    ; Prevents keyboard switch closure crosstalk on shared CIA1 lines from
    ; injecting phantom joystick inputs that cancel out player movement.
    ; --------------------------------------------------------------------------
    lda g_input_up
    ora g_input_down
    ora g_input_left
    ora g_input_right
    ora g_input_fire
    bne @skip_joystick  ; If keyboard is in use, skip reading Joystick Port 2

    lda CIA1_DATA_A     ; Read Joystick Port 2 (Bits are 0 when pressed, 1 when unpressed)

@check_joy_up:
    lsr                 ; Shift Bit 0 (Up) into Carry flag
    bcs @check_joy_down
    inc g_input_up

@check_joy_down:
    lsr                 ; Shift Bit 1 (Down) into Carry flag
    bcs @check_joy_left
    inc g_input_down

@check_joy_left:
    lsr                 ; Shift Bit 2 (Left) into Carry flag
    bcs @check_joy_right
    inc g_input_left

@check_joy_right:
    lsr                 ; Shift Bit 3 (Right) into Carry flag
    bcs @check_joy_fire
    inc g_input_right

@check_joy_fire:
    lsr                 ; Shift Bit 4 (Fire button) into Carry flag
    bcs @skip_joystick
    inc g_input_fire

@skip_joystick:
    ; --------------------------------------------------------------------------
    ; Step 3: Opposing Direction Cancellation
    ; Prevents simultaneous Up+Down or Left+Right from deadlocking movement.
    ; Diagonals (e.g. Up+Left, Up+Right, Down+Left, Down+Right) are fully preserved!
    ; --------------------------------------------------------------------------
    lda g_input_up
    beq +
    lda g_input_down
    beq +
    lda #0
    sta g_input_up
    sta g_input_down
+
    lda g_input_left
    beq +
    lda g_input_right
    beq +
    lda #0
    sta g_input_left
    sta g_input_right
+

    ; --------------------------------------------------------------------------
    ; Step 4: Compute Edge-Triggered Single-Shot Fire (fire_pressed)
    ; --------------------------------------------------------------------------
    lda g_input_fire
    beq @no_fire_pressed

    lda s_prev_fire
    bne @done_edge

    lda #$01
    sta g_input_fire_pressed
    jmp @done_edge

@no_fire_pressed:
    lda #$00
    sta g_input_fire_pressed

@done_edge:
    lda g_input_fire
    sta s_prev_fire

    ; --------------------------------------------------------------------------
    ; Step 5: Evaluate Edge-Triggered Debug Tier Jump (SHIFT + 1..8)
    ; --------------------------------------------------------------------------
    lda s_current_debug_key
    beq @no_debug_key
    cmp s_prev_debug_key
    beq @debug_eval_done        ; Same debug key held across frames: suppress re-trigger
    sta s_prev_debug_key        ; New keypress edge detected
    jsr input_jump_to_tier      ; Jump to tier corresponding to key in A (1..8)
    jmp @debug_eval_done

@no_debug_key:
    lda #0
    sta s_prev_debug_key        ; Key released

@debug_eval_done:
    rts

; ==============================================================================
; Subroutine: input_jump_to_tier
; Purpose: Sets game progression parameters to the unlock tier of Enemy N (1..8),
;          spawns Enemy N immediately by its own archetype rules, and allows
;          preceding unlocked enemies (1..N-1) to continue spawning under the tier.
; Input: A = 1..8 (Enemy 1..8)
; ==============================================================================
input_jump_to_tier:
    cmp #9
    bne @is_tier_jump
    lda #COLOR_LIGHT_RED
    sta VIC_BORDER_COLOR
    bne @flash_and_clear

@is_tier_jump:
    sta g_first_spawn_force     ; 1..8: Force Enemy N on very first upcoming spawn
    sec
    sbc #1                      ; 1..8 -> 0..7
    tax                         ; X = archetype / tier index (0..7)

    ; 1. Flash border with archetype feedback color
    lda g_debug_enemy_colors, x
    sta VIC_BORDER_COLOR

    ; 2. Set game elapsed time to unlock threshold of Enemy N
    lda enemy_table_unlock_sec_lo, x
    sta g_game_time_total_sec + 0
    lda enemy_table_unlock_sec_hi, x
    sta g_game_time_total_sec + 1
    lda #0
    sta g_game_time_frames
    sta g_game_time_sec
    sta g_game_time_min

@flash_and_clear:
    lda #8
    sta g_debug_border_timer

    ; 3. Despawn all active enemies and bullets for a clean wave start
    jsr enemies_clear_all

    ; 4. Trigger immediate wave spawn (2 frames)
    lda #2
    sta g_wave_spawn_timer
    rts

