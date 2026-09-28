#!/usr/bin/env zsh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRG_PATH="$SCRIPT_DIR/bin/drean_nave_64.prg"
DISK_PATH=""
for candidate in \
    "$SCRIPT_DIR/tools/highscores.d64" \
    "$SCRIPT_DIR/tools/nave-highscore.d64" \
    "./tools/highscores.d64" \
    "./tools/nave-highscore.d64"; do
    if [[ -f "$candidate" ]]; then
        DISK_PATH="$candidate"
        break
    fi
done

DISK_ARGS=()
if [[ -n "$DISK_PATH" ]]; then
    DISK_ARGS=(-drive9type 1541 -drive9truedrive -attach9rw -9 "$DISK_PATH")
fi


echo "==> Compiling latest C64 binary..."
"$SCRIPT_DIR/build.sh"

# 1. Check if user specified a custom VICE path in environment
if [[ -n "$VICE_BIN" && -x "$VICE_BIN" ]]; then
    EXEC_CMD=("$VICE_BIN" "${DISK_ARGS[@]}" "$PRG_PATH")
elif [[ -n "$VICE_APP" && -d "$VICE_APP" ]]; then
    EXEC_CMD=(open -a "$VICE_APP" --args "${DISK_ARGS[@]}" "$PRG_PATH")
fi

# 2. Check for CLI executables in PATH and standard locations
if [[ -z "$EXEC_CMD" ]]; then
    for bin in x64sc x64; do
        if command -v "$bin" >/dev/null 2>&1; then
            EXEC_CMD=("$bin" "${DISK_ARGS[@]}" "$PRG_PATH")
            break
        elif [[ -x "/opt/homebrew/bin/$bin" ]]; then
            EXEC_CMD=("/opt/homebrew/bin/$bin" "${DISK_ARGS[@]}" "$PRG_PATH")
            break
        elif [[ -x "/usr/local/bin/$bin" ]]; then
            EXEC_CMD=("/usr/local/bin/$bin" "${DISK_ARGS[@]}" "$PRG_PATH")
            break
        fi
    done
fi

# 3. Check for macOS Application bundles
if [[ -z "$EXEC_CMD" ]]; then
    for app in \
        "/Applications/VICE/x64sc.app" \
        "/Applications/x64sc.app" \
        "/Applications/VICE.app" \
        "/Applications/VICE/x64.app" \
        "/Applications/x64.app" \
        "$HOME/Applications/VICE/x64sc.app" \
        "$HOME/Applications/x64sc.app" \
        "$HOME/Applications/VICE.app" \
        "$HOME/Applications/VICE/x64.app" \
        "$HOME/Applications/x64.app"; do
        if [[ -d "$app" ]]; then
            EXEC_CMD=(open -a "$app" --args "${DISK_ARGS[@]}" "$PRG_PATH")
            break
        fi
    done
fi

# 4. Check LaunchServices for registered app names
if [[ -z "$EXEC_CMD" ]]; then
    for app_name in "x64sc" "VICE" "x64"; do
        if open -Ra "$app_name" 2>/dev/null; then
            EXEC_CMD=(open -a "$app_name" --args "${DISK_ARGS[@]}" "$PRG_PATH")
            break
        fi
    done
fi

# 5. Run emulator or report missing binary
if [[ -n "$EXEC_CMD" ]]; then
    if [[ ${#DISK_ARGS[@]} -gt 0 ]]; then
        echo "==> Launching VICE with $PRG_PATH (attached Drive 9: $DISK_PATH)..."
    else
        echo "==> Launching VICE with $PRG_PATH..."
    fi
    "${EXEC_CMD[@]}"
else
    echo "==> Error: VICE emulator executable not found."
    echo ""
    echo "To run this script, please install VICE:"
    echo "  - Via Homebrew: brew install vice"
    echo "  - Or download the macOS bundle from https://sourceforge.net/projects/vice-emu/ and copy to /Applications"
    echo ""
    echo "Alternatively, you can export VICE_BIN or VICE_APP to point to your installation."
    exit 1
fi

