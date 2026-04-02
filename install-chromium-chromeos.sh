#!/usr/bin/env bash
#
# Sets up D-Logic UFR NFC/RFID browser extensions for Chromium on Chrome OS Linux (Crostini) containers. Supports x86_64 and x86.
# Silent by default. Pass --verbose for output.
#
# Usage:
#   ./install-chromium-chromeos.sh [OPTIONS]
#
# Options:
#   --extension-id <id>     Chrome extension ID for allowed_origins.
#                           Default: kjfmmgpfhdohhcodbkaodgkidbenkgog
#   --skip-chromium         Skip Chromium installation.
#   --clone-dir <path>      Where to clone the repo. Default: ./dlogic-ufr-web-ext-chromeos
#   --verbose               Print progress to stdout.
#   --help                  Show this help message.
#

set -euo pipefail

EXTENSION_ID="kjfmmgpfhdohhcodbkaodgkidbenkgog"
SKIP_CHROMIUM=false
CLONE_DIR="./dlogic-ufr-web-ext-chromeos"
VERBOSE=false
REPO_URL="https://github.com/FerrenF/dlogic-ufr-web-ext-chromeos.git"
NATIVE_MSG_DIR="$HOME/.config/chromium/NativeMessagingHosts"
HOST_BINARY_DEST="/usr/local/bin/ufr"
MANIFEST_FILES=(
    "ufr.dlogic.chrome.json"
    "com.dlogic.native.json"
)

usage() {
    sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# \?//'
    sed -n '/^# Options:/,/^#$/p' "$0" | sed 's/^# \?//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --extension-id)
            EXTENSION_ID="$2"
            shift 2
            ;;
        --skip-chromium)
            SKIP_CHROMIUM=true
            shift
            ;;
        --clone-dir)
            CLONE_DIR="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            exit 1
            ;;
    esac
done

log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "$*"
    fi
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

detect_arch() {
    local machine
    machine="$(uname -m)"
    case "$machine" in
        x86_64) echo "x86_64" ;;
        i?86)   echo "x86" ;;
        *)      die "Unsupported architecture: $machine. Expected x86_64 or x86." ;;
    esac
}

ARCH="$(detect_arch)"
log "Detected architecture: $ARCH"

# Step 1: Install Chromium
if [[ "$SKIP_CHROMIUM" == true ]]; then
    log "Skipping Chromium installation."
else
    log "Installing Chromium..."
    sudo apt update -y -qq > /dev/null 2>&1
    sudo apt install -y -qq chromium > /dev/null 2>&1
fi

# Step 2: Clone the repo with submodules
if [[ -d "$CLONE_DIR/.git" ]]; then
    log "Repository exists at $CLONE_DIR, pulling..."
    git -C "$CLONE_DIR" pull --quiet
    git -C "$CLONE_DIR" submodule update --init --quiet
else
    log "Cloning repository..."
    git clone --recurse-submodules --quiet "$REPO_URL" "$CLONE_DIR"
fi

# Paths into submodule
SUBMODULE_LINUX_DIR="$CLONE_DIR/ufr-browser_extensions/browser_extensions/Chrome/Host/data/Linux"

if [[ ! -d "$SUBMODULE_LINUX_DIR" ]]; then
    die "Expected directory not found: $SUBMODULE_LINUX_DIR — repo structure may have changed."
fi

# Step 3: Create NativeMessagingHosts directory
mkdir -p "$NATIVE_MSG_DIR"

# Step 4: Copy and patch manifest files
ALLOWED_ORIGINS_JSON="[\"chrome-extension://${EXTENSION_ID}/\"]"

patch_manifest() {
    local src="$1"
    local dest="$2"

    if [[ ! -f "$src" ]]; then
        die "Manifest not found: $src"
    fi

    log "Patching $(basename "$src") -> $dest"

    python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    m = json.load(f)
m['allowed_origins'] = json.loads(sys.argv[2])
with open(sys.argv[3], 'w') as f:
    json.dump(m, f, indent=2)
    f.write('\n')
" "$src" "$ALLOWED_ORIGINS_JSON" "$dest"

    chmod 755 "$dest"
}

for manifest_file in "${MANIFEST_FILES[@]}"; do
    patch_manifest \
        "$SUBMODULE_LINUX_DIR/$manifest_file" \
        "$NATIVE_MSG_DIR/$manifest_file"
done

# Step 5: Install the native messaging host binary
HOST_BINARY_SRC="$SUBMODULE_LINUX_DIR/$ARCH/ufr"

if [[ ! -f "$HOST_BINARY_SRC" ]]; then
    die "Host binary not found for $ARCH at: $HOST_BINARY_SRC"
fi

log "Installing host binary ($ARCH) to $HOST_BINARY_DEST..."
sudo cp "$HOST_BINARY_SRC" "$HOST_BINARY_DEST"
sudo chmod 755 "$HOST_BINARY_DEST"

log "Setup complete."