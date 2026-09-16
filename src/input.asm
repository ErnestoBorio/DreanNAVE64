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
; 4. Fire Keys:
;    - Left Shift  (Column 1, Row PB7 ONLY)
;    - Right Shift (Column 6, Row PB4 ONLY)
;    - Spacebar    (Column 7, Row PB4 ONLY)
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

; ==============================================================================
; Subroutine: input_init
; Purpose: Initializes CIA1 I/O port direction registers and resets state variables.
; ==============================================================================
input_init:
    ; Set CIA1 Data Direction Registers to Input mode (0 = Input, 1 = Output)
    lda #$00
    sta CIA1_DIR_A      ; Port A = Input mode
    sta CIA1_DIR_B      ; Port B = Input mode

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
; Purpose: Scans Joystick Port 2 and Keyboard Matrix lines.
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

    ; --------------------------------------------------------------------------
    ; Step 1: Read Joystick Port 2 ($DC00)
    ; --------------------------------------------------------------------------
    ; Ensure Port A and Port B are configured as inputs
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
; Step 2: Standard Keyboard Matrix Scan
; ------------------------------------------------------------------------------
; Set Port A to outputs ($FF) to select columns.
; Set Port B to inputs ($00) to read rows.
@scan_keyboard:
    lda #$ff
    sta CIA1_DIR_A
    lda #$00
    sta CIA1_DIR_B

    ; --- Column 2 ($FB = %11111011): Keys 'R', 'D', 'F' ---
    lda #$fb
    sta CIA1_DATA_A     ; Pull Column 2 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    tax                 ; Save Port B reading in X register
    and #$02            ; Check Bit 1 ('R' key = Up: 0 = pressed)
    bne +
    inc g_input_up
+   txa
    and #$04            ; Check Bit 2 ('D' key = Left: 0 = pressed)
    bne +
    inc g_input_left
+   txa
    and #$20            ; Check Bit 5 ('F' key = Down: 0 = pressed)
    bne +
    inc g_input_down
+

    ; --- Column 3 ($F7 = %11110111): Keys 'G', 'H', 'U' ---
    lda #$f7
    sta CIA1_DATA_A     ; Pull Column 3 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    tax
    and #$04            ; Check Bit 2 ('G' key = Right: 0 = pressed)
    bne +
    inc g_input_right
+   txa
    and #$20            ; Check Bit 5 ('H' key = TATE Up: 0 = pressed)
    bne +
    inc g_input_up
+   txa
    and #$40            ; Check Bit 6 ('U' key = TATE Right: 0 = pressed)
    bne +
    inc g_input_right
+

    ; --- Column 4 ($EF = %11101111): Keys 'J', 'K' ---
    lda #$ef
    sta CIA1_DATA_A     ; Pull Column 4 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    tax
    and #$04            ; Check Bit 2 ('J' key = TATE Left: 0 = pressed)
    bne +
    inc g_input_left
+   txa
    and #$20            ; Check Bit 5 ('K' key = TATE Down: 0 = pressed)
    bne +
    inc g_input_down
+

    ; --- Column 1 ($FD = %11111101): Left Shift (Row PB7) ---
    lda #$fd
    sta CIA1_DATA_A     ; Pull Column 1 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    and #$80            ; Check Bit 7 (Left Shift ONLY: 0 = pressed)
    bne +
    inc g_input_fire
+

    ; --- Column 6 ($BF = %10111111): Right Shift (Row PB4) ---
    lda #$bf
    sta CIA1_DATA_A     ; Pull Column 6 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    and #$10            ; Check Bit 4 (Right Shift ONLY: 0 = pressed)
    bne +
    inc g_input_fire
+

    ; --- Column 7 ($7F = %01111111): Spacebar (Row PB4) ---
    lda #$7f
    sta CIA1_DATA_A     ; Pull Column 7 low
    lda CIA1_DATA_B     ; Read Rows (Port B)
    and #$10            ; Check Bit 4 (Spacebar ONLY: 0 = pressed)
    bne +
    inc g_input_fire
+

    ; Restore Port A and Port B to all inputs for safety and Joystick Port 2 reading
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
