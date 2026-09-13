# Drean NAVE 64 Horizontal Shoot-'Em-Up Implementation Plan

This document is the working plan for building Drean NAVE 64, a horizontal space shoot-'em-up for the Commodore 64 using Oscar64. The game should be built incrementally, with each phase producing a playable or verifiable milestone before moving on.

## Direction

- Genre: shoot-'em-up playable horizontally (standard TV) OR vertically in TATE mode (TV rotated 90° on its left side to match original vertical NAVE arcade feel).
- Screen Orientation:
  - Standard Horizontal Mode: Player advances right, stars scroll left.
  - TATE Vertical Mode (TV on left side): Native right-to-left scrolling becomes top-to-bottom scroll towards player ship at the bottom of the rotated screen.
- Controls & Input:
  - Joystick Input: Supported in both orientations (Port 2). Player physically rotates joystick 90° when playing in TATE mode.
  - Dual Keyboard Control Sets: The C64 computer/keyboard sits flat on the desk (it does not rotate, only the TV turns on its left side).
    - Horizontal Mode Keyboard Set: `R`-`D`-`F`-`G` keys.
    - TATE Mode Keyboard Set: `U`-`H`-`J`-`K` keys.
- Player ship: starts tiny, around 8x8 pixels.
- Progression: collecting power-ups makes the ship larger and increases missile output.
- Enemies: enter from the right (or top in TATE mode), move in distinct patterns, and shoot either straight left (down in TATE) or aimed toward the player.
- Enemy lanes: each enemy is assigned to the top, middle, or bottom third of the native C64 playfield (left, center, right columns in TATE mode).
- Lane boundaries: use the full 200-pixel C64 screen height divided into top `0-65`, middle `66-132`, and bottom `133-199`.
- World motion: the player ship faces right (up in TATE), player missiles travel right (up in TATE), and starry background character layer scrolls right-to-left (top-to-bottom in TATE).
- Aesthetic target: high-contrast black space with white pixel/line detail, dense star noise, mechanical ship forms, and a restrained arcade HUD.
- Asset strategy: graphics will be supplied later in a raw byte format. Until that format is known, use placeholder data behind stable asset interfaces.

## Technical Assumptions

- Target platform: Commodore 64.
- Toolchain: Oscar64.
- Timing default: develop and tune for PAL first, matching Argentina's PAL-N domestic C64 context; NTSC compatibility can be evaluated later.
- Screen mode: start with character-based graphics so the starry background can scroll cheaply.
- Main gameplay entities should use hardware sprites through Oscar64's sprite multiplexer once object counts exceed the physical eight-sprite limit.
- Sprites may use C64 multicolor mode and fat pixels for a clearly hardware-constrained C64 look, while the background uses custom character graphics.
- Keep tiny shots and simple effects eligible for character-layer drawing if sprites become too crowded on the same raster lines.
- The first implementation should prefer deterministic, table-driven behavior over dynamic allocation or complex runtime systems.
- Keep frame timing predictable; every phase should target a PAL 50 Hz update loop first.

## Phase 0: Project Skeleton And Build Loop

Goal: establish a repeatable compile/run workflow before gameplay begins.

Tasks:

- Create the Oscar64 project layout.
- Add a minimal `main` program that initializes the C64 screen, clears state, and enters a stable frame loop.
- Add build scripts or documented commands for producing a `.prg` and associated VICE label file (`.vs`).
- Add debugger launch script (`run_debugger.sh`) targeting `/Users/petruza/Source/Drean64/RetroDebugger/Retro Debugger.app`.
- Decide where generated or converted asset files will live.
- Create placeholder modules for input, rendering, entities, collisions, weapons, enemies, power-ups, HUD, and level scripting.

Acceptance:

- A `.prg` and `.vs` symbol file build reliably.
- The program boots cleanly in Retro Debugger (`/Users/petruza/Source/Drean64/RetroDebugger/Retro Debugger.app`).
- The frame loop runs without visible flicker or instability.

## Phase 1: Screen, Timing, And Input

Goal: get the basic runtime feeling solid.

Tasks:

- Initialize character graphics mode for the black-and-white starfield reference look.
- Reserve screen, color, charset, and sprite memory ranges deliberately so later asset data has a predictable layout.
- Add joystick input (Port 2) for up, down, left, right, and fire.
- Add dual keyboard input sets (C64 keyboard remains flat while TV rotates):
  - Horizontal Mode Key Set: `R`-`D`-`F`-`G` keys.
  - TATE Mode Key Set: `U`-`H`-`J`-`K` keys.
- Allow physically turning the joystick 90° for TATE mode without software remapping needed.
- Add fixed-rate frame synchronization (PAL 50 Hz).
- Add debug counters or visual markers only if they help verify timing.
- Define playfield bounds, leaving space for HUD if needed.

Acceptance:

- A visible placeholder player marker moves smoothly inside the playfield.
- Movement cannot leave the playable area.
- Fire input is detected cleanly via Joystick or Keyboard.
- Both keyboard sets and joystick controls operate correctly in their respective screen orientations.

## Phase 2: Tiny Player Ship Prototype

Goal: make the first 8x8 player ship playable.

Tasks:

- Represent the initial ship as a small hardware sprite.
- Reserve virtual sprite ownership for the player ship so it is never starved by enemies or shots.
- Decide per player ship stage whether the sprite is hires monochrome or multicolor fat-pixel art.
- Implement player position, velocity, acceleration if desired, and screen bounds.
- Add basic animation hooks, even if the first ship is static.
- Define the ship collision bounds separately from the visual size.
- Add temporary placeholder art until final raw bytes are supplied.

Acceptance:

- The player ship is visible, responsive, and approximately 8x8 pixels.
- Collision bounds can be inspected or reasoned about independently from the sprite art.

## Phase 3: Player Missiles

Goal: add the first satisfying shooting loop.

Tasks:

- Add a small pool of player missile entities.
- Start with sprite-based player missiles for clarity, then consider character-layer shots if the sprite budget becomes tight.
- Spawn missiles from the ship when fire is pressed.
- Move missiles from left to right.
- Despawn missiles when they leave the screen.
- Add fire rate limiting.
- Reserve data fields for future weapon upgrades: number of shots, offsets, speed, damage, and shot pattern.

Acceptance:

- The player can fire repeatedly.
- Missiles move cleanly and recycle without memory churn.
- Fire rate feels readable rather than noisy.

## Phase 4: Enemy Entity System

Goal: support multiple enemy ships entering from the right.

Tasks:

- Add a fixed enemy pool.
- Define enemy archetypes with placeholder sprite data, hit points, score value, movement pattern, and shooting behavior.
- Render enemies as virtual sprites managed by the multiplexer.
- Allow enemy sprites to use multicolor mode where the fat-pixel style improves readability and C64 character.
- Spawn enemies from the right edge.
- Despawn enemies when they leave the screen or are destroyed.
- Add simple enemy damage from player missiles.

Acceptance:

- Multiple enemies can appear, move, take hits, and disappear.
- Entity limits are explicit and stable.

## Phase 5: Enemy Movement Patterns

Goal: make enemy behavior distinct without overloading the CPU.

Tasks:

- Divide the playfield into top, middle, and bottom enemy lanes.
- Use fixed lane boundaries based on the full C64 screen height: top `0-65`, middle `66-132`, bottom `133-199`.
- Assign every spawned enemy to one lane and clamp or design its pattern to stay inside that third.
- Implement table-driven movement patterns.
- Start with a small set:
  - straight left
  - sine-like vertical drift using lookup tables
  - diagonal entry then level flight
  - pause-and-dive
  - wave formation
- Store pattern state per enemy using compact counters and indices.
- Keep movement data editable so patterns can become level content later.

Acceptance:

- Enemies visibly differ in motion.
- Patterns are deterministic and cheap to update.
- No enemy movement pattern leaves its assigned vertical third.
- New patterns can be added without rewriting the enemy core.

## Phase 6: Enemy Bullets

Goal: add enemy fire while keeping the screen readable.

Tasks:

- Add a fixed enemy bullet pool.
- Start with sprite-based enemy bullets, with a fallback path for drawing very small bullets into the character layer if multiplexing pressure is too high.
- Implement two bullet modes:
  - straight left
  - aimed toward the current player position
- Use simple integer velocity for aimed bullets.
- Add enemy fire cooldowns and spawn timing.
- Tune bullet speed and density around C64 readability.

Acceptance:

- Enemies can shoot left or toward the player.
- Enemy bullets collide with the player.
- Bullet counts remain capped and predictable.

## Phase 7: Collision And Damage Rules

Goal: create a consistent combat model.

Tasks:

- Use C64 hardware sprite collision registers for:
  - player missiles vs enemies
  - enemy bullets vs player
  - enemies vs player
- Handle player vs power-ups separately because power-ups are character-layer objects.
- Track enough ownership/type metadata per sprite to interpret hardware collision bits correctly.
- Read and clear sprite collision state at a consistent point in the frame.
- Add player health, lives, invulnerability frames, and hit feedback.
- Add enemy death feedback using simple sprite flashes or particles if affordable.

Acceptance:

- Combat has clear consequences.
- The player cannot be instantly damaged repeatedly by one contact.
- No bounding-box hitbox calculations are required for sprite objects.
- Power-up collection works through character-cell or coarse position overlap.

## Phase 8: Power-Ups And Ship Growth

Goal: implement the central progression idea.

Tasks:

- Add collectible power-up entities.
- Render bonuses and power-ups as fixed 2x2 character objects in the scrolling starfield layer so they do not consume sprite budget.
- Define power levels for the player ship.
- For each power level, define:
  - visual size
  - collision bounds
  - missile count
  - missile spawn offsets
  - fire rate
  - optional damage or missile speed changes
- Start with three ship states:
  - tiny 8x8 ship, single shot
  - small/medium ship stages that still fit in one 24x21 hardware sprite
  - large ship using 2x scaled hardware sprite expansion on both X and Y axes, up to 48x42 pixels maximum
- Decide whether growing larger is purely beneficial or also increases risk because of a larger hitbox.
- Use 2 or 3 unscaled single-sprite growth stages before switching to the 2x scaled large ship.

Acceptance:

- Picking up a power-up changes the ship and weapon behavior.
- Growth is visible and mechanically meaningful.
- Weapon upgrades do not exceed sprite, missile, or CPU budgets.

## Sprite Management Strategy

Goal: make player, enemy, and shot sprites coexist while character/background power-ups remain collectible and readable.

Initial plan:

- Use Oscar64's sprite multiplexer for virtual sprites after the first simple prototype.
- Keep all game objects in fixed pools, then submit only active visible objects to the multiplexer each frame.
- Treat each vertical third as an 8-sprite budget zone.
- Each third can contain at most 8 sprites at once: up to 1 player sprite if the player is currently in that band, 1 player shot, 3 enemies, and 3 enemy shots.
- When the player is in the final 2x scaled form, it still uses one sprite slot, but its larger collision and raster footprint must be considered.
- Give the player ship highest priority.
- Give enemy bullets higher priority than player missiles because they affect survival.
- Draw power-ups into the scrolling character/starfield layer instead of spending sprites on them.
- Keep player missiles cheap and visually narrow; if needed, render them through character-layer overlays instead of spending many sprites.
- Cap dense horizontal rows so the game does not ask the C64 to display more than eight sprites on the same raster line.
- Design waves around top/middle/bottom enemy lanes to reduce same-raster-line sprite collisions.
- Avoid spawning too many enemies and shots in the same lane at once.
- Use sprite expansion for the final large player ship, not composed multi-sprite art.

Starting virtual sprite budget:

- player ship: 1 global sprite for all stages; final large form uses 2x X/Y sprite expansion, up to 48x42 pixels
- player shots: 1 sprite per third
- enemy ships: 3 sprites per third
- enemy shots: 3 sprites per third
- bonus/power-ups: fixed 2x2 character/background objects, not part of the sprite budget
- explosions/effects: optional and lowest priority

Acceptance:

- The first playable version works without multiplexing.
- The next version uses Oscar64's multiplexer for at least 16 virtual sprites.
- Object priority rules are documented before adding dense enemy waves.
- No wave design depends on more than eight visible sprites inside one vertical third.

## Phase 9: Background And Scrolling

Goal: sell the left-to-right movement without blocking gameplay.

Tasks:

- Add a starfield scrolling from right to left, opposite the player's forward direction.
- Use character-based scrolling as the first approach.
- Define 8 reusable star characters for different densities and shapes.
- Define 4-character, 2x2-cell graphics for each power-up or bonus type.
- Place power-ups directly in the scrolling background map so they cost no sprites.
- Use layered star speeds only if affordable after the basic character scroll is stable.
- Add occasional mechanical/space debris character patterns inspired by the references if charset space allows.
- Make sure background brightness does not hide missiles or bullets.

Acceptance:

- The screen clearly feels like forward motion through space.
- Gameplay objects remain readable over the background.
- Character scrolling cost is predictable.

## Phase 10: HUD And Game State

Goal: add the arcade frame around the action.

Tasks:

- Add score, lives, power level, and energy/health display.
- Use chunky monochrome UI styling consistent with the references.
- Add start, game over, and restart states.
- Keep HUD updates efficient by changing only dirty values where possible.

Acceptance:

- The player can start, play, die, and restart.
- HUD information is readable and does not crowd the playfield.

## Phase 11: Level Scripting And Waves

Goal: turn isolated enemies into a short playable stage.

Tasks:

- Add a timeline or event script for spawning enemy waves.
- Define spawn events with time, archetype, position, pattern, and shoot mode.
- Include the enemy lane in each spawn event.
- Add power-up drops either scripted or tied to enemy kills.
- Create a first short stage of 60-90 seconds.
- Tune difficulty around the tiny starting ship and early upgrades.

Acceptance:

- A complete short level can be played from start to finish.
- Enemy waves feel authored rather than random.
- Enemy lane usage keeps the screen readable and reduces sprite multiplexer pressure.
- Power-ups arrive at useful moments.

## Phase 12: Asset Pipeline

Goal: integrate the final graphics once the raw byte format is known.

Tasks:

- Document the supplied raw byte format:
  - dimensions
  - bit order
  - bytes per row
  - color assumptions
  - hires sprite vs multicolor sprite mode
  - sprite vs character data
  - animation frame layout
- Write a Python graphics transformation tool (`tools/convert_assets.py`) using Python (e.g. `Pillow` / standard library).
- Import player ship sizes, enemies, bullets, power-ups, background tiles, and HUD glyphs.
- Convert PNG sprite sources into either hires 24x21 sprite data (64 bytes per frame) or multicolor 12x21 logical-pixel sprite data stored in C64 hardware byte layout.
- Convert PNG character sources into 8x8 custom character data (8 bytes per character), including star characters and 2x2 power-up tiles.
- Add validation in Python to catch wrong dimensions, invalid palette indexes, or unexpected byte counts.
- Keep placeholder assets available for debugging.

Acceptance:

- Supplied art can be converted or included repeatably.
- Asset errors fail loudly during build or conversion.
- Runtime code does not need to know about source art formats.

## Phase 13: Audio

Goal: add sound once the core game is stable.

Tasks:

- Add basic SID sound effects:
  - player shot
  - enemy shot
  - enemy destroyed
  - player hit
  - power-up collected
- Add a simple music or ambience plan if memory and timing allow.
- Make sure audio updates do not disturb gameplay timing.

Acceptance:

- Core actions have clear audio feedback.
- Sound can be disabled or simplified if timing becomes tight.

## Phase 14: Performance Pass

Goal: protect the frame rate and memory budget.

Tasks:

- Measure worst-case active enemies, bullets, missiles, and background updates.
- Reduce per-frame work using fixed pools, lookup tables, and update staggering where appropriate.
- Tune Oscar64 sprite multiplexing limits and raster interrupt slots only after measuring real object counts.
- Check memory layout for code, data, screen memory, color memory, sprite data, charset data, and music.

Acceptance:

- Worst-case gameplay remains stable.
- Entity caps are documented.
- Any tradeoffs are explicit.

## Phase 15: Polish Pass

Goal: improve feel and presentation without changing the foundation.

Tasks:

- Tune player speed, firing rhythm, bullet speed, enemy hit points, and power-up frequency.
- Add spawn warnings or readable entry spacing if enemies feel unfair.
- Add small visual effects: flashes, debris pixels, trails, or short explosions.
- Improve title and transition screens using the reference aesthetic.
- Playtest on emulator and, if available, real hardware.

Acceptance:

- The first stage feels coherent, readable, and replayable.
- The game has a recognizable identity even before more stages are added.

## Early Data Structures To Keep Stable

These are not final code decisions, but they should guide the first implementation:

- `PlayerState`: position, size/power level, health, invulnerability timer, fire cooldown.
- `Shot`: active flag, position, velocity, damage, owner/type.
- `Enemy`: active flag, archetype, position, health, pattern id, pattern timer, fire timer.
- `PowerUp`: active flag, character-cell position, type, collected flag.
- `WaveEvent`: frame/time, enemy archetype, lane, spawn position, movement pattern, shoot mode.
- `SpriteAsset`: dimensions, frame count, byte pointer, flags for format/layout.
- `VirtualSprite`: active flag, priority, position, sprite frame pointer/index, color, multicolor flag, expansion flags, owner/entity id.

## Open Decisions

- Exact character memory layout, charset allocation, and scroll buffer strategy.
- Sprite art mode per object class: hires monochrome, multicolor fat-pixel, or mixed.
- Which object types can fall back from virtual sprites to character-layer drawing when sprite pressure is high.
- Exact sizes and art for the 2 or 3 unscaled single-sprite player growth stages.
- Final virtual sprite cap and Oscar64 multiplexer settings.
- Exact raw byte format for supplied art.
- Whether NTSC timing compatibility is needed after the PAL-first version is stable.
- Whether ship growth increases collision size or keeps a smaller forgiving hitbox.

## First Playable Target

The first meaningful milestone should be:

- black background with scrolling stars
- tiny 8x8 player ship
- joystick movement
- single player missile stream
- one enemy archetype entering from the right
- one enemy movement pattern
- enemy damage/destruction
- no final art required

This keeps the first version small enough to finish quickly while proving the core Oscar64/C64 loop.
