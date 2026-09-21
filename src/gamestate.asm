; ==============================================================================
; GAMESTATE.ASM - Core Game Flow State Machine Subsystem
; ==============================================================================
; Target: Commodore 64 (50 Hz PAL)
; Assembler: ACME 6502 Assembler
; ==============================================================================
; Manages Game States:
; - STATE_TITLE     (0): Attract & Title screen, scrolling starfield, FIRE/SPACE to start
; - STATE_READY     (1): Reset session, display "READY!", 1.5s countdown
; - STATE_PLAYING   (2): Active gameplay loop (player, enemies, weapons, HUD)
; - STATE_DYING     (3): Ship death explosion, 3.0s delay
; - STATE_GAME_OVER (4): "GAME OVER" & final score, 5.0s delay or Fire/Space to title
; ==============================================================================

STATE_TITLE     = 0
STATE_READY     = 1
STATE_PLAYING   = 2
STATE_DYING     = 3
STATE_GAME_OVER = 4

; ------------------------------------------------------------------------------
; State Machine RAM Variables
; ------------------------------------------------------------------------------
g_game_state:   !byte STATE_TITLE
g_state_timer:  !byte 0         ; General state countdown timer (PAL frames)
g_entering_initials: !byte 0    ; 1 = Player entering initials on Game Over screen

; Text for READY! banner
ready_banner_text:
    !byte 82, 69, 65, 68, 89, 33 ; "READY!" (ASCII codes: R, E, A, D, Y, !)

; ------------------------------------------------------------------------------
; State Dispatch Tables
; ------------------------------------------------------------------------------
state_update_table:
    !word state_title_update     ; 0: STATE_TITLE
    !word state_ready_update     ; 1: STATE_READY
    !word state_playing_update   ; 2: STATE_PLAYING
    !word state_dying_update     ; 3: STATE_DYING
    !word state_game_over_update ; 4: STATE_GAME_OVER

state_enter_table:
    !word state_title_enter      ; 0: STATE_TITLE
    !word state_ready_enter      ; 1: STATE_READY
    !word state_playing_enter    ; 2: STATE_PLAYING
    !word state_dying_enter      ; 3: STATE_DYING
    !word state_game_over_enter  ; 4: STATE_GAME_OVER

state_exit_table:
    !word state_title_exit       ; 0: STATE_TITLE
    !word state_ready_exit       ; 1: STATE_READY
    !word state_playing_exit     ; 2: STATE_PLAYING
    !word state_dying_exit       ; 3: STATE_DYING
    !word state_game_over_exit   ; 4: STATE_GAME_OVER

; ==============================================================================
; Subroutine: gamestate_init
; Purpose: Sets up initial state (STATE_TITLE) and invokes its enter handler.
; ==============================================================================
gamestate_init:
    lda #STATE_TITLE
    sta g_game_state
    jmp state_title_enter

; ==============================================================================
; Subroutine: gamestate_update
; Purpose: Dispatches update routine for current g_game_state.
; ==============================================================================
gamestate_update:
    lda g_game_state
    asl
    tax
    lda state_update_table + 0, x
    sta $fb
    lda state_update_table + 1, x
    sta $fc
    jmp ($00fb)

; ==============================================================================
; Subroutine: change_state
; Purpose: Transitions from current state to new state passed in A.
;          Executes: current_state_exit -> set g_game_state -> new_state_enter.
; Arguments: A = target state (STATE_TITLE..STATE_GAME_OVER)
; ==============================================================================
change_state:
    pha                         ; Push new state to stack

    ; 1. Execute current state's exit handler
    lda g_game_state
    asl
    tax
    lda state_exit_table + 0, x
    sta $fb
    lda state_exit_table + 1, x
    sta $fc
    jsr @call_indirect

    ; 2. Commit new state
    pla
    sta g_game_state

    ; 3. Execute new state's enter handler
    asl
    tax
    lda state_enter_table + 0, x
    sta $fb
    lda state_enter_table + 1, x
    sta $fc
    jsr @call_indirect
    rts

@call_indirect:
    jmp ($00fb)

; ==============================================================================
; State 0: STATE_TITLE
; ==============================================================================
state_title_enter:
    ; Disable hardware sprites & multiplexer during Title screen
    lda #0
    sta VIC_SPR_ENABLE
    sta g_multiplexer_active
    sta g_missile_active
    sta VIC_BORDER_COLOR

    ; Hide HUD from Row 0
    jsr hud_clear
    jmp title_enter

state_title_update:
    jmp title_update

state_title_exit:
    jmp title_exit

; ==============================================================================
; State 1: STATE_READY
; ==============================================================================
state_ready_enter:
    ; 1. Cleanly re-initialize all gameplay subsystems for fresh run
    jsr game_timer_init         ; Reset elapsed gameplay timeline and wave progression
    jsr player_init
    jsr weapons_init
    jsr enemies_init
    jsr powerups_init
    jsr hud_init
    jsr hud_clear               ; Hide HUD during READY

    ; 2. Display "READY!" at Column 20, Rows 10..15 in White
    lda #COLOR_WHITE
    sta s_char_color
    lda #10
    sta s_cur_row
    ldy #20
    ldx #0
-   lda ready_banner_text, x
    jsr hud_draw_char
    inx
    cpx #6
    bne -

    ; 3. Set 1.5-second countdown timer (75 PAL frames)
    lda #75
    sta g_state_timer

    ; 4. Render player ship so it is visible during READY
    jsr player_render
    rts

state_ready_update:
    ; Decrement countdown timer
    dec g_state_timer
    bne @done

    ; Timer expired: transition to active gameplay
    lda #STATE_PLAYING
    jsr change_state

@done:
    rts

state_ready_exit:
    ; Erase "READY!" banner at Column 20, Rows 10..15 with blank spaces
    lda #COLOR_BLACK
    sta s_char_color
    lda #10
    sta s_cur_row
    ldy #20
    ldx #6
-   lda #$20
    jsr hud_draw_char
    dex
    bne -
    rts

; ==============================================================================
; State 2: STATE_PLAYING
; ==============================================================================
state_playing_enter:
    ; 1. Enable multiplexer
    lda #1
    sta g_multiplexer_active

    ; 2. Display active HUD on Row 0
    jsr hud_show
    rts

state_playing_update:
    ; 1. Update Game Entities & World Motion
    jsr player_update
    jsr weapons_update
    jsr starfield_update
    jsr powerups_update
    jsr enemies_update
    jsr collisions_check
    jsr collisions_check_player
    jsr powerups_check_collision
    jsr hud_update

    ; 2. Render Graphics & Hardware Sprites
    jsr player_render
    jsr weapons_render
    jsr enemies_render

    ; 3. Check for player death
    lda g_player_alive
    bne @still_alive

    ; Player destroyed: transition to death animation state
    lda #STATE_DYING
    jsr change_state

@still_alive:
    rts

state_playing_exit:
    rts

; ==============================================================================
; State 3: STATE_DYING
; ==============================================================================
state_dying_enter:
    ; Set 3.0-second death explosion timer (150 PAL frames)
    lda #150
    sta g_state_timer
    rts

state_dying_update:
    ; Keep world in motion while death explosion animates
    ; Keep world in motion and advance player death explosion animation
    jsr player_update
    jsr weapons_update
    jsr starfield_update
    jsr enemies_update
    jsr hud_update
    jsr player_render
    jsr weapons_render
    jsr enemies_render

    ; Decrement death timer
    dec g_state_timer
    bne @done

    ; 3.0s expired: transition to Game Over screen
    lda #STATE_GAME_OVER
    jsr change_state

@done:
    rts

state_dying_exit:
    rts

; ==============================================================================
; State 4: STATE_GAME_OVER
; ==============================================================================
state_game_over_enter:
    ; 1. Despawn enemies, disable sprites, draw GAME OVER & final SCORE
    jsr game_over_trigger

    ; 2. Check if player score qualifies for Top 10
    jsr hiscore_check_qualify
    bcc @no_initials

    ; Qualifies! Enable initials entry
    jsr hiscore_entry_init
    lda #1
    sta g_entering_initials
    rts

@no_initials:
    lda #0
    sta g_entering_initials
    ; Set 5.0-second countdown timer (250 PAL frames)
    lda #250
    sta g_state_timer
    rts

state_game_over_update:
    lda g_entering_initials
    beq @normal_game_over_timer

    ; Player is entering initials: update initials entry (keyboard, cursor blink, commit)
    jsr hiscore_entry_update
    rts

@normal_game_over_timer:
    ; 1. Decrement 5.0-second countdown
    dec g_state_timer
    beq @to_title

    ; 2. Guard delay: don't allow skipping in the first 0.2s (frames 250..241)
    lda g_state_timer
    cmp #240
    bcs @done

    ; 3. Check for Fire button / Fire key newly pressed to skip early
    lda g_input_fire_pressed
    beq @done

@to_title:
    lda #STATE_TITLE
    jsr change_state

@done:
    rts

state_game_over_exit:
    ; Erase "GAME OVER" and "SCORE" text from screen
    jmp hud_clear_game_over
