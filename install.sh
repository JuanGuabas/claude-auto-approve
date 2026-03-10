#!/bin/bash
# One-line installer for Claude Auto-Approve
# Usage: curl -sL https://raw.githubusercontent.com/JuanGuabas/claude-auto-approve/main/install.sh | bash
set -e

echo "Installing Claude Auto-Approve..."

TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Download source
curl -sL https://raw.githubusercontent.com/JuanGuabas/claude-auto-approve/main/ClaudeAutoApprove.swift -o ClaudeAutoApprove.swift

# Compile
echo "Compiling..."
swiftc -o ClaudeAutoApprove -framework Cocoa -O ClaudeAutoApprove.swift

# Create .app bundle
APP="/Applications/ClaudeAutoApprove.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ClaudeAutoApprove "$APP/Contents/MacOS/ClaudeAutoApprove"

cat > "$APP/Contents/Info.plist" << 'PLIST'
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

# Cleanup
cd /
rm -rf "$TMPDIR"

echo ""
echo "Installed to /Applications/ClaudeAutoApprove.app"
echo ""
echo "IMPORTANT: Grant Accessibility permission first!"
echo "  System Settings > Privacy & Security > Accessibility"
echo "  Click + and add ClaudeAutoApprove"
echo ""
echo "Start: open /Applications/ClaudeAutoApprove.app"
echo "  - Menu bar shows: ⚡ OFF"
echo "  - Click to toggle auto-approve on/off"
echo "  - Works with Terminal.app and iTerm2"
