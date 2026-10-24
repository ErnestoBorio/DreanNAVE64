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

DISK_ARGS=(-drive8type 1541 -drive8truedrive -attach8rw)

# 1. Check if user specified a custom VICE path in environment
if [[ -n "$VICE_BIN" && -x "$VICE_BIN" ]]; then
    EXEC_CMD=("$VICE_BIN" "${DISK_ARGS[@]}" "$TARGET_MEDIA")
elif [[ -n "$VICE_APP" && -d "$VICE_APP" ]]; then
    EXEC_CMD=(open -a "$VICE_APP" --args "${DISK_ARGS[@]}" "$TARGET_MEDIA")
fi

# 2. Check for CLI executables in PATH and standard locations
if [[ -z "$EXEC_CMD" ]]; then
    for bin in x64sc x64; do
        if command -v "$bin" >/dev/null 2>&1; then
            EXEC_CMD=("$bin" "${DISK_ARGS[@]}" "$TARGET_MEDIA")
            break
        elif [[ -x "/opt/homebrew/bin/$bin" ]]; then
            EXEC_CMD=("/opt/homebrew/bin/$bin" "${DISK_ARGS[@]}" "$TARGET_MEDIA")
            break
        elif [[ -x "/usr/local/bin/$bin" ]]; then
            EXEC_CMD=("/usr/local/bin/$bin" "${DISK_ARGS[@]}" "$TARGET_MEDIA")
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
            EXEC_CMD=(open -a "$app" --args "${DISK_ARGS[@]}" "$TARGET_MEDIA")
            break
        fi
    done
fi

# 4. Check LaunchServices for registered app names
if [[ -z "$EXEC_CMD" ]]; then
    for app_name in "x64sc" "VICE" "x64"; do
        if open -Ra "$app_name" 2>/dev/null; then
            EXEC_CMD=(open -a "$app_name" --args "${DISK_ARGS[@]}" "$TARGET_MEDIA")
            break
        fi
    done
fi

# 5. Run emulator or report missing binary
if [[ -n "$EXEC_CMD" ]]; then
    echo "==> Launching VICE with $TARGET_MEDIA (Drive 8)..."
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

