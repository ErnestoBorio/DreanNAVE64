#!/usr/bin/env zsh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
D64_TARGET="$SCRIPT_DIR/bin/drean_nave_64.d64"
TMP_HISCORE="/tmp/nave_hiscores_sync.prg"

# Clean up any temporary hiscores file
rm -f "$TMP_HISCORE"

# Find c1541 executable
C1541_BIN="/opt/homebrew/bin/c1541"
if [ ! -f "$C1541_BIN" ]; then
    C1541_BIN="c1541"
fi

if ! command -v "$C1541_BIN" >/dev/null 2>&1 && [ ! -x "$C1541_BIN" ]; then
    echo "==> Error: c1541 utility not found."
    exit 1
fi

if [ ! -f "$D64_TARGET" ]; then
    echo "==> Note: $D64_TARGET not found. Nothing to delete."
    exit 0
fi

echo "==> Deleting highscores from $D64_TARGET..."
"$C1541_BIN" -attach "$D64_TARGET" -delete "highscores" >/dev/null 2>&1 || true

echo "==> Updated directory of $D64_TARGET:"
"$C1541_BIN" -attach "$D64_TARGET" -list
echo "==> Done. On next launch, high scores will reset to factory defaults."

