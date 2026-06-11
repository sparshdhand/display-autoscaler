#!/bin/bash
set -e

AGENT_PLIST="$HOME/Library/LaunchAgents/com.user.display-autoscaler.plist"

if [ -f "$AGENT_PLIST" ]; then
    echo "[Uninstall] Unloading LaunchAgent..."
    launchctl bootout gui/$(id -u) "$AGENT_PLIST" || true
    rm -f "$AGENT_PLIST"
fi

if [ -f "$HOME/bin/display-autoscaler" ]; then
    echo "[Uninstall] Removing binary..."
    rm -f "$HOME/bin/display-autoscaler"
fi

echo "[Uninstall] Uninstallation completed successfully!"
