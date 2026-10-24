#!/usr/bin/env zsh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

VERSION="v1.0"
if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
    V_RAW=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')
    if [[ -n "$V_RAW" ]]; then
        if [[ "$V_RAW" == v* || "$V_RAW" == V* ]]; then
            VERSION="$V_RAW"
        else
            VERSION="v$V_RAW"
        fi
    fi
fi

D64_TARGET="$SCRIPT_DIR/bin/drean_nave_64_${VERSION}.d64"
if [[ ! -f "$D64_TARGET" && -f "$SCRIPT_DIR/bin/drean_nave_64.d64" ]]; then
    D64_TARGET="$SCRIPT_DIR/bin/drean_nave_64.d64"
fi
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

