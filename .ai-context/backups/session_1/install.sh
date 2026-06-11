#!/bin/bash
set -e

echo "[Install] Compiling Swift source..."
swiftc -O main.swift -o display-autoscaler -Xlinker -undefined -Xlinker dynamic_lookup

echo "[Install] Copying executable to /usr/local/bin..."
sudo cp display-autoscaler /usr/local/bin/display-autoscaler

echo "[Install] Setting up configuration directory..."
mkdir -p "$HOME/.config/display-autoscaler"
if [ ! -f "$HOME/.config/display-autoscaler/config.json" ]; then
    cp config.json "$HOME/.config/display-autoscaler/config.json"
    echo "[Install] Default configuration created at $HOME/.config/display-autoscaler/config.json"
fi

echo "[Install] Creating LaunchAgent plist..."
AGENT_PLIST="$HOME/Library/LaunchAgents/com.user.display-autoscaler.plist"
cat <<EOF > "$AGENT_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.display-autoscaler</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/display-autoscaler</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

echo "[Install] Loading LaunchAgent..."
launchctl bootstrap gui/$(id -u) "$AGENT_PLIST" || true
launchctl kickstart -k "gui/$(id -u)/com.user.display-autoscaler" || true

echo "[Install] Installation completed successfully!"
