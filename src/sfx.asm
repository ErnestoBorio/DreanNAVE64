; ==============================================================================
; DreanNAVE64 - Dedicated 3-Voice Polyphonic SID Sound Effects Subsystem
; Target Architecture: MOS 6502 / Commodore 64 / MOS 6581/8580 SID ($D400)
; Assembly Syntax: ACME Assembler
; ==============================================================================
; Voice Allocation:
;   Voice 1 ($D400-$D406): Player Channel (SFX_LASER, SFX_START Lead)
;   Voice 2 ($D407-$D40D): Enemies & Detonations (SFX_ENEMY_SHOT, SFX_EXPLOSION_ENEMY,
;                          SFX_BOMB, SFX_PLAYER_DEATH Noise)
;   Voice 3 ($D40E-$D414): Bonuses, Alerts & UI (SFX_BONUS, SFX_LOW_ENERGY,
;                          SFX_KEY_CLICK, SFX_START Harmony, SFX_PLAYER_DEATH Saw)
; ==============================================================================

; ------------------------------------------------------------------------------
; SFX Identifier Constants (1..9)
; ------------------------------------------------------------------------------
SFX_NONE            = 0
SFX_START           = 1     ; Stage start fanfare ("READY!")
SFX_LASER           = 2     ; Player laser shot (Voice 1: pulse pitch slide)
SFX_ENEMY_SHOT      = 3     ; Enemy bullet shot (Voice 2: metallic chirp)
SFX_BONUS           = 4     ; Bonus item collected (Voice 3: 3-note arpeggio)
SFX_BOMB            = 5     ; Smart bomb blast (Voice 2: heavy rumble)
SFX_LOW_ENERGY      = 6     ; Low energy flashing alarm (Voice 3: warning beep)
SFX_EXPLOSION_ENEMY = 7     ; Enemy destroyed (Voice 2: noise burst)
SFX_PLAYER_DEATH    = 8     ; Player destruction (Voice 2+3: crash & dive)
SFX_KEY_CLICK       = 9     ; Initials typewriter click (Voice 3: short blip)
SFX_GAME_OVER       = 10    ; Ceremonial after-action anthem (Voice 1+2+3)

; ------------------------------------------------------------------------------
; Subroutine: sound_init
; Purpose: Silences and clears all 29 SID registers ($D400-$D41C), sets master
;          volume to 15 ($0F), and resets all channel tracking state variables.
; ==============================================================================
sound_init:
    ; Clear all 29 SID hardware registers ($D400-$D41C)
    ldx #$1c
    lda #0
-   sta SID_BASE, x
    dex
    bpl -

    ; Reset local channel state variables
    sta sfx_v1_id
    sta sfx_v1_timer
    sta sfx_v1_pitch_lo
    sta sfx_v1_pitch_hi

    sta sfx_v2_id
    sta sfx_v2_timer
    sta sfx_v2_priority
    sta sfx_v2_pitch_lo
    sta sfx_v2_pitch_hi

    sta sfx_v3_id
    sta sfx_v3_timer
    sta sfx_v3_priority
    sta sfx_v3_pitch_lo
    sta sfx_v3_pitch_hi

    ; Set Master Volume to Maximum (15) with no filter routing
    lda #$0f
    sta SID_MODE_VOL

    rts

; ==============================================================================
; Subroutine: sound_play_sfx
; Purpose: Triggers a sound effect across the 3 hardware voices.
; Input:   A = SFX ID (SFX_START..SFX_KEY_CLICK)
; Notes:   Preserves ALL registers (A, X, Y) and does not touch Zero Page.
; ==============================================================================
sound_play_sfx:
    sta sfx_id_temp
    stx sfx_x_temp
    sty sfx_y_temp

    cmp #SFX_START
    bne +
    jsr sfx_play_start
    jmp @sfx_restore

+   cmp #SFX_LASER
    bne +
    jsr sfx_play_laser
    jmp @sfx_restore

+   cmp #SFX_ENEMY_SHOT
    bne +
    jsr sfx_play_enemy_shot
    jmp @sfx_restore

+   cmp #SFX_BONUS
    bne +
    jsr sfx_play_bonus
    jmp @sfx_restore

+   cmp #SFX_BOMB
    bne +
    jsr sfx_play_bomb
    jmp @sfx_restore

+   cmp #SFX_LOW_ENERGY
    bne +
    jsr sfx_play_low_energy
    jmp @sfx_restore

+   cmp #SFX_EXPLOSION_ENEMY
    bne +
    jsr sfx_play_explosion
    jmp @sfx_restore

+   cmp #SFX_PLAYER_DEATH
    bne +
    jsr sfx_play_player_death
    jmp @sfx_restore

+   cmp #SFX_KEY_CLICK
    bne +
    jsr sfx_play_key_click
    jmp @sfx_restore

+   cmp #SFX_GAME_OVER
    bne @sfx_restore
    jsr sfx_play_game_over

@sfx_restore:
    ldy sfx_y_temp
    ldx sfx_x_temp
    lda sfx_id_temp
    rts

; ------------------------------------------------------------------------------
; 1. SFX_START: Triumphant Stage Start Fanfare ("READY!")
; 3-Voice Polyphonic Heroic Fanfare ("Hero's Launch"):
;   Voice 1: Lead Trumpet (50% square, soaring heroic melody & high G5 climax)
;   Voice 2: Harmony Horn (Sawtooth brass, driving thirds and fifths)
;   Voice 3: Bass Foundation (Triangle root pedal & harmonic motion)
; Total duration: 64 frames (1.28s), timed within the 75-frame READY banner.
; ------------------------------------------------------------------------------
sfx_play_start:
    ; Voice 1: Lead Trumpet - Note 1: G4 ($1A13)
    lda #0
    sta SID_V1_CTRL
    lda #$13
    sta SID_V1_FREQ_LO
    lda #$1a
    sta SID_V1_FREQ_HI
    lda #$08                    ; Attack 2ms, decay 300ms
    sta SID_V1_AD
    lda #$d0                    ; Sustain level 13, release 6ms
    sta SID_V1_SR
    lda #$08                    ; 50% pulse width (bright heroic brass)
    sta SID_V1_PW_HI
    lda #$00
    sta SID_V1_PW_LO
    lda #(SID_PULSE | SID_GATE)
    sta SID_V1_CTRL

    lda #SFX_START
    sta sfx_v1_id
    lda #64
    sta sfx_v1_timer

    ; Voice 2: Harmony Horn - Note 1: E4 ($15ED)
    lda #0
    sta SID_V2_CTRL
    lda #$ed
    sta SID_V2_FREQ_LO
    lda #$15
    sta SID_V2_FREQ_HI
    lda #$08
    sta SID_V2_AD
    lda #$c0                    ; Sustain level 12
    sta SID_V2_SR
    lda #(SID_SAWTOOTH | SID_GATE)
    sta SID_V2_CTRL

    lda #SFX_START
    sta sfx_v2_id
    lda #64
    sta sfx_v2_timer
    lda #4                      ; Priority 4 (locked during fanfare)
    sta sfx_v2_priority

    ; Voice 3: Bass Foundation - Note 1: C3 ($08B4)
    lda #0
    sta SID_V3_CTRL
    lda #$b4
    sta SID_V3_FREQ_LO
    lda #$08
    sta SID_V3_FREQ_HI
    lda #$08
    sta SID_V3_AD
    lda #$e0                    ; Sustain level 14
    sta SID_V3_SR
    lda #(SID_TRIANGLE | SID_GATE)
    sta SID_V3_CTRL

    lda #SFX_START
    sta sfx_v3_id
    lda #64
    sta sfx_v3_timer
    lda #4                      ; Priority 4
    sta sfx_v3_priority
    rts

; ------------------------------------------------------------------------------
; 2. SFX_LASER: Player Laser Shot (Dedicated Voice 1)
; Warm, mellow sci-fi laser beam:
; Smooth Triangle wave diving from ~1800 Hz down to ~450 Hz over 4 frames (80ms).
; Mellow timbre (no harsh high-harmonic pulse buzz) with reduced volume (Sustain = 7).
; ------------------------------------------------------------------------------
sfx_play_laser:
    lda #0
    sta SID_V1_CTRL             ; Gate off to reset envelope
    sta SID_V1_FREQ_LO
    lda #$78                    ; Frame 0: ~1800 Hz (warm mid-range start)
    sta SID_V1_FREQ_HI
    sta sfx_v1_pitch_hi
    lda #$08                    ; Attack = 2ms, Decay = 300ms
    sta SID_V1_AD
    lda #$70                    ; Sustain = 7 (~45% volume, soft and pleasant)
    sta SID_V1_SR
    lda #(SID_TRIANGLE | SID_GATE) ; Smooth, rounded Triangle waveform (no harsh treble)
    sta SID_V1_CTRL

    lda #SFX_LASER
    sta sfx_v1_id
    lda #4                      ; 4 frames (80ms) duration
    sta sfx_v1_timer
    rts

; ------------------------------------------------------------------------------
; 3. SFX_ENEMY_SHOT: Enemy Bullet Shot (Voice 2)
; Heavy Plasma Sawtooth (Option 3):
; Aggressive, full-spectrum Sawtooth wave diving from ~1800 Hz down to ~300 Hz
; over 5 frames (100ms) with menacing arcade presence ($E0 sustain).
; Priority = 2 (cuts through routine explosions, re-triggers on rapid fire).
; ------------------------------------------------------------------------------
sfx_play_enemy_shot:
    lda sfx_v2_timer
    beq @trigger_enemy_shot
    lda sfx_v2_priority
    cmp #3
    bcs @enemy_shot_skip        ; Bomb (3), Fanfare (4), or Player Death (4) active -> don't cut off

@trigger_enemy_shot:
    lda #0
    sta SID_V2_CTRL             ; Gate off to reset envelope
    sta SID_V2_FREQ_LO
    lda #$78                    ; Frame 0 attack: ~1800 Hz heavy plasma attack
    sta SID_V2_FREQ_HI
    sta sfx_v2_pitch_hi
    lda #$00                    ; Attack = 2ms, Decay = 6ms
    sta SID_V2_AD
    lda #$e0                    ; Sustain level 14 (loud, aggressive, punchy)
    sta SID_V2_SR
    lda #(SID_SAWTOOTH | SID_GATE) ; Rich Sawtooth waveform
    sta SID_V2_CTRL

    lda #SFX_ENEMY_SHOT
    sta sfx_v2_id
    lda #5                      ; 5 frames (100ms) duration
    sta sfx_v2_timer
    lda #2                      ; Priority 2 (above explosions)
    sta sfx_v2_priority
@enemy_shot_skip:
    rts

; ------------------------------------------------------------------------------
; 4. SFX_BONUS: Bonus Item Collected (Voice 3)
; Ascending 3-note arpeggio (E5 -> G5 -> C6 over 18 frames)
; Priority = 3
; ------------------------------------------------------------------------------
sfx_play_bonus:
    lda sfx_v3_timer
    beq @trigger_bonus
    lda sfx_v3_priority
    cmp #4
    bcs @bonus_skip             ; Player death active -> skip

@trigger_bonus:
    lda #0
    sta SID_V3_CTRL
    ; Note 1: E5 ($2be3)
    lda #$e3
    sta SID_V3_FREQ_LO
    lda #$2b
    sta SID_V3_FREQ_HI
    lda #$08                    ; Fast attack
    sta SID_V3_AD
    lda #$a0                    ; Medium release
    sta SID_V3_SR
    lda #(SID_TRIANGLE | SID_GATE)
    sta SID_V3_CTRL

    lda #SFX_BONUS
    sta sfx_v3_id
    lda #18
    sta sfx_v3_timer
    lda #3
    sta sfx_v3_priority
@bonus_skip:
    rts

; ------------------------------------------------------------------------------
; 5. SFX_BOMB: Smart Bomb Blast (Voice 2)
; Massive room-shaking noise burst + sub-bass rumble (36 frames)
; Priority = 3
; ------------------------------------------------------------------------------
sfx_play_bomb:
    lda sfx_v2_timer
    beq @trigger_bomb
    lda sfx_v2_priority
    cmp #4
    bcs @bomb_skip              ; Player death active -> skip

@trigger_bomb:
    lda #0
    sta SID_V2_CTRL
    lda #$00
    sta SID_V2_FREQ_LO
    lda #$12
    sta SID_V2_FREQ_HI
    sta sfx_v2_pitch_hi
    lda #$09                    ; Fast attack, medium decay
    sta SID_V2_AD
    lda #$f0                    ; Long sustain/release
    sta SID_V2_SR
    lda #(SID_NOISE | SID_GATE)
    sta SID_V2_CTRL

    lda #SFX_BOMB
    sta sfx_v2_id
    lda #36
    sta sfx_v2_timer
    lda #3
    sta sfx_v2_priority
@bomb_skip:
    rts

; ------------------------------------------------------------------------------
; 6. SFX_LOW_ENERGY: Low Energy Flashing Alarm (Voice 3)
; Urgent high warning beep ($3400 square wave, 5 frames)
; Priority = 2 (won't interrupt bonus chime or player death)
; ------------------------------------------------------------------------------
sfx_play_low_energy:
    lda sfx_v3_timer
    beq @trigger_low_energy
    lda sfx_v3_priority
    cmp #2
    bcs @low_energy_skip        ; Bonus (3) or Death (4) playing -> skip

@trigger_low_energy:
    lda #0
    sta SID_V3_CTRL
    lda #$00
    sta SID_V3_FREQ_LO
    lda #$34
    sta SID_V3_FREQ_HI
    lda #$00
    sta SID_V3_AD
    lda #$e0                    ; Sustain level 14 (AUDIBLE!)
    sta SID_V3_SR
    lda #$08
    sta SID_V3_PW_HI
    lda #$00
    sta SID_V3_PW_LO
    lda #(SID_PULSE | SID_GATE)
    sta SID_V3_CTRL

    lda #SFX_LOW_ENERGY
    sta sfx_v3_id
    lda #5
    sta sfx_v3_timer
    lda #2
    sta sfx_v3_priority
@low_energy_skip:
    rts

; ------------------------------------------------------------------------------
; 7. SFX_EXPLOSION_ENEMY: Enemy Destroyed (Voice 2)
; Snappy noise burst (14 frames)
; Priority = 1 (routine explosion, can be interrupted by laser)
; ------------------------------------------------------------------------------
sfx_play_explosion:
    lda sfx_v2_timer
    beq @trigger_explosion
    lda sfx_v2_priority
    cmp #2
    bcs @explosion_skip         ; Enemy Shot (2), Bomb (3), or Death (4) playing -> don't cut off

@trigger_explosion:
    lda #0
    sta SID_V2_CTRL
    lda #$00
    sta SID_V2_FREQ_LO
    lda #$28
    sta SID_V2_FREQ_HI
    sta sfx_v2_pitch_hi
    lda #$00
    sta SID_V2_AD
    lda #$52
    sta SID_V2_SR
    lda #(SID_NOISE | SID_GATE)
    sta SID_V2_CTRL

    lda #SFX_EXPLOSION_ENEMY
    sta sfx_v2_id
    lda #14
    sta sfx_v2_timer
    lda #1                      ; Priority 1
    sta sfx_v2_priority
@explosion_skip:
    rts

; ------------------------------------------------------------------------------
; 8. SFX_PLAYER_DEATH: Player Ship Destruction (Voice 2 + Voice 3)
; Dual-voice crash: heavy noise blast (Voice 2) + pitch dive (Voice 3) (36 frames)
; Priority = 4 (highest)
; ------------------------------------------------------------------------------
sfx_play_player_death:
    ; Voice 2: Heavy noise explosion
    lda #0
    sta SID_V2_CTRL
    lda #$00
    sta SID_V2_FREQ_LO
    lda #$40
    sta SID_V2_FREQ_HI
    sta sfx_v2_pitch_hi
    lda #$00
    sta SID_V2_AD
    lda #$e2
    sta SID_V2_SR
    lda #(SID_NOISE | SID_GATE)
    sta SID_V2_CTRL

    lda #SFX_PLAYER_DEATH
    sta sfx_v2_id
    lda #36
    sta sfx_v2_timer
    lda #4
    sta sfx_v2_priority

    ; Voice 3: Descending sawtooth dive ($2800 -> $0400)
    lda #0
    sta SID_V3_CTRL
    lda #$00
    sta SID_V3_FREQ_LO
    lda #$28
    sta SID_V3_FREQ_HI
    sta sfx_v3_pitch_hi
    lda #$00
    sta SID_V3_AD
    lda #$a2
    sta SID_V3_SR
    lda #(SID_SAWTOOTH | SID_GATE)
    sta SID_V3_CTRL

    lda #SFX_PLAYER_DEATH
    sta sfx_v3_id
    lda #36
    sta sfx_v3_timer
    lda #4
    sta sfx_v3_priority
    rts

; ------------------------------------------------------------------------------
; 9. SFX_KEY_CLICK: Initials Entry Typewriter Click (Voice 3)
; Crisp, tactile mechanical keystroke clack:
; 50% square wave at $1800 (~360 Hz) with Decay = 2 (~48ms loud natural percussive fade)
; Priority = 1
; ------------------------------------------------------------------------------
sfx_play_key_click:
    lda sfx_v3_timer
    beq @trigger_key_click
    lda sfx_v3_priority
    cmp #1
    bne @key_click_skip

@trigger_key_click:
    lda #0
    sta SID_V3_CTRL
    lda #$00
    sta SID_V3_FREQ_LO
    lda #$18
    sta SID_V3_FREQ_HI
    lda #$02                    ; Attack = 2ms, Decay = 2 (~48ms loud natural percussive fade)
    sta SID_V3_AD
    sta SID_V3_SR               ; Sustain = 0 (natural fade to silence)
    lda #$08                    ; 50% square wave (mechanical keyboard timbre)
    sta SID_V3_PW_HI
    lda #$00
    sta SID_V3_PW_LO
    lda #(SID_PULSE | SID_GATE)
    sta SID_V3_CTRL

    lda #SFX_KEY_CLICK
    sta sfx_v3_id
    lda #3
    sta sfx_v3_timer
    lda #1
    sta sfx_v3_priority
@key_click_skip:
    rts

; ==============================================================================
; 10. SFX_GAME_OVER: Star Ceremony Anthem
; 3-Voice Polyphonic Stately Ceremony ("The Throne Room & Star Ceremony"):
;   Voice 1: Ceremonial Trumpet (50% pulse wave, noble melody reaching high G5)
;   Voice 2: Regal Horns (Sawtooth brass, flowing ceremonial counterpoint)
;   Voice 3: Stately Bass Foundation (Deep triangle march pedal & root movement)
; Total duration: 216 frames (~4.32s at 50 Hz PAL)
; ==============================================================================
sfx_play_game_over:
    lda #$0f                    ; Ensure master volume is at maximum
    sta SID_MODE_VOL

    ; Voice 1: Ceremonial Trumpet - Initial Note: G4 ($1A13)
    lda #0
    sta SID_V1_CTRL
    lda #$13
    sta SID_V1_FREQ_LO
    lda #$1a
    sta SID_V1_FREQ_HI
    lda #$18                    ; Attack 5ms, Decay 300ms
    sta SID_V1_AD
    lda #$d4                    ; Sustain level 13, Release 200ms
    sta SID_V1_SR
    lda #$08                    ; 50% pulse width (bright ceremonial brass)
    sta SID_V1_PW_HI
    lda #$00
    sta SID_V1_PW_LO
    lda #(SID_PULSE | SID_GATE)
    sta SID_V1_CTRL

    lda #SFX_GAME_OVER
    sta sfx_v1_id
    lda #216
    sta sfx_v1_timer

    ; Voice 2: Regal Horns - Initial Note: E4 ($15ED)
    lda #0
    sta SID_V2_CTRL
    lda #$ed
    sta SID_V2_FREQ_LO
    lda #$15
    sta SID_V2_FREQ_HI
    lda #$18
    sta SID_V2_AD
    lda #$c4                    ; Sustain level 12, Release 200ms
    sta SID_V2_SR
    lda #(SID_SAWTOOTH | SID_GATE)
    sta SID_V2_CTRL

    lda #SFX_GAME_OVER
    sta sfx_v2_id
    lda #216
    sta sfx_v2_timer
    lda #4                      ; Priority 4 (locked during tune)
    sta sfx_v2_priority

    ; Voice 3: Stately Bass - Initial Note: C3 ($08B4)
    lda #0
    sta SID_V3_CTRL
    lda #$b4
    sta SID_V3_FREQ_LO
    lda #$08
    sta SID_V3_FREQ_HI
    lda #$08                    ; Attack 2ms, Decay 300ms
    sta SID_V3_AD
    lda #$e4                    ; Sustain level 14, Release 200ms
    sta SID_V3_SR
    lda #(SID_TRIANGLE | SID_GATE)
    sta SID_V3_CTRL

    lda #SFX_GAME_OVER
    sta sfx_v3_id
    lda #216
    sta sfx_v3_timer
    lda #4                      ; Priority 4
    sta sfx_v3_priority
    rts

; ==============================================================================
; Subroutine: sound_update
; Purpose: Called once per PAL frame (50 Hz). Updates active SFX channels.
; Notes:   Preserves ALL registers (A, X, Y).
; ==============================================================================
sound_update:
    pha
    txa
    pha
    tya
    pha

    jsr sound_update_v1
    jsr sound_update_v2
    jsr sound_update_v3

    pla
    tay
    pla
    tax
    pla
    rts

; ------------------------------------------------------------------------------
; Retrigger Helpers for Fanfare Brass Articulation
; Input: A = Frequency High Byte, X = Frequency Low Byte
; ------------------------------------------------------------------------------
sfx_retrigger_v1:
    pha
    lda #SID_PULSE
    sta SID_V1_CTRL
    stx SID_V1_FREQ_LO
    pla
    sta SID_V1_FREQ_HI
    lda #(SID_PULSE | SID_GATE)
    sta SID_V1_CTRL
    rts

sfx_retrigger_v2:
    pha
    lda #SID_SAWTOOTH
    sta SID_V2_CTRL
    stx SID_V2_FREQ_LO
    pla
    sta SID_V2_FREQ_HI
    lda #(SID_SAWTOOTH | SID_GATE)
    sta SID_V2_CTRL
    rts

sfx_retrigger_v3:
    pha
    lda #SID_TRIANGLE
    sta SID_V3_CTRL
    stx SID_V3_FREQ_LO
    pla
    sta SID_V3_FREQ_HI
    lda #(SID_TRIANGLE | SID_GATE)
    sta SID_V3_CTRL
    rts

; ------------------------------------------------------------------------------
; Helper: sound_update_v1 (Player Channel)
; ------------------------------------------------------------------------------
sound_update_v1:
    lda sfx_v1_timer
    bne +
    rts
+   dec sfx_v1_timer
    bne @v1_modulate

    ; Timer expired: silence Voice 1
    lda #0
    sta SID_V1_CTRL
    sta sfx_v1_id
    rts

@v1_modulate:
    lda sfx_v1_id
    cmp #SFX_LASER
    bne +
    jmp @v1_mod_laser

+   cmp #SFX_START
    bne +
    jmp @v1_mod_start

+   cmp #SFX_GAME_OVER
    bne +
    jmp @v1_mod_game_over

+   rts

@v1_mod_laser:
    ; Rapid pitch dive across frames 3, 2, 1
    ldx sfx_v1_timer
    lda laser_freq_hi_table, x
    sta SID_V1_FREQ_HI
    rts

@v1_mod_game_over:
    ; Voice 1 Ceremonial Trumpet Melody ("The Star Ceremony"):
    ; 216: G4 ($1A13) -> starts in sfx_play_game_over (ceremonial call)
    ; 204: C5 ($22CE) (held long and proud for 36 frames while Voice 2 fanfares!)
    ; 168: D5 ($2711) (step up)
    ; 156: E5 ($2BDA) (held high and noble for 36 frames while Voice 2 fanfares!)
    ; 120: F5 ($2E76) (majestic peak)
    ; 108: E5 ($2BDA)
    ; 96:  D5 ($2711)
    ; 84:  C5 ($22CE)
    ; 72:  G5 ($3426) (soaring climax on high G5 for 24 frames!)
    ; 48:  E5 ($2BDA)
    ; 36:  D5 ($2711)
    ; 24:  C5 ($22CE) (final grand resolution to tonic!)
    ; 1:   Release envelope fade
    lda sfx_v1_timer
    cmp #204
    bne +
    lda #$22                    ; C5 ($22CE)
    ldx #$ce
    jmp sfx_retrigger_v1

+   cmp #168
    bne +
    lda #$27                    ; D5 ($2711)
    ldx #$11
    jmp sfx_retrigger_v1

+   cmp #156
    bne +
    lda #$2b                    ; E5 ($2BDA)
    ldx #$da
    jmp sfx_retrigger_v1

+   cmp #120
    bne +
    lda #$2e                    ; F5 ($2E76)
    ldx #$76
    jmp sfx_retrigger_v1

+   cmp #108
    bne +
    lda #$2b                    ; E5 ($2BDA)
    ldx #$da
    jmp sfx_retrigger_v1

+   cmp #96
    bne +
    lda #$27                    ; D5 ($2711)
    ldx #$11
    jmp sfx_retrigger_v1

+   cmp #84
    bne +
    lda #$22                    ; C5 ($22CE)
    ldx #$ce
    jmp sfx_retrigger_v1

+   cmp #72
    bne +
    lda #$34                    ; G5 ($3426) - high peak climax!
    ldx #$26
    jmp sfx_retrigger_v1

+   cmp #48
    bne +
    lda #$2b                    ; E5 ($2BDA)
    ldx #$da
    jmp sfx_retrigger_v1

+   cmp #36
    bne +
    lda #$27                    ; D5 ($2711)
    ldx #$11
    jmp sfx_retrigger_v1

+   cmp #24
    bne +
    lda #$22                    ; C5 ($22CE)
    ldx #$ce
    jmp sfx_retrigger_v1

+   cmp #1
    bne +
    lda #$04                    ; Release fade
    sta SID_V1_SR
+   rts

@v1_mod_start:
    ; Voice 1 Lead Fanfare Melody ("Hero's Launch"):
    ; 64: G4 ($1A13) -> starts in sfx_play_start
    ; 57: C5 ($22CE) (soaring octave leap to tonic)
    ; 51: E5 ($2BDA) (triumphant high major third)
    ; 43: D5 ($2711) (heroic forward drive)
    ; 37: E5 ($2BDA) (heroic lift)
    ; 31: F5 ($2E76) (dramatic suspension)
    ; 23: G5 ($3426) (high G5 climax!)
    ; 1:  Release envelope
    lda sfx_v1_timer
    cmp #57
    bne +
    lda #$22                    ; Note 2: C5 ($22CE)
    ldx #$ce
    jmp sfx_retrigger_v1

+   cmp #51
    bne +
    lda #$2b                    ; Note 3: E5 ($2BDA)
    ldx #$da
    jmp sfx_retrigger_v1

+   cmp #43
    bne +
    lda #$27                    ; Note 4: D5 ($2711)
    ldx #$11
    jmp sfx_retrigger_v1

+   cmp #37
    bne +
    lda #$2b                    ; Note 5: E5 ($2BDA)
    ldx #$da
    jmp sfx_retrigger_v1

+   cmp #31
    bne +
    lda #$2e                    ; Note 6: F5 ($2E76)
    ldx #$76
    jmp sfx_retrigger_v1

+   cmp #23
    bne +
    lda #$34                    ; Note 7: G5 ($3426) - soaring climax!
    ldx #$26
    jmp sfx_retrigger_v1

+   cmp #1
    bne +
    lda #$02                    ; Smooth release on final frame
    sta SID_V1_SR
+   rts

; ------------------------------------------------------------------------------
; Helper: sound_update_v2 (Enemies & Detonations)
; ------------------------------------------------------------------------------
sound_update_v2:
    lda sfx_v2_timer
    bne +
    rts
+   dec sfx_v2_timer
    bne @v2_modulate

    ; Timer expired: silence Voice 2
    lda #0
    sta SID_V2_CTRL
    sta sfx_v2_id
    sta sfx_v2_priority
    rts

@v2_modulate:
    lda sfx_v2_id
    cmp #SFX_ENEMY_SHOT
    bne +
    jmp @v2_mod_enemy_shot

+   cmp #SFX_START
    bne +
    jmp @v2_mod_start

+   cmp #SFX_GAME_OVER
    bne +
    jmp @v2_mod_game_over

+   cmp #SFX_EXPLOSION_ENEMY
    bne +
    jmp @v2_mod_explosion

+   cmp #SFX_BOMB
    bne +
    jmp @v2_mod_bomb

+   cmp #SFX_PLAYER_DEATH
    bne +
    jmp @v2_mod_death

+   rts

@v2_mod_game_over:
    ; Voice 2 Regal Horns (Answering fanfares & counterpoint):
    ; 216: E4 ($15ED) -> starts in sfx_play_game_over
    ; 204: G4 ($1A13)
    ; 192: A4 ($1D45) (brass fanfare answer while V1 holds C5!)
    ; 180: C5 ($22CE) (soaring flourish while V1 holds C5!)
    ; 168: A4 ($1D45)
    ; 156: G4 ($1A13)
    ; 144: B4 ($20DA) (brass fanfare answer while V1 holds E5!)
    ; 132: D5 ($2711) (soaring flourish while V1 holds E5!)
    ; 120: C5 ($22CE)
    ; 108: G4 ($1A13)
    ; 96:  F4 ($173B)
    ; 84:  E4 ($15ED)
    ; 72:  B4 ($20DA) (brass harmony under V1's high G5!)
    ; 60:  D5 ($2711)
    ; 48:  C5 ($22CE)
    ; 36:  B4 ($20DA)
    ; 24:  G4 ($1A13) (pure fifth harmony to final tonic!)
    ; 1:   Release envelope fade
    lda sfx_v2_timer
    cmp #204
    bne +
    lda #$1a                    ; G4 ($1A13)
    ldx #$13
    jmp sfx_retrigger_v2

+   cmp #192
    bne +
    lda #$1d                    ; A4 ($1D45) - fanfare answer!
    ldx #$45
    jmp sfx_retrigger_v2

+   cmp #180
    bne +
    lda #$22                    ; C5 ($22CE) - flourish!
    ldx #$ce
    jmp sfx_retrigger_v2

+   cmp #168
    bne +
    lda #$1d                    ; A4 ($1D45)
    ldx #$45
    jmp sfx_retrigger_v2

+   cmp #156
    bne +
    lda #$1a                    ; G4 ($1A13)
    ldx #$13
    jmp sfx_retrigger_v2

+   cmp #144
    bne +
    lda #$20                    ; B4 ($20DA) - fanfare answer!
    ldx #$da
    jmp sfx_retrigger_v2

+   cmp #132
    bne +
    lda #$27                    ; D5 ($2711) - flourish!
    ldx #$11
    jmp sfx_retrigger_v2

+   cmp #120
    bne +
    lda #$22                    ; C5 ($22CE)
    ldx #$ce
    jmp sfx_retrigger_v2

+   cmp #108
    bne +
    lda #$1a                    ; G4 ($1A13)
    ldx #$13
    jmp sfx_retrigger_v2

+   cmp #96
    bne +
    lda #$17                    ; F4 ($173B)
    ldx #$3b
    jmp sfx_retrigger_v2

+   cmp #84
    bne +
    lda #$15                    ; E4 ($15ED)
    ldx #$ed
    jmp sfx_retrigger_v2

+   cmp #72
    bne +
    lda #$20                    ; B4 ($20DA)
    ldx #$da
    jmp sfx_retrigger_v2

+   cmp #60
    bne +
    lda #$27                    ; D5 ($2711)
    ldx #$11
    jmp sfx_retrigger_v2

+   cmp #48
    bne +
    lda #$22                    ; C5 ($22CE)
    ldx #$ce
    jmp sfx_retrigger_v2

+   cmp #36
    bne +
    lda #$20                    ; B4 ($20DA)
    ldx #$da
    jmp sfx_retrigger_v2

+   cmp #24
    bne +
    lda #$1a                    ; G4 ($1A13)
    ldx #$13
    jmp sfx_retrigger_v2

+   cmp #1
    bne +
    lda #$04
    sta SID_V2_SR
+   rts

@v2_mod_enemy_shot:
    ; Rapid alien laser dive across frames 4, 3, 2, 1
    ldx sfx_v2_timer
    lda enemy_shot_freq_hi_table, x
    sta SID_V2_FREQ_HI
    rts

@v2_mod_start:
    ; Voice 2 Harmony Horn (Sawtooth brass, driving fanfare chords):
    ; 64: E4 ($15ED) -> starts in sfx_play_start
    ; 57: G4 ($1A13)
    ; 51: C5 ($22CE)
    ; 43: B4 ($20DA)
    ; 37: C5 ($22CE)
    ; 31: D5 ($2711)
    ; 23: E5 ($2BDA) (major third above C climax!)
    ; 1:  Release envelope
    lda sfx_v2_timer
    cmp #57
    bne +
    lda #$1a                    ; G4 ($1A13)
    ldx #$13
    jmp sfx_retrigger_v2

+   cmp #51
    bne +
    lda #$22                    ; C5 ($22CE)
    ldx #$ce
    jmp sfx_retrigger_v2

+   cmp #43
    bne +
    lda #$20                    ; B4 ($20DA)
    ldx #$da
    jmp sfx_retrigger_v2

+   cmp #37
    bne +
    lda #$22                    ; C5 ($22CE)
    ldx #$ce
    jmp sfx_retrigger_v2

+   cmp #31
    bne +
    lda #$27                    ; D5 ($2711)
    ldx #$11
    jmp sfx_retrigger_v2

+   cmp #23
    bne +
    lda #$2b                    ; E5 ($2BDA)
    ldx #$da
    jmp sfx_retrigger_v2

+   cmp #1
    bne +
    lda #$02
    sta SID_V2_SR
+   rts

@v2_mod_explosion:
    ; Pitch down noise frequency slightly
    lda sfx_v2_pitch_hi
    sec
    sbc #$02
    bcc +
    sta sfx_v2_pitch_hi
    sta SID_V2_FREQ_HI
+   rts

@v2_mod_bomb:
    ; Low sub-bass oscillation
    lda sfx_v2_timer
    and #$03
    tax
    lda bomb_freq_table, x
    sta SID_V2_FREQ_HI
    rts

@v2_mod_death:
    ; Sweep noise down over 36 frames
    lda sfx_v2_pitch_hi
    sec
    sbc #$01
    bcc +
    sta sfx_v2_pitch_hi
    sta SID_V2_FREQ_HI
+   rts

; ------------------------------------------------------------------------------
; Helper: sound_update_v3 (Bonuses, Alerts & UI)
; ------------------------------------------------------------------------------
sound_update_v3:
    lda sfx_v3_timer
    bne +
    rts
+   dec sfx_v3_timer
    bne @v3_modulate

    ; Timer expired: silence Voice 3
    lda #0
    sta SID_V3_CTRL
    sta sfx_v3_id
    sta sfx_v3_priority
    rts

@v3_modulate:
    lda sfx_v3_id
    cmp #SFX_BONUS
    bne +
    jmp @v3_mod_bonus

+   cmp #SFX_START
    bne +
    jmp @v3_mod_start

+   cmp #SFX_GAME_OVER
    bne +
    jmp @v3_mod_game_over

+   cmp #SFX_PLAYER_DEATH
    bne +
    jmp @v3_mod_death

+   rts

@v3_mod_game_over:
    ; Voice 3 Processional March Bass (Deep Triangle foundation):
    ; 216: C3 ($08B4) -> starts in sfx_play_game_over
    ; 204: G2 ($0685)
    ; 192: C3 ($08B4)
    ; 180: E3 ($0AF7)
    ; 168: F3 ($0B9D)
    ; 156: F2 ($05CF)
    ; 144: G3 ($0D0A)
    ; 132: G2 ($0685)
    ; 120: A3 ($0EA2)
    ; 108: E3 ($0AF7)
    ; 96:  F3 ($0B9D)
    ; 84:  D3 ($09C4)
    ; 72:  G2 ($0685)
    ; 60:  G3 ($0D0A)
    ; 48:  C3 ($08B4)
    ; 36:  G2 ($0685)
    ; 24:  C2 ($045A) (lowest sub-bass tonic pedal!)
    ; 1:   Release envelope fade
    lda sfx_v3_timer
    cmp #204
    bne +
    lda #$06                    ; G2 ($0685)
    ldx #$85
    jmp sfx_retrigger_v3

+   cmp #192
    bne +
    lda #$08                    ; C3 ($08B4)
    ldx #$b4
    jmp sfx_retrigger_v3

+   cmp #180
    bne +
    lda #$0a                    ; E3 ($0AF7)
    ldx #$f7
    jmp sfx_retrigger_v3

+   cmp #168
    bne +
    lda #$0b                    ; F3 ($0B9D)
    ldx #$9d
    jmp sfx_retrigger_v3

+   cmp #156
    bne +
    lda #$05                    ; F2 ($05CF)
    ldx #$cf
    jmp sfx_retrigger_v3

+   cmp #144
    bne +
    lda #$0d                    ; G3 ($0D0A)
    ldx #$0a
    jmp sfx_retrigger_v3

+   cmp #132
    bne +
    lda #$06                    ; G2 ($0685)
    ldx #$85
    jmp sfx_retrigger_v3

+   cmp #120
    bne +
    lda #$0e                    ; A3 ($0EA2)
    ldx #$a2
    jmp sfx_retrigger_v3

+   cmp #108
    bne +
    lda #$0a                    ; E3 ($0AF7)
    ldx #$f7
    jmp sfx_retrigger_v3

+   cmp #96
    bne +
    lda #$0b                    ; F3 ($0B9D)
    ldx #$9d
    jmp sfx_retrigger_v3

+   cmp #84
    bne +
    lda #$09                    ; D3 ($09C4)
    ldx #$c4
    jmp sfx_retrigger_v3

+   cmp #72
    bne +
    lda #$06                    ; G2 ($0685)
    ldx #$85
    jmp sfx_retrigger_v3

+   cmp #60
    bne +
    lda #$0d                    ; G3 ($0D0A)
    ldx #$0a
    jmp sfx_retrigger_v3

+   cmp #48
    bne +
    lda #$08                    ; C3 ($08B4)
    ldx #$b4
    jmp sfx_retrigger_v3

+   cmp #36
    bne +
    lda #$06                    ; G2 ($0685)
    ldx #$85
    jmp sfx_retrigger_v3

+   cmp #24
    bne +
    lda #$04                    ; C2 ($045A) - sub-bass pedal
    ldx #$5a
    jmp sfx_retrigger_v3

+   cmp #1
    bne +
    lda #$04
    sta SID_V3_SR
+   rts

@v3_mod_bonus:
    ; 3-note ascending arpeggio: G5 at 12, C6 at 6
    lda sfx_v3_timer
    cmp #12
    bne +
    ; Note 2: G5 ($3537)
    lda #$37
    sta SID_V3_FREQ_LO
    lda #$35
    sta SID_V3_FREQ_HI
    rts
+   cmp #6
    bne +
    ; Note 3: C6 ($45a0)
    lda #$a0
    sta SID_V3_FREQ_LO
    lda #$45
    sta SID_V3_FREQ_HI
    rts

@v3_mod_start:
    ; Voice 3 Bass Foundation (Triangle, driving fanfare roots):
    ; 64: C3 ($08B4) -> starts in sfx_play_start
    ; 57: C3 ($08B4)
    ; 51: C3 ($08B4)
    ; 43: G3 ($0D0A) (dominant)
    ; 37: A3 ($0EA2) (Am root)
    ; 31: G3 ($0D0A) (dominant)
    ; 23: C3 ($08B4) (tonic resolution)
    ; 1:  Release envelope
    lda sfx_v3_timer
    cmp #57
    bne +
    lda #$08                    ; C3 ($08B4)
    ldx #$b4
    jmp sfx_retrigger_v3

+   cmp #51
    bne +
    lda #$08                    ; C3 ($08B4)
    ldx #$b4
    jmp sfx_retrigger_v3

+   cmp #43
    bne +
    lda #$0d                    ; G3 ($0D0A)
    ldx #$0a
    jmp sfx_retrigger_v3

+   cmp #37
    bne +
    lda #$0e                    ; A3 ($0EA2)
    ldx #$a2
    jmp sfx_retrigger_v3

+   cmp #31
    bne +
    lda #$0d                    ; G3 ($0D0A)
    ldx #$0a
    jmp sfx_retrigger_v3

+   cmp #23
    bne +
    lda #$08                    ; C3 ($08B4)
    ldx #$b4
    jmp sfx_retrigger_v3

+   cmp #1
    bne +
    lda #$02
    sta SID_V3_SR
+   rts

@v3_mod_death:
    ; Descending sawtooth dive ($28 down to $03)
    lda sfx_v3_pitch_hi
    sec
    sbc #$01
    cmp #$03
    bcc +
    sta sfx_v3_pitch_hi
    sta SID_V3_FREQ_HI
+   rts

; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; Frequency Modulation Data Tables
; ------------------------------------------------------------------------------
bomb_freq_table:
    !byte $14, $10, $0c, $08

laser_freq_hi_table:
    !byte $00                   ; 0: expired / silence
    !byte $1e                   ; 1: ~450 Hz tail
    !byte $35                   ; 2: ~800 Hz mid-low
    !byte $50                   ; 3: ~1200 Hz mid
    !byte $78                   ; 4: ~1800 Hz initial warm zap

enemy_shot_freq_hi_table:
    !byte $00                   ; 0: expired / silence
    !byte $14                   ; 1: ~300 Hz deep rumble tail
    !byte $20                   ; 2: ~480 Hz low-mid
    !byte $32                   ; 3: ~750 Hz mid
    !byte $50                   ; 4: ~1200 Hz upper-mid
    !byte $78                   ; 5: ~1800 Hz initial attack

; ------------------------------------------------------------------------------
; State Variables & Channel Trackers
; ------------------------------------------------------------------------------
sfx_id_temp:        !byte 0
sfx_x_temp:         !byte 0
sfx_y_temp:         !byte 0

sfx_v1_id:          !byte 0
sfx_v1_timer:       !byte 0
sfx_v1_pitch_lo:    !byte 0
sfx_v1_pitch_hi:    !byte 0

sfx_v2_id:          !byte 0
sfx_v2_timer:       !byte 0
sfx_v2_priority:    !byte 0
sfx_v2_pitch_lo:    !byte 0
sfx_v2_pitch_hi:    !byte 0

sfx_v3_id:          !byte 0
sfx_v3_timer:       !byte 0
sfx_v3_priority:    !byte 0
sfx_v3_pitch_lo:    !byte 0
sfx_v3_pitch_hi:    !byte 0




