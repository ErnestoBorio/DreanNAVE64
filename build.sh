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

# Assemble main.asm into C64 PRG binary with VICE debug labels
"$ACME_BIN" --cpu 6502 --labeldump bin/drean_nave_64.vs --vicelabels bin/vice.lbl src/main.asm

echo "==> Build successful: bin/drean_nave_64.prg"
