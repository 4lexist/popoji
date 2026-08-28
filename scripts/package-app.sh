#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
CONFIGURATION="${1:-release}"
APP_DIR="$PROJECT_DIR/dist/Popoji.app"
CONTENTS_DIR="$APP_DIR/Contents"
LOCAL_SIGNING_IDENTITY="Popoji Local Development"

AVAILABLE_IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null)"
if [[ -n "${POPOJI_CODESIGN_IDENTITY:-}" ]]; then
    SIGNING_IDENTITY="$POPOJI_CODESIGN_IDENTITY"
elif [[ "$AVAILABLE_IDENTITIES" == *\"$LOCAL_SIGNING_IDENTITY\"* ]]; then
    SIGNING_IDENTITY="$LOCAL_SIGNING_IDENTITY"
else
    SIGNING_IDENTITY="$(
        print -r -- "$AVAILABLE_IDENTITIES" \
            | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' \
            | head -n 1
    )"
fi

if [[ -z "$SIGNING_IDENTITY" || "$AVAILABLE_IDENTITIES" != *\"$SIGNING_IDENTITY\"* ]]; then
    print -u2 "No stable code-signing identity was found."
    print -u2 "Create a self-signed Code Signing certificate named '$LOCAL_SIGNING_IDENTITY'"
    print -u2 "in Keychain Access, or set POPOJI_CODESIGN_IDENTITY to an existing identity name."
    exit 1
fi

export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/swiftpm-cache"
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

cd "$PROJECT_DIR"
swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/Popoji" "$CONTENTS_DIR/MacOS/Popoji"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Signed with: $SIGNING_IDENTITY"
echo "$APP_DIR"
