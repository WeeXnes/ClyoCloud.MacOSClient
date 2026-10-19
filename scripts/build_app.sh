#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Building ClyoMacClient (Release)..."
cd "$ROOT_DIR"

SDK_PATH="$(xcrun --show-sdk-path 2>/dev/null || echo '/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk')"
echo "==> Using macOS SDK: $SDK_PATH"

mkdir -p "$ROOT_DIR/build"
SWIFT_FILES=$(find "$ROOT_DIR/Sources/ClyoMacClient" -name "*.swift")

swiftc -sdk "$SDK_PATH" -O -o "$ROOT_DIR/build/ClyoCloud" $SWIFT_FILES

APP_NAME="ClyoCloud.app"
APP_DIR="$ROOT_DIR/build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Creating $APP_NAME bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$ROOT_DIR/build/ClyoCloud" "$MACOS_DIR/ClyoCloud"
chmod +x "$MACOS_DIR/ClyoCloud"

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy logo icon if exists
if [ -f "$ROOT_DIR/../ClyoCloud/public/wicon.png" ]; then
    cp "$ROOT_DIR/../ClyoCloud/public/wicon.png" "$RESOURCES_DIR/AppIcon.png"
fi

# Ad-hoc code sign the bundle for consistent macOS identity
codesign --force --deep -s - "$APP_DIR"

echo "==> Successfully created and signed $APP_DIR"
echo "You can launch it via: open '$APP_DIR'"
