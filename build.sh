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

# Build D64 disk image with game PRG and hiscores file
D64_TARGET="bin/drean_nave_64.d64"
PRG_FILE="bin/drean_nave_64.prg"
TMP_HISCORE="/tmp/nave_hiscores_sync.prg"

if command -v "$C1541_BIN" >/dev/null 2>&1 || [ -x "$C1541_BIN" ]; then
    echo "==> Creating D64 disk image: $D64_TARGET..."

    # 1. If target D64 already exists and has highscores, extract it to preserve gameplay scores
    HISCORES_FOUND=0
    if [ -f "$D64_TARGET" ]; then
        if "$C1541_BIN" -attach "$D64_TARGET" -read "highscores" "$TMP_HISCORE" >/dev/null 2>&1; then
            HISCORES_FOUND=1
        fi
    fi

    # 2. Format fresh D64 disk image and write game PRG
    rm -f "$D64_TARGET"
    if [ "$HISCORES_FOUND" -eq 1 ] && [ -f "$TMP_HISCORE" ]; then
        "$C1541_BIN" -format "drean nave 64,dn" d64 "$D64_TARGET" \
                    -write "$PRG_FILE" "drean nave 64" \
                    -write "$TMP_HISCORE" "highscores" >/dev/null
        rm -f "$TMP_HISCORE"
    else
        "$C1541_BIN" -format "drean nave 64,dn" d64 "$D64_TARGET" \
                    -write "$PRG_FILE" "drean nave 64" >/dev/null
    fi

    echo "==> Disk image created: $D64_TARGET"
else
    echo "==> Note: c1541 utility not found. Skipping D64 creation."
fi
