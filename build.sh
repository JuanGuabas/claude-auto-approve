#!/bin/bash
# Build Claude Auto-Approve macOS app
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClaudeAutoApprove"
APP_DIR="$SCRIPT_DIR/$APP_NAME.app"
INSTALL_DIR="/Applications/$APP_NAME.app"

echo "Building $APP_NAME..."

# Compile Swift
swiftc -o "$SCRIPT_DIR/$APP_NAME" \
    -framework Cocoa \
    -O \
    "$SCRIPT_DIR/$APP_NAME.swift"

echo "Compiled successfully"

# Create .app bundle
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

mv "$SCRIPT_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ClaudeAutoApprove</string>
    <key>CFBundleDisplayName</key>
    <string>Claude Auto-Approve</string>
    <key>CFBundleIdentifier</key>
    <string>com.poseido.claude-auto-approve</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>ClaudeAutoApprove</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Claude Auto-Approve needs to read Terminal content and send keystrokes to auto-approve Claude Code permission prompts.</string>
</dict>
</plist>
PLIST

echo "App bundle created at: $APP_DIR"

# Install to /Applications
echo ""
read -p "Install to /Applications? [Y/n] " -r
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    rm -rf "$INSTALL_DIR"
    cp -R "$APP_DIR" "$INSTALL_DIR"
    echo "Installed to $INSTALL_DIR"
    echo ""
    echo "IMPORTANT: Grant Accessibility permission!"
    echo "  System Settings → Privacy & Security → Accessibility"
    echo "  Add ClaudeAutoApprove.app"
    echo ""
    echo "Start with: open /Applications/ClaudeAutoApprove.app"
else
    echo ""
    echo "Run with: open $APP_DIR"
fi

echo ""
echo "Usage:"
echo "  - Click the menu bar icon (⚡ OFF) to see menu"
echo "  - Click 'Enable Auto-Approve' to start"
echo "  - Icon changes to '⚡ ON' when active"
echo "  - Auto-approves Claude Code permission prompts in Terminal/iTerm2"
echo "  - Click 'Disable Auto-Approve' when done"
