#!/bin/bash
set -e

AGENT_PLIST="$HOME/Library/LaunchAgents/com.user.display-autoscaler.plist"

if [ -f "$AGENT_PLIST" ]; then
    echo "[Uninstall] Unloading LaunchAgent..."
    launchctl bootout gui/$(id -u) "$AGENT_PLIST" || true
    rm -f "$AGENT_PLIST"
fi

if [ -f "/usr/local/bin/display-autoscaler" ]; then
    echo "[Uninstall] Removing binary..."
    sudo rm -f "/usr/local/bin/display-autoscaler"
fi

echo "[Uninstall] Uninstallation completed successfully!"
