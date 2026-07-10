#!/bin/bash
set -e

echo "=== Jump Desktop Clipboard Bridge Installer (Mac) ==="

# Define paths
INSTALL_DIR="$HOME/.jump_clipboard_bridge"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$LAUNCH_AGENTS_DIR/com.jump.clipboard-bridge.plist"

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Compile Swift code
echo "Compiling Swift daemon..."
swiftc -O ClipboardBridge.swift -o "$INSTALL_DIR/ClipboardBridge"

# Create LaunchAgent plist
echo "Creating LaunchAgent..."
cat <<EOF > "$PLIST_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.jump.clipboard-bridge</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/ClipboardBridge</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# Load the daemon
echo "Loading daemon into launchd..."
launchctl unload "$PLIST_FILE" 2>/dev/null || true
launchctl load "$PLIST_FILE"

echo "Success! The Mac daemon is running and will start automatically on login."
echo "Temporary logs are stored in launchd. Check system logs if needed."
