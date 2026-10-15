#!/usr/bin/env zsh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEBUGGER_APP="/Users/petruza/Source/Drean64/RetroDebugger/Retro Debugger.app"
D64_PATH="$SCRIPT_DIR/bin/drean_nave_64.d64"
PRG_PATH="$SCRIPT_DIR/bin/drean_nave_64.prg"
SYMBOLS_PATH="$SCRIPT_DIR/bin/vice.lbl"

echo "==> Compiling latest C64 binary and D64 disk image..."
"$SCRIPT_DIR/build.sh"

TARGET_MEDIA="$D64_PATH"
if [[ ! -f "$TARGET_MEDIA" ]]; then
    TARGET_MEDIA="$PRG_PATH"
fi

DEBUGGER_ARGS=()
if [[ -f "$SYMBOLS_PATH" ]]; then
    DEBUGGER_ARGS+=(-symbols "$SYMBOLS_PATH")
fi

if [[ "$TARGET_MEDIA" == *.d64 ]]; then
    DEBUGGER_ARGS+=(-d64 "$TARGET_MEDIA" -autorundisk)
else
    DEBUGGER_ARGS+=(-prg "$TARGET_MEDIA")
fi

echo "==> Launching Retro Debugger with $TARGET_MEDIA..."
DEBUGGER_EXE="$DEBUGGER_APP/Contents/MacOS/Retro Debugger"
if pgrep -f "Retro Debugger" >/dev/null 2>&1 && [[ -x "$DEBUGGER_EXE" ]]; then
    "$DEBUGGER_EXE" -pass "${DEBUGGER_ARGS[@]}" &
    osascript -e 'tell application "Retro Debugger" to activate' 2>/dev/null || true
else
    open -a "$DEBUGGER_APP" --args "${DEBUGGER_ARGS[@]}"
fi
