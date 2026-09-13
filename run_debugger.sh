#!/usr/bin/env zsh
set -e

DEBUGGER_APP="/Users/petruza/Source/Drean64/RetroDebugger/Retro Debugger.app"
PRG_PATH="/Users/petruza/Source/drean NAVE 64/bin/drean_nave_64.prg"

if [ ! -f "$PRG_PATH" ]; then
    echo "==> Building project first..."
    ./build.sh
fi

echo "==> Launching Retro Debugger with $PRG_PATH..."
open -a "$DEBUGGER_APP" --args "$PRG_PATH"

