# Drean NAVE 64 Horizontal Shoot-'Em-Up Implementation Plan (6502 Assembly / ACME)

This document is the master technical roadmap for **Drean NAVE 64**, a horizontal space shoot-'em-up written in **pure 6502 Assembly** for the Commodore 64 using the **ACME** assembler.

---

## Technical Architecture & Memory Layout

- **Assembler**: ACME (`acme` 0.97, binary at `/opt/homebrew/bin/acme`).
- **Target Platform**: Commodore 64 (50 Hz PAL timing default).
- **Build Output**: `bin/drean_nave_64.prg` + VICE Debug Symbols `bin/drean_nave_64.vs`.
- **Timing & Synchronization**:
  - Direct hardware synchronization to scanline 240 (`VIC_RASTER`) for deterministic 50 Hz PAL VBLANK execution.
  - Maskable interrupts disabled with `SEI` during gameplay (eliminating interrupt collisions, Kernal keyboard contention, and stack overflow).
  - Hardware NMI vector (`$0318`) points to a safe `RTI` stub to prevent RESTORE key or CIA2 timer crashes.
  - CIA timers stopped and CIA interrupts masked.

### Memory Map

| Address Range | Allocation / Usage |
| :--- | :--- |
| `$0801 - $080D` | C64 BASIC Stub Header (`10 SYS 2064`) |
| `$0810 - $1FFF` | Core Assembly Code (Main loop, Subsystems, Math tables) |
| `$0400 - $07E7` | Screen RAM (40x25 character grid) |
| `$07F8 - $07FF` | VIC-II Hardware Sprite Pointers (Sprites 0..7) |
| `$2000 - $203F` | Player Ship Sprite Data (Block 128) |
| `$2280 - $22BF` | Player Shot Sprite Data (Block 138) |
| `$2300 - $23FF` | Enemy Alien Ship Sprite Data (Block 140) |
| `$2800 - $2FFF` | Custom Starfield Character Set Data (2048 bytes) |
| `$D800 - $DBE7` | Color RAM |

---

## Development Phases

### Phase 0: Assembly Project Skeleton & ACME Build Loop
**Goal**: Establish a repeatable, clean 6502 assembly compile/run workflow and modular code layout.
- Modular 6502 assembly directory structure under `src/`.
- Minimal main entry program with standard BASIC stub (`10 SYS 2064` at `$0801`).
- Hardware initialization at `$0810` with black border/background and cleared Screen/Color RAM.
- Stable 50 Hz PAL frame loop synchronizing to scanline 240 (`VIC_RASTER`).
- Modular skeleton subsystem source files (`c64_hardware.asm`, `input.asm`, `player.asm`, `weapons.asm`, `starfield.asm`, `enemies.asm`, `collisions.asm`, `hud.asm`).
- Automated build script (`build.sh`) generating PRG and VICE debug symbol table (`.vs`).
- Integration with Retro Debugger launch script (`run_debugger.sh`) and VS Code build task (<kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>B</kbd>).

### Phase 1: Hardware Core, Screen & Input Subsystem
**Goal**: Handle all player input scanning deterministically with zero movement cross-talk.
- Joystick Port 2 reading via CIA1 Port A (`$DC00`) in input mode.
- Standard active-low Keyboard Matrix scanning on CIA1:
  - Horizontal Key Set: `R`-`D`-`F`-`G` (R=Up, D=Left, F=Down, G=Right).
  - TATE Mode Key Set: `U`-`H`-`J`-`K` (H=Up, J=Left, K=Down, U=Right).
  - Dedicated Fire Keys: Left Shift (Column 1, Row PB7), Right Shift (Column 6, Row PB4), Spacebar (Column 7, Row PB4).
- Matrix row isolation ensuring directional movement keys never trigger fire.
- Single-shot edge detection (`fire_pressed = current_fire & ~previous_fire`).
- Screen RAM verification marker verifying movement, boundaries, and fire feedback.

### Phase 2: Player Ship Subsystem
**Goal**: Render the player ship as a hardware sprite with smooth 8-way directional movement.
- Player entity RAM state (`g_player_x`, `g_player_y`, `g_player_alive`, `g_player_power`).
- 64-byte raw sprite data for the player ship loaded into VIC-II RAM (`$2000`, Block 128).
- VIC-II Hardware Sprite 0 configuration (Multicolor mode: Cyan individual color, White shared MC0, Dark Gray shared MC1).
- 8-way directional movement (2 pixels/frame) with boundary clamping (`SPRITE_MIN_X`=24, `SPRITE_MAX_X`=320, `SPRITE_MIN_Y`=50, `SPRITE_MAX_Y`=240).
- VIC-II Sprite 0 X/Y coordinate registers and MSB (bit 0 of `$D010`) management.

### Phase 3: Player Weapons & Shooting Subsystem
**Goal**: Implement a responsive shooting loop with latched single-shot fire and palette cycling.
- Hi-res monochrome player missile sprite loaded into VIC-II RAM (`$2280`, Block 138).
- Latched single-shot fire request handling (`g_fire_requested`), guaranteeing zero dropped taps and zero unwanted continuous auto-fire.
- Ultra-high speed 50 pixels/frame rightward missile movement.
- Right playfield border recycling (`X >= 320`) with overflow protection.
- 7-color per-frame Energy palette sequence cycling (Cyan, Pink, Yellow, Dark Green, Light Green, Light Blue, Light Gray).
- VIC-II Hardware Sprite 1 configuration and MSB (bit 1 of `$D010`) management.

### Phase 4: High-Speed Parallax Starfield Subsystem
**Goal**: Render a smooth, arcade-style scrolling starfield background with depth.
- 2048-byte custom character set loaded into VIC-II RAM at `$2800`.
- VIC-II memory setup (`$D018`) and fine scroll register (`$D016` / `VIC_CTRL2`).
- 16-bit Galois LFSR pseudo-random generator with a 64-entry weighted frequency distribution table.
- Smooth fine-scrolling (4 pixels/frame) and leftward 40x25 Screen RAM array shifting on underflow.

### Phase 5: Enemy Waves & AI Motion Subsystem
**Goal**: Support multiple enemy alien ships spawning from the right border with distinct wave trajectories.
- Multicolor alien enemy ship sprite data loaded into VIC-II RAM (`$2300`, Block 140).
- Active enemy pool supporting simultaneous enemies using VIC-II Hardware Sprites 2..5.
- Sinusoidal wave motion using signed delta lookup tables (`g_sine_table`).
- Enemy spawn timer, off-screen right entry (`X = 340`, `Y = random 60..210`), and left-border recycling (`X < 16`).
- Hardware sprite allocation and MSB handling for active enemies.

### Phase 6: Collision Detection & Explosions Subsystem
**Goal**: Detect missile-to-enemy and player-to-enemy impacts, spawn visual explosions, and handle player lives.
- Bounding box collision checks:
  - Player Missiles vs Enemies.
  - Player Ship vs Enemies.
- Multi-frame expanding explosion sprite animation sequences.
- Player damage feedback, life decrement, and respawn invulnerability frames.
- Score increments on enemy destruction.

### Phase 7: SID Sound Effects & Audio Subsystem
**Goal**: Integrate audio feedback using the Commodore 64 SID chip (`$D400 - $D41C`).
- SID register initialization, volume setup, and voice clearing.
- High-pitched pulse/noise sweep for player missile firing.
- Low-frequency noise crash for enemy explosions.
- Hit and respawn sound effects.

### Phase 8: HUD & Game Flow State Machine
**Goal**: Implement the arcade status display and overall game flow.
- Top status line in Screen RAM displaying `SCORE`, `LIVES`, and `HIGH SCORE`.
- Title Screen, Active Play, and Game Over / Restart state machine.
- Game reset handling to restart a fresh session without rebooting.

---

## Verification Plan

### Automated Build Verification
- Execute `./build.sh` (ACME assembler).
- Confirm zero compilation errors and generation of `bin/drean_nave_64.prg` and `bin/drean_nave_64.vs`.

### Emulator / Debugger Verification
- Launch via <kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>B</kbd> in **Retro Debugger**.
- Inspect hardware registers, sprite rendering, collision handling, and timing stability.
