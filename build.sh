#!/usr/bin/env zsh
set -e

# Find ACME assembler executable
ACME_BIN="/opt/homebrew/bin/acme"
if [ ! -f "$ACME_BIN" ]; then
    ACME_BIN="acme"
fi

echo "==> Using ACME Assembler: $ACME_BIN"

# Create output bin directory
mkdir -p bin

# Pre-bake title screen bitmap asset if source logo exists
if [ -f "tools/build_title_bitmap.py" ] && [ -f "assets/DreanNAVE64.png" ]; then
    echo "==> Pre-baking title bitmap asset..."
    python3 tools/build_title_bitmap.py
fi

# Assemble main.asm into C64 PRG binary with VICE debug labels
"$ACME_BIN" --cpu 6502 --labeldump bin/drean_nave_64.vs --vicelabels bin/vice.lbl src/main.asm

echo "==> Build successful: bin/drean_nave_64.prg"

# Find c1541 disk utility executable
C1541_BIN="/opt/homebrew/bin/c1541"
if [ ! -f "$C1541_BIN" ]; then
    C1541_BIN="c1541"
fi

# Read version from VERSION file
VERSION="v1.0"
if [ -f "VERSION" ]; then
    V_RAW=$(cat "VERSION" | tr -d '[:space:]')
    if [ -n "$V_RAW" ]; then
        if [[ "$V_RAW" == v* || "$V_RAW" == V* ]]; then
            VERSION="$V_RAW"
        else
            VERSION="v$V_RAW"
        fi
    fi
fi

# Build D64 disk image with game PRG (fresh factory state without saved highscores)
D64_FILENAME="drean_nave_64_${VERSION}.d64"
D64_TARGET="bin/$D64_FILENAME"
PRG_FILE="bin/drean_nave_64.prg"
TMP_HISCORE="/tmp/nave_hiscores_sync.prg"

rm -f "$TMP_HISCORE"

if command -v "$C1541_BIN" >/dev/null 2>&1 || [ -x "$C1541_BIN" ]; then
    echo "==> Creating fresh D64 disk image (resetting high scores to factory defaults): $D64_TARGET..."

    rm -f "$D64_TARGET"
    "$C1541_BIN" -format "drean nave 64,dn" d64 "$D64_TARGET" \
                -write "$PRG_FILE" "drean nave 64" >/dev/null

    # Also maintain a symlink to bin/drean_nave_64.d64 for compatibility with default tools
    (cd bin && ln -sf "$D64_FILENAME" "drean_nave_64.d64")

    echo "==> Disk image created: $D64_TARGET (symlinked as bin/drean_nave_64.d64)"
else
    echo "==> Note: c1541 utility not found. Skipping D64 creation."
fi
