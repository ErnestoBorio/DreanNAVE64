#!/usr/bin/env zsh
set -e

# Find Oscar64 compiler executable
OSCAR64_BIN="/Users/petruza/Source/oscar64/bin/oscar64"
if [ ! -f "$OSCAR64_BIN" ]; then
    OSCAR64_BIN="/Users/petruza/Source/Drean64/oscar64/bin/oscar64"
fi

if [ ! -f "$OSCAR64_BIN" ]; then
    OSCAR64_BIN="oscar64"
fi

echo "==> Using Oscar64 compiler: $OSCAR64_BIN"

# Automatically run Python asset converter before compiling
if [ -f "tools/convert_assets.py" ]; then
    echo "==> Converting assets via Python..."
    python3 tools/convert_assets.py
fi

# Create output bin directory
mkdir -p bin

# Build PRG and VICE symbol label map
"$OSCAR64_BIN" -o=bin/drean_nave_64.prg -tf=prg -g src/main.c src/input.c src/player.c src/sprites_data.c src/charset_data.c src/gfx_assets.c src/starfield.c src/enemies.c src/collisions.c src/hud.c

echo "==> Build successful: bin/drean_nave_64.prg"
