#!/bin/bash

# Build script for Mouse Toucher app (Production)

APP_NAME="MouseToucher"
BUNDLE_ID="com.mousetoucher.app"
BUILD_DIR="build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo "=========================================="
echo "Building Mouse Toucher (Universal Binary)"
echo "=========================================="

# Clean previous build
rm -rf "$APP_PATH"
mkdir -p "$BUILD_DIR"

# Create app bundle structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Compile for Apple Silicon (arm64)
echo "📦 Compiling for Apple Silicon (arm64)..."
swiftc -o "$BUILD_DIR/${APP_NAME}_arm64" \
    -target arm64-apple-macos11.0 \
    -import-objc-header MultitouchBridge.h \
    -framework Cocoa \
    -framework ApplicationServices \
    -F /System/Library/PrivateFrameworks \
    -framework MultitouchSupport \
    -Xlinker -rpath -Xlinker /System/Library/PrivateFrameworks \
    Preferences.swift \
    TapDetector.swift \
    MultitouchManager.swift \
    AppDelegate.swift \
    main.swift

if [ $? -ne 0 ]; then
    echo "❌ arm64 compilation failed!"
    exit 1
fi

# Compile for Intel (x86_64)
echo "📦 Compiling for Intel (x86_64)..."
swiftc -o "$BUILD_DIR/${APP_NAME}_x86_64" \
    -target x86_64-apple-macos11.0 \
    -import-objc-header MultitouchBridge.h \
    -framework Cocoa \
    -framework ApplicationServices \
    -F /System/Library/PrivateFrameworks \
    -framework MultitouchSupport \
    -Xlinker -rpath -Xlinker /System/Library/PrivateFrameworks \
    Preferences.swift \
    TapDetector.swift \
    MultitouchManager.swift \
    AppDelegate.swift \
    main.swift

if [ $? -ne 0 ]; then
    echo "❌ x86_64 compilation failed!"
    exit 1
fi

# Create universal binary
echo "🔗 Creating universal binary..."
lipo -create \
    "$BUILD_DIR/${APP_NAME}_arm64" \
    "$BUILD_DIR/${APP_NAME}_x86_64" \
    -output "$APP_PATH/Contents/MacOS/$APP_NAME"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create universal binary!"
    exit 1
fi

# Clean up temporary files
rm "$BUILD_DIR/${APP_NAME}_arm64" "$BUILD_DIR/${APP_NAME}_x86_64"

# Copy Info.plist
cp Info.plist "$APP_PATH/Contents/"

# Ad-hoc sign the app bundle so macOS Accessibility permissions persist
echo "[34m[1m[0m"
echo "[34m[1m[0m"
echo "[34m[1mCodesigning app bundle...[0m"
codesign --force --deep --sign - "$APP_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Codesigning failed!"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ UNIVERSAL BINARY BUILD COMPLETE!"
echo "=========================================="
echo ""
echo "App location: $APP_PATH"
echo "Architectures: arm64 (Apple Silicon) + x86_64 (Intel)"
echo ""
echo "To run the app:"
echo "  open $APP_PATH"
echo ""
echo "To install the app (copy to Applications):"
echo "  cp -r $APP_PATH /Applications/"
echo ""
