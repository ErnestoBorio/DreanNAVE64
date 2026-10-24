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

D64_PATH="$SCRIPT_DIR/bin/drean_nave_64_${VERSION}.d64"
if [[ ! -f "$D64_PATH" && -f "$SCRIPT_DIR/bin/drean_nave_64.d64" ]]; then
    D64_PATH="$SCRIPT_DIR/bin/drean_nave_64.d64"
fi
PRG_PATH="$SCRIPT_DIR/bin/drean_nave_64.prg"
SYMBOLS_PATH="$SCRIPT_DIR/bin/vice.lbl"

NO_BUILD=0
for arg in "$@"; do
    case "$arg" in
        --no-build|--skip-build|-n)
            NO_BUILD=1
            ;;
    esac
done

if [[ "$NO_BUILD" -eq 1 ]]; then
    echo "==> Skipping build (launching existing build without rebuilding)..."
    if [[ ! -f "$D64_PATH" && ! -f "$PRG_PATH" ]]; then
        echo "==> Note: No existing binary or disk image found. Running build.sh first..."
        "$SCRIPT_DIR/build.sh"
    fi
else
    echo "==> Compiling latest C64 binary and D64 disk image..."
    "$SCRIPT_DIR/build.sh"
fi

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

# Locate Retro Debugger / C64 Debugger across environments
DEBUGGER_APP="${DEBUGGER_APP:-${RETRO_DEBUGGER_APP:-}}"

# 1. Check relative sibling repositories & standard application locations
if [[ -z "$DEBUGGER_APP" || ! -d "$DEBUGGER_APP" ]]; then
    for candidate in \
        "$SCRIPT_DIR/../Drean64/RetroDebugger/Retro Debugger.app" \
        "$SCRIPT_DIR/../RetroDebugger/Retro Debugger.app" \
        "$SCRIPT_DIR/../RetroDebugger/RetroDebugger.app" \
        "$SCRIPT_DIR/../C64Debugger/C64 Debugger.app" \
        "$SCRIPT_DIR/../C64Debugger/C64Debugger.app" \
        "/Applications/Retro Debugger.app" \
        "/Applications/RetroDebugger.app" \
        "/Applications/C64 Debugger.app" \
        "/Applications/C64Debugger.app" \
        "$HOME/Applications/Retro Debugger.app" \
        "$HOME/Applications/RetroDebugger.app" \
        "$HOME/Applications/C64 Debugger.app" \
        "$HOME/Applications/C64Debugger.app"; do
        if [[ -d "$candidate" ]]; then
            DEBUGGER_APP="$candidate"
            break
        fi
    done
fi

# 2. Check macOS Spotlight metadata if still not found
if [[ -z "$DEBUGGER_APP" || ! -d "$DEBUGGER_APP" ]] && command -v mdfind >/dev/null 2>&1; then
    for name in "Retro Debugger.app" "RetroDebugger.app" "C64 Debugger.app" "C64Debugger.app"; do
        found="$(mdfind "kMDItemFSName == '$name'" 2>/dev/null | head -n 1)"
        if [[ -n "$found" && -d "$found" ]]; then
            DEBUGGER_APP="$found"
            break
        fi
    done
fi

# 3. Check for standalone CLI executable in PATH
DEBUGGER_BIN="${RETRO_DEBUGGER_BIN:-}"
if [[ -z "$DEBUGGER_APP" && -z "$DEBUGGER_BIN" ]]; then
    for bin in "Retro Debugger" "RetroDebugger" "retrodebugger" "C64 Debugger" "C64Debugger" "c64debugger"; do
        if command -v "$bin" >/dev/null 2>&1; then
            DEBUGGER_BIN="$bin"
            break
        fi
    done
fi

# 4. Launch debugger
if [[ -n "$DEBUGGER_APP" && -d "$DEBUGGER_APP" ]]; then
    echo "==> Launching Retro Debugger with $TARGET_MEDIA..."
    DEBUGGER_EXE=""
    for exe_candidate in \
        "$DEBUGGER_APP/Contents/MacOS/Retro Debugger" \
        "$DEBUGGER_APP/Contents/MacOS/RetroDebugger" \
        "$DEBUGGER_APP/Contents/MacOS/C64 Debugger" \
        "$DEBUGGER_APP/Contents/MacOS/C64Debugger"; do
        if [[ -x "$exe_candidate" ]]; then
            DEBUGGER_EXE="$exe_candidate"
            break
        fi
    done

    # If already running, pass new disk/prg via -pass hot-reload
    APP_NAME="$(basename "$DEBUGGER_APP" .app)"
    if pgrep -f "$APP_NAME" >/dev/null 2>&1 && [[ -n "$DEBUGGER_EXE" ]]; then
        "$DEBUGGER_EXE" -pass "${DEBUGGER_ARGS[@]}" &
        osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null || true
    else
        open -a "$DEBUGGER_APP" --args "${DEBUGGER_ARGS[@]}"
    fi
elif [[ -n "$DEBUGGER_BIN" ]]; then
    echo "==> Launching $DEBUGGER_BIN with $TARGET_MEDIA..."
    "$DEBUGGER_BIN" "${DEBUGGER_ARGS[@]}"
else
    echo "==> Error: Retro Debugger / C64 Debugger not found."
    echo ""
    echo "Please install Retro Debugger (or C64 Debugger) into /Applications,"
    echo "place it in a sibling folder, or export DEBUGGER_APP:"
    echo "  export DEBUGGER_APP=\"/path/to/Retro Debugger.app\""
    exit 1
fi
