#!/usr/bin/env zsh
set -e

DEBUGGER_APP="/Users/petruza/Source/Drean64/RetroDebugger/Retro Debugger.app"
PRG_PATH="/Users/petruza/Source/drean NAVE 64/bin/drean_nave_64.prg"

echo "==> Compiling latest C64 binary..."
./build.sh

echo "==> Launching Retro Debugger with $PRG_PATH..."
open -a "$DEBUGGER_APP" --args "$PRG_PATH"
