; ==============================================================================
; INPUT.ASM - CIA1 Joystick Port 2 & Open-Drain Keyboard Matrix Subsystem
; ==============================================================================
; This module handles player directional movement and fire input scanning.
;
; INPUT MAPPINGS SUPPORTED:
; 1. Joystick Port 2 ($DC00): Up, Down, Left, Right, Fire button
; 2. Keyboard Set 1 (R-D-F-G): R=Up, D=Left, F=Down, G=Right
; 3. Keyboard Set 2 (U-H-J-K): H/U=Up/Right, J/K=Left/Down
; 4. Fire Keys: Left Shift, Right Shift, Spacebar
;
; SINGLE-SHOT (EDGE-DETECTION) FIRING LOGIC:
; - g_input_fire: Level-triggered (1 as long as fire key/button is held down)
; - g_input_fire_pressed: Edge-triggered (1 ONLY on the initial keydown frame)
;   Evaluated as: g_input_fire_pressed = current_fire AND NOT previous_fire
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

; ==============================================================================
; Subroutine: input_init
; Purpose: Initializes CIA1 I/O ports and resets input state variables.
; ==============================================================================
input_init:
    ; Set CIA1 Data Direction Registers to Input mode (0 = Input, 1 = Output)
    lda #$00
    sta CIA1_DIR_A      ; Port A = Input mode
    sta CIA1_DIR_B      ; Port B = Input mode
    sta CIA1_DATA_A     ; Data register output latch = 0V ground
    sta CIA1_DATA_B     ; Data register output latch = 0V ground

    ; Reset input state variables
    sta g_input_up
    sta g_input_down
    sta g_input_left
    sta g_input_right
    sta g_input_fire
    sta g_input_fire_pressed
    sta s_prev_fire
    rts

; ==============================================================================
; Subroutine: input_update
; Purpose: Scans Joystick Port 2 and Open-Drain Keyboard Matrix lines.
; ==============================================================================
input_update:
    ; Reset frame input flags to 0 (inactive)
    lda #$00
    sta g_input_up
    sta g_input_down
    sta g_input_left
    sta g_input_right
    sta g_input_fire
    sta g_input_fire_pressed

    ; Output data registers are kept at 0V ground ($00).
    ; In Open-Drain mode, we select a matrix column by setting its DIR_A bit to 1 (Output 0V).
    ; Unselected bits remain 0 (Input mode, high impedance) to prevent short circuits with Joysticks.
    sta CIA1_DATA_A
    sta CIA1_DATA_B

    ; --------------------------------------------------------------------------
    ; Step 1: Read Joystick Port 2 ($DC00, All pins in Input mode)
    ; --------------------------------------------------------------------------
    sta CIA1_DIR_A      ; Port A = All inputs
    sta CIA1_DIR_B      ; Port B = All inputs

    lda CIA1_DATA_A     ; Read Joystick Port 2 (Bits are 0 when pressed, 1 when unpressed)

@check_joy_up:
    lsr                 ; Shift Bit 0 (Up) into Carry flag
    bcs @check_joy_down ; If Carry = 1 (unpressed), skip to next check
    inc g_input_up      ; If Carry = 0 (pressed), set g_input_up = 1

@check_joy_down:
    lsr                 ; Shift Bit 1 (Down) into Carry flag
    bcs @check_joy_left ; If Carry = 1 (unpressed), skip to next check
    inc g_input_down    ; If Carry = 0 (pressed), set g_input_down = 1

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
    bcs @scan_keyboard
    inc g_input_fire

; ------------------------------------------------------------------------------
; Step 2: Open-Drain Keyboard Matrix Scan
; ------------------------------------------------------------------------------
@scan_keyboard:

    ; --- Column PA2 ($04): Keys 'R', 'D', 'F' ---
    lda #$04
    sta CIA1_DIR_A      ; Set PA2 to Output 0V Ground
    lda CIA1_DATA_B     ; Read Rows (Port B)

    tax                 ; Save Port B reading in X register
    and #$02            ; Check Bit 1 ('R' key = Up)
    bne +
    inc g_input_up
+   txa
    and #$04            ; Check Bit 2 ('D' key = Left)
    bne +
    inc g_input_left
+   txa
    and #$20            ; Check Bit 5 ('F' key = Down)
    bne +
    inc g_input_down
+

    ; --- Column PA3 ($08): Keys 'G', 'H', 'U' ---
    lda #$08
    sta CIA1_DIR_A      ; Set PA3 to Output 0V Ground
    lda CIA1_DATA_B     ; Read Rows (Port B)

    tax
    and #$04            ; Check Bit 2 ('G' key = Right)
    bne +
    inc g_input_right
+   txa
    and #$20            ; Check Bit 5 ('H' key = Up)
    bne +
    inc g_input_up
+   txa
    and #$40            ; Check Bit 6 ('U' key = Right)
    bne +
    inc g_input_right
+

    ; --- Column PA4 ($10): Keys 'J', 'K' ---
    lda #$10
    sta CIA1_DIR_A      ; Set PA4 to Output 0V Ground
    lda CIA1_DATA_B     ; Read Rows (Port B)

    tax
    and #$04            ; Check Bit 2 ('J' key = Left)
    bne +
    inc g_input_left
+   txa
    and #$20            ; Check Bit 5 ('K' key = Down)
    bne +
    inc g_input_down
+

    ; --- Column PA1 ($02): Left Shift ---
    lda #$02
    sta CIA1_DIR_A      ; Set PA1 to Output 0V Ground
    lda CIA1_DATA_B     ; Read Rows (Port B)
    tax
    and #$02            ; Check Bit 1 (Left Shift row PB1)
    beq +
    txa
    and #$80            ; Check Bit 7 (Left Shift alternate row PB7)
    bne ++
+   inc g_input_fire
++

    ; --- Column PA6 ($40): Right Shift ---
    lda #$40
    sta CIA1_DIR_A      ; Set PA6 to Output 0V Ground
    lda CIA1_DATA_B     ; Read Rows (Port B)
    tax
    and #$10            ; Check Bit 4 (Right Shift row PB4)
    beq +
    txa
    and #$40            ; Check Bit 6 (Right Shift alternate row PB6)
    bne ++
+   inc g_input_fire
++

    ; --- Column PA7 ($80): Spacebar ---
    lda #$80
    sta CIA1_DIR_A      ; Set PA7 to Output 0V Ground
    lda CIA1_DATA_B     ; Read Rows (Port B)
    and #$10            ; Check Bit 4 (Spacebar row PB4)
    bne +
    inc g_input_fire
+

    ; Reset CIA1 Direction registers back to all inputs for safety
    lda #$00
    sta CIA1_DIR_A
    sta CIA1_DIR_B

    ; --------------------------------------------------------------------------
    ; Step 3: Compute Edge-Triggered Single-Shot Fire (fire_pressed)
    ; g_input_fire_pressed = g_input_fire AND (NOT s_prev_fire)
    ; --------------------------------------------------------------------------
    lda g_input_fire    ; Load current frame fire state (0 or non-zero)
    beq @no_fire_pressed ; If 0, no fire button is down

    lda s_prev_fire     ; Load previous frame fire state
    bne @done_edge      ; If previous frame was 1, button was already down (not a keydown event)

    ; Button was 0 on last frame and 1 on this frame -> New Keydown event!
    lda #$01
    sta g_input_fire_pressed
    jmp @done_edge

@no_fire_pressed:
    lda #$00
    sta g_input_fire_pressed

@done_edge:
    ; Save current frame fire state to s_prev_fire for next frame
    lda g_input_fire
    sta s_prev_fire
    rts
