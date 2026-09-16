# Drean NAVE 64 Horizontal Shoot-'Em-Up Implementation Plan (6502 Assembly / ACME)

This document is the master technical roadmap for **Drean NAVE 64**, a horizontal space shoot-'em-up written in **pure 6502 Assembly** for the Commodore 64 using the **ACME** assembler.

---

## Technical Architecture & Memory Layout

- **Assembler**: ACME (`acme` 0.97, binary at `/opt/homebrew/bin/acme`).
- **Target Platform**: Commodore 64 (50 Hz PAL timing default).
- **Build Output**: `bin/drean_nave_64.prg` + VICE Debug Symbols `bin/drean_nave_64.vs`.
- **Interrupt Architecture**:
  - Scanline 240 hardware Raster IRQ (`raster_isr`) firing at start of VBLANK.
  - Zero-page / stack protection: Kernal RAM NMI vector (`$0318`) points to Kernal NMI exit routine (`$FEBC`) to guarantee 100% stack balance.
  - Timers & CIA interrupts stopped to eliminate interrupt collisions.

### Memory Map

| Address Range | Allocation / Usage |
| :--- | :--- |
| `$0801 - $080D` | C64 BASIC Stub Header (`10 SYS 2064`) |
| `$0810 - $1FFF` | Core Assembly Code (Main loop, IRQ handlers, Subroutines) |
| `$0400 - $07E7` | Screen RAM (40x25 character grid) |
| `$07F8 - $07FF` | VIC-II Hardware Sprite Pointers (Sprites 0..7) |
| `$2000 - $203F` | Player Ship Sprite Data (Block 128) |
| `$2280 - $22BF` | Player Shot Sprite Data (Block 138) |
| `$2300 - $23FF` | Enemy Alien Ship Sprite Data (Block 140) |
| `$2800 - $2FFF` | Custom Starfield Character Set Data (2048 bytes) |
| `$D800 - $DBE7` | Color RAM |

---

## Completed Phases

### Phase 0: Assembly Project Skeleton & ACME Build Loop [COMPLETED]
- [x] Set up modular 6502 assembly directory structure under `src/`.
- [x] Configured `build.sh` to assemble `src/main.asm` using ACME (`acme --cpu 6502`).
- [x] Configured `run_debugger.sh` to compile binary + VICE symbols (`.vs`) and launch **Retro Debugger**.
- [x] Configured `.vscode/tasks.json` (<kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>B</kbd> default build & debug launcher).
- [x] Embedded raw `.byte` sprite arrays and charset definitions directly into assembly source files. Deleted obsolete Python asset converters and PNG scripts.

### Phase 1: Hardware Core, IRQ & Open-Drain Input Subsystem [COMPLETED]
- [x] Hardware register equates (`src/c64_hardware.asm`).
- [x] Scanline 240 VIC-II Hardware Raster Interrupt (`raster_isr`) for deterministic 50 Hz frame synchronization.
- [x] CIA1 Joystick Port 2 scanning (Up, Down, Left, Right, Fire).
- [x] CIA1 Open-Drain Keyboard Matrix scanning:
  - Horizontal Key Set: `R`-`D`-`F`-`G`.
  - TATE Mode Key Set: `U`-`H`-`J`-`K`.
  - Fire Keys: **Left Shift** (PA1 / PB7, PB1), **Right Shift** (PA6 / PB4, PB6), **Spacebar** (PA7 / PB4).
- [x] Single-shot edge detection (`g_input_fire_pressed = current_fire & ~previous_fire`).

### Phase 2: Player Ship Subsystem [COMPLETED]
- [x] Player entity RAM variables (`g_player_x`, `g_player_y`, `g_player_alive`, `g_player_power`).
- [x] 8-way directional movement (2 pixels/frame).
- [x] Playfield screen clamping (`SPRITE_MIN_X`=24, `SPRITE_MAX_X`=320, `SPRITE_MIN_Y`=50, `SPRITE_MAX_Y`=240).
- [x] VIC-II Hardware Sprite 0 configuration (Multicolor mode: Cyan, White, Dark Gray).

### Phase 3: Player Weapons & Shooting Subsystem [COMPLETED]
- [x] Player shot sprite data (`$2280`, Block 138) in hi-res monochrome mode.
- [x] Latched single-shot fire request handling (`g_fire_requested`).
- [x] Ultra-high speed 50 pixels/frame rightward missile movement.
- [x] Right playfield border recycling (`X >= 320`).
- [x] Per-frame 7-color Energy palette cycling sequence (Cyan, Pink, Yellow, Dark Green, Light Green, Light Blue, Light Gray).
- [x] VIC-II Hardware Sprite 1 configuration & MSB bit toggling.

### Phase 4: High-Speed Parallax Starfield Subsystem [COMPLETED]
- [x] 2048-byte custom character set copied to VIC-II RAM at `$2800`.
- [x] 16-bit Galois LFSR pseudo-random generator with 64-entry weighted frequency distribution table.
- [x] Hardware fine scrolling (`VIC_CTRL2` / `$D016`).
- [x] 40x25 Screen RAM leftward array shifting on fine scroll underflow.

---

## Active & Upcoming Phases

### Phase 5: Enemy Waves & AI Motion Subsystem [IN PROGRESS]
**Goal**: Support multiple enemy alien ships spawning from the right border with smooth wave motion trajectories.

- [ ] Add multicolor enemy ship sprite data (`$2300` / Block 140) to `src/sprites_data.asm`.
- [ ] Implement active enemy pool (up to 4 active entities using Hardware Sprites 2..5).
- [ ] Implement sinusoidal wave motion using 16-entry signed delta Y table (`g_sine_table`).
- [ ] Implement enemy spawn timer, right-side spawning (`X = 340`, `Y = random 60..210`), and left-border recycling (`X < 16`).
- [ ] Update `src/enemies.asm` and integrate into main 50 Hz VBLANK loop in `src/main.asm`.

### Phase 6: Collision Detection & Explosions Subsystem
**Goal**: Detect collisions between missiles, enemies, and player ship, with visual explosions and score/life updates.

- [ ] Implement bounding box collision detection (Player Missiles vs Enemies; Player Ship vs Enemies).
- [ ] Multi-frame expanding explosion sprite animation.
- [ ] Decrement player lives on collision, trigger respawn invulnerability frames.
- [ ] Increment player score on enemy destroy.

### Phase 7: SID Sound Effects & Audio Subsystem
**Goal**: Add C64 SID chip sound effects.

- [ ] SID chip register initialization (`$D400 - $D41C`).
- [ ] Laser shot audio pulse/sweep on missile fire.
- [ ] Explosion crash sound effect on enemy kill.

### Phase 8: HUD & Game Flow State Machine
**Goal**: Add game status UI header line and state machine.

- [ ] Display `SCORE`, `LIVES`, and `HIGH SCORE` on top line of Screen RAM.
- [ ] Implement Title Screen, Game Loop, and Game Over / Restart state machine.

---

## Verification Plan

### Automated Build Verification
- Execute `./build.sh` (ACME assembler).
- Confirm zero compilation errors and generation of `bin/drean_nave_64.prg` and `bin/drean_nave_64.vs`.

### Emulator / Debugger Verification
- Launch via <kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>B</kbd> in **Retro Debugger**.
- Inspect hardware registers, sprite rendering, collision handling, and timing stability.
