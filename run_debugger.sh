#!/usr/bin/env zsh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEBUGGER_APP="/Users/petruza/Source/Drean64/RetroDebugger/Retro Debugger.app"
PRG_PATH="$SCRIPT_DIR/bin/drean_nave_64.prg"

echo "==> Compiling latest C64 binary..."
"$SCRIPT_DIR/build.sh"

echo "==> Launching Retro Debugger with $PRG_PATH..."
open -a "$DEBUGGER_APP" --args "$PRG_PATH"
