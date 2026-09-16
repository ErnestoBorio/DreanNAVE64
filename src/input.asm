; ==============================================================================
; INPUT.ASM - Input Subsystem (Phase 0 Skeleton)
; ==============================================================================

g_input_up:           !byte 0
g_input_down:         !byte 0
g_input_left:         !byte 0
g_input_right:        !byte 0
g_input_fire:         !byte 0
g_input_fire_pressed: !byte 0

input_init:
    lda #0
    sta g_input_up
    sta g_input_down
    sta g_input_left
    sta g_input_right
    sta g_input_fire
    sta g_input_fire_pressed
    rts

input_update:
    rts

