# Drean NAVE 64

[![Platform](https://img.shields.io/badge/Platform-Commodore%2064%20%2F%20Drean%20Commodore-blue.svg)](https://en.wikipedia.org/wiki/Commodore_64)
[![Language](https://img.shields.io/badge/Language-6502%20Assembly-orange.svg)](https://github.com/ErnestoBorio/DreanNAVE64)
[![Assembler](https://img.shields.io/badge/Assembler-ACME-green.svg)](https://sourceforge.net/projects/acme-crossass/)

**Drean NAVE 64** is a high-octane horizontal/TATE arcade shoot-'em-up written in pure 6502 Assembly for the Commodore 64 and Drean Commodore 64. It is a tribute and demake of Videogamo Inc.'s legendary arcade machine **NAVE** (by Hernán Saez & Máximo Balestrini).

---

## Features

* **Authentic Arcade TATE Mode**: Designed for vertical (90° rotated) arcade play with dedicated controls and screen layout.
* **Rock-Solid 50 Hz PAL Engine**: Raster-synchronized execution running at a locked 50 frames per second.
* **Dual Raster Split & Fine-Scrolling**:
  * Static HUD on Character Row 0 (Status line, Score, Energy gauge, Timer).
  * Raster interrupt split right after scanline 58/59.
  * Smooth 4-pixel/frame fine-scrolling starfield across full 40 columns without jitter or clipping.
* **5-Tier Ship Evolution**:
  * Phase 1: Standard single blaster (5 HP).
  * Phase 2: Dual forward lasers.
  * Phase 3: Triple forward spread.
  * Phase 4: Hardware-scaled double cannons.
  * Phase 5: Hardware-scaled triple devastating artillery.
* **High-Speed Laser Subsystem**: 50 px/frame swept-box collision detection guaranteeing zero clipping through fast-moving enemies.
* **Bonus Item Pickups**:
  * `[P]` **Power / Evolution**: Upgrades weapon phase (or fully repairs shields at max phase).
  * `[B]` **Smart Bomb**: Triggers a full-screen shockwave destroying all active enemies.
  * `[E]` **Energy Shield**: Restores +1 HP.
* **Diverse Wave Formations**: Scout drones, sinusoidal wave squadrons, armored cruisers, homing spider scouts, and elite warships.
* **Full SID Audio Engine**:
  * Punchy arcade sound effects (laser fire, explosions, shield sparks, smart bombs).
  * Multi-voice *"Rhythm Is a Dancer"* SID music across title and high scores attract loop.
  * Dramatic Game Over anthem.
* **Authentic Commodore Disk Directory High Scores**:
  * Displays Top 10 pilot scores formatted as a Commodore 64 disk directory listing (`609 BLOCKS FREE.`, `READY.`, blinking block cursor).
  * Interactive 3-letter pilot initials entry with full keyboard support.
  * Auto-persists to **Device 8** disk image (`@0:HIGHSCORES`).
* **Automated D64 Disk Image Workflow**:
  * Formats and builds `bin/drean_nave_64.d64` containing both the game binary and high scores.
  * Preserves gameplay records across incremental builds.
  * Auto-generates initial factory table on first boot if missing.
  * Dedicated script and VS Code task to reset scores back to factory defaults.

---

## Controls

### Gameplay Controls (TATE Rotated Mode)

| Action | Joystick (Port 2) | Keyboard |
| :--- | :--- | :--- |
| **Move Up** (Forward) | Up | <kbd>U</kbd> |
| **Move Down** (Backward) | Down | <kbd>K</kbd> |
| **Move Left** | Left | <kbd>H</kbd> |
| **Move Right** | Right | <kbd>J</kbd> |
| **Fire Laser** | Fire Button | <kbd>Space</kbd>, <kbd>Left Shift</kbd>, <kbd>Right Shift</kbd> |

### High Score Entry
* **Letter Entry**: Type letters <kbd>A</kbd>–<kbd>Z</kbd> or numbers <kbd>0</kbd>–<kbd>9</kbd>.
* **Correction**: Press <kbd>DEL</kbd> / <kbd>Backspace</kbd>.
* **Confirm**: Press <kbd>Return</kbd>.

### Debug / Testing Shortcuts
* <kbd>Shift</kbd> + <kbd>F3</kbd>: Toggle Invincibility / God Mode.
* <kbd>Shift</kbd> + <kbd>P</kbd>: Force spawn an immediate Powerup item.

---

## Building and Running

### Prerequisites

* **ACME Cross-Assembler**:
  ```bash
  brew install acme
  ```
* **VICE Commodore Emulator** (provides `x64sc` and `c1541`):
  ```bash
  brew install vice
  ```
* **Python 3** (used to pre-bake the 8,000-byte title screen bitmap asset).

### Quick Build

To build the standalone PRG and unified D64 disk image:

```bash
./build.sh
```

Build outputs in `bin/`:
* `bin/drean_nave_64.prg`: Standalone Commodore 64 binary executable.
* `bin/drean_nave_64.d64`: Standard 1541 disk image (with autostart PRG & `highscores`).
* `bin/vice.lbl` / `bin/drean_nave_64.vs`: Debug symbol tables for VICE and Retro Debugger.

### Launching Emulators

* **VICE (with Rebuild)**:
  ```bash
  ./run_vice.sh
  ```
  Rebuilds the project (resetting high scores to factory defaults) and launches `x64sc` with Drive 8 attached in read/write mode.

* **VICE (Preserve High Scores / No Build)**:
  ```bash
  ./run_vice.sh --no-build
  ```
  Launches VICE using the existing D64 image without rebuilding, preserving saved high scores across play sessions.

* **Retro Debugger**:
  ```bash
  ./run_debugger.sh
  ```
  Launches C64 Retro Debugger with `-d64`, `-autorundisk`, and debug symbols loaded (also supports `--no-build`).

* **Reset High Scores**:
  ```bash
  ./delete_hiscores.sh
  ```
  Removes the `highscores` file from `bin/drean_nave_64.d64`. Next time the game launches, it will re-initialize to factory default scores. (Note: Running `./build.sh` also resets high scores to factory defaults).

### VS Code Integration

Pre-configured tasks are available under **Terminal $\rightarrow$ Run Task...**:
* `Build & Run Debugger` (<kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>B</kbd> default build task)
* `Build & Run VICE` (rebuilds and resets high scores)
* `Launch VICE (No Build)` (launches emulator without rebuilding; preserves saved high scores)
* `Build PRG Only`
* `Delete High Scores`

---

## Technical Architecture & Memory Layout

The game is written in modular 6502 assembly with strict zero-stack-corruption conventions and manual memory banking:

| Memory Address | Allocation & Purpose |
| :--- | :--- |
| `$0801 - $080D` | C64 BASIC Stub Header (`10 SYS 2064`) |
| `$0810 - $27FF` | Core Assembly Code (Main loop, IRQ handlers, Starfield, Collisions, HUD) |
| `$2800 - $2FFF` | Custom Starfield & HUD Character Set (2,048 bytes) |
| `$3000 - $35FF` | Hardware Sprite Data (Player, Weapons, Enemies, Explosions, Pickups) |
| `$3600 - $5551` | Gameplay Engine (Enemies AI, Powerups, Gamestate Machine, Title logic) |
| `$5552 - $7491` | Pre-Baked Title Screen Bitmap Asset (8,000 bytes) |
| `$7492 - $7CBF` | High Scores Subsystem & Table Persistence Logic |
| `$8000 - $83E7` | Hi-Res Title Screen RAM (VIC-II Bank 2) |
| `$8400 - $8EFF` | SID Sound Engine & *"Rhythm Is a Dancer"* Music Driver |
| `$A000 - $BF3F` | Hi-Res Title Display Bitmap RAM |
| `$D800 - $DBE7` | Color RAM |

---

## Credits & Acknowledgments

* **Original Concept & Arcade Design**: [Videogamo Inc.](https://videogamo.com/) – Hernán Saez & Máximo Balestrini.
* **Commodore 64 Demake**: Ernesto Borio ([@petruza](https://github.com/petruza)).
* **Homage**: Drean Commodore 64 (Argentina).

