; ==============================================================================
; PLAYER.ASM - Phase 1 Visual Marker & Bounds Verification Subsystem
; ==============================================================================
; Provides an interactive, visible on-screen marker to verify Phase 1:
; - 8-way movement via Joystick Port 2, R-D-F-G, and U-H-J-K
; - Playfield boundary clamping
; - Single-shot and continuous fire detection (Left/Right Shift, Spacebar, Joy Fire)
; ==============================================================================

; ------------------------------------------------------------------------------
; Player Marker RAM Variables
; ------------------------------------------------------------------------------
g_marker_x:         !byte 20    ; Screen column (1..38)
g_marker_y:         !byte 12    ; Screen row (1..23)
s_prev_marker_x:    !byte 20    ; Previous frame column
s_prev_marker_y:    !byte 12    ; Previous frame row
s_move_delay:       !byte 0     ; Movement speed divider counter

; ==============================================================================
; Subroutine: player_init
; Purpose: Sets starting coordinates for the verification marker.
; ==============================================================================
player_init:
    lda #20
    sta g_marker_x
    sta s_prev_marker_x
    lda #12
    sta g_marker_y
    sta s_prev_marker_y
    lda #0
    sta s_move_delay
    rts

; ==============================================================================
; Subroutine: player_update
; Purpose: Updates marker position based on g_input_* variables and clamps to bounds.
; ==============================================================================
player_update:
    ; Update every 4 frames so character-cell motion is smooth and readable
    inc s_move_delay
    lda s_move_delay
    cmp #4
    bcc @skip_move
    lda #0
    sta s_move_delay

    ; Check Move Up
    lda g_input_up
    beq @check_down
    lda g_marker_y
    cmp #1                      ; Top border clamp
    beq @check_down
    dec g_marker_y

@check_down:
    ; Check Move Down
    lda g_input_down
    beq @check_left
    lda g_marker_y
    cmp #23                     ; Bottom border clamp
    beq @check_left
    inc g_marker_y

@check_left:
    ; Check Move Left
    lda g_input_left
    beq @check_right
    lda g_marker_x
    cmp #1                      ; Left border clamp
    beq @check_right
    dec g_marker_x

@check_right:
    ; Check Move Right
    lda g_input_right
    beq @done_move
    lda g_marker_x
    cmp #38                     ; Right border clamp
    beq @done_move
    inc g_marker_x

@done_move:
@skip_move:
    rts

; ==============================================================================
; Subroutine: player_render
; Purpose: Clears previous character on Screen RAM and renders the marker at new position.
; ==============================================================================
player_render:
    ; 1. Erase previous marker position from Screen RAM ($0400)
    jsr compute_screen_addr_prev ; Returns pointer in $fb/$fc
    ldy s_prev_marker_x
    lda #$20                    ; Space ($20 = blank)
    sta ($fb), y

    ; 2. Update previous position tracking
    lda g_marker_x
    sta s_prev_marker_x
    lda g_marker_y
    sta s_prev_marker_y

    ; 3. Draw marker character at current position
    jsr compute_screen_addr_curr ; Returns pointer in $fb/$fc
    ldy g_marker_x

    ; Choose character and color based on fire state:
    ; - Fire newly pressed: Star/Burst char ($53) in Yellow
    ; - Fire held: Triangle/Arrow ($3E) in Cyan
    ; - Normal: Triangle/Arrow ($3E) in White
    lda g_input_fire_pressed
    beq @check_fire_held
    lda #$53                    ; Shifted asterism/burst symbol
    sta ($fb), y
    lda #COLOR_YELLOW
    jmp @write_color

@check_fire_held:
    lda g_input_fire
    beq @draw_normal
    lda #$3e                    ; '>' arrow character
    sta ($fb), y
    lda #COLOR_CYAN
    jmp @write_color

@draw_normal:
    lda #$3e                    ; '>' arrow character
    sta ($fb), y
    lda #COLOR_WHITE

@write_color:
    ; Write color into Color RAM ($D800)
    ; $fc high byte for screen is $04..$07, for color RAM is $D8..$DB
    pha
    lda $fc
    clc
    adc #($d8 - $04)            ; Adjust page from $04 to $D8
    sta $fd
    lda $fb
    sta $fe
    pla
    sta ($fe), y
    rts

; ------------------------------------------------------------------------------
; Helper: Computes base screen row pointer in $fb/$fc for s_prev_marker_y
; ------------------------------------------------------------------------------
compute_screen_addr_prev:
    ldx s_prev_marker_y
    lda g_screen_row_lo, x
    sta $fb
    lda g_screen_row_hi, x
    sta $fc
    rts

; ------------------------------------------------------------------------------
; Helper: Computes base screen row pointer in $fb/$fc for g_marker_y
; ------------------------------------------------------------------------------
compute_screen_addr_curr:
    ldx g_marker_y
    lda g_screen_row_lo, x
    sta $fb
    lda g_screen_row_hi, x
    sta $fc
    rts

; ------------------------------------------------------------------------------
; 25-Row Screen RAM Low and High Address Tables ($0400 + row * 40)
; ------------------------------------------------------------------------------
g_screen_row_lo:
    !byte <$0400, <$0428, <$0450, <$0478, <$04a0, <$04c8, <$04f0, <$0518
    !byte <$0540, <$0568, <$0590, <$05b8, <$05e0, <$0608, <$0630, <$0658
    !byte <$0680, <$06a8, <$06d0, <$06f8, <$0720, <$0748, <$0770, <$0798
    !byte <$07c0

g_screen_row_hi:
    !byte >$0400, >$0428, >$0450, >$0478, >$04a0, >$04c8, >$04f0, >$0518
    !byte >$0540, >$0568, >$0590, >$05b8, >$05e0, >$0608, >$0630, >$0658
    !byte >$0680, >$06a8, >$06d0, >$06f8, >$0720, >$0748, >$0770, >$0798
    !byte >$07c0
